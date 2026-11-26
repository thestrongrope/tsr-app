using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudentAdd;

// Slice: POST /classes/{class_id}/students {token} -> enrol one member; answers with the roster payload (domain/ClassRoster.cs). Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_student_add (:709), ClassStudentsModel::addStudent. Order: active complete class (404), students:enrol on the class (403), token a JSON integer above 0 (422 "token must be a member's token").
// A member already on the active roster is a no-op (200, nothing written, no event). Otherwise domain/Enrolment.AddAsync: not a member, or a known gender other than the class's, is one 422 ("Could not add <token>: not a
// registered member, or their gender does not match this class."); a member without a gender may join. A removed member gets a NEW row (not a restore); membership's accepted-registration command runs when they have no
// class request. No lock, as PHP. Event: classes.student_enrolled (outbox, same transaction). PHP's search touch is not sent.

internal static class ClassStudentAddSlice
{
    public static IEndpointRouteBuilder MapClassStudentAdd(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/students", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(source, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "students:enrol", AccessTarget.ForClass(head.Id), ct))
        {
            return Refusals.NotPermittedToChangeStudents();
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (!PhpValue.IsInt(body!.Get("token"), out var token) || token <= 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "token must be a member's token");
        }

        // A token beyond what a member's token column holds names nobody.
        if (token > int.MaxValue)
        {
            return Refused(token);
        }

        var member = (int)token;
        if (!await ClassRoster.IsActiveAsync(source, head.Id, member, ct) && !await SaveAsync(source, clock, head.Id, member, caller.Token, ct))
        {
            return Refused(token);
        }

        return Results.Json(await ClassRoster.BuildAsync(source, permissions, caller, head.Id, ct), ClassesJson.Answers.Answer);
    }

    private static IResult Refused(long token) => Problem.Detail(
        StatusCodes.Status422UnprocessableEntity,
        "Could not add " + token.ToString(System.Globalization.CultureInfo.InvariantCulture) + ": not a registered member, or their gender does not match this class.");

    private static async Task<bool> SaveAsync(NpgsqlDataSource source, TimeProvider clock, int classId, int token, int by, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        if (!await Enrolment.AddAsync(tx, classId, token, by, ct))
        {
            return false;
        }

        await Outbox.WriteAsync(tx, "classes.student_enrolled", new StudentEnrolled(classId, token, by, "added"), ClassesJson.Default.StudentEnrolled, clock, ct);
        await tx.CommitAsync(ct);
        return true;
    }
}
