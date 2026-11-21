using System.Data.Common;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Identity.Api;
using Tsr.Membership.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassStudentEdit;

// Slice: PUT /classes/{class_id}/students/{token} {name, email, mobile, notes} -> edit a student; answers with the roster payload (domain/ClassRoster.cs). Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_student_update (:798), ClassStudentsModel::studentEmailError, canChangeEmail, updateStudentInClass. Order: active complete class (404), classes:update on the class (403, "manage this
// class"; the teacher does not hold it), the member is on the active roster (404), each of the four fields absent or null (empty) or text of at most 500 characters (422 "<f> must be text of at most 500 characters"), trimmed;
// the email (domain/StudentEditRules.cs: another member's token address, then a malformed one, 422), then identity's command: a different email is refused (422 "This member signs in with their own email; it cannot be changed
// here.") unless the member's address is blank or <token>@thestrongrope.com AND they have no Firebase link. Then one transaction: identity's ChangeEmailAsync (only a non-blank email), membership's ChangeContactAsync (the
// name only when not "" or "0" as PHP empty(); the mobile ALWAYS, an omitted one wipes it) and the note on every enrolment row of the pair (always, "" when omitted). Any database failure (a value too long for its column)
// rolls everything back: 422 "Failed to update student". No other field is read (no mass assignment), no history row. An email another member already has is 422 "This email already belongs to another member." (decided 11 Nov 2026; PHP has no such check).
// Deviations: the email column holds 255 characters here and 200 in PHP; a NUL in a field is 422 (PostgreSQL cannot store it). Events: identity.member_email_changed, membership.member_contact_changed (written by the owners'
// commands) and classes.student_edited (the note), each in the same transaction. PHP's search touch is not sent (PHP has none for this route).

internal static class ClassStudentEditSlice
{
    private const int MaxField = 500;
    private static readonly string[] Fields = ["name", "email", "mobile", "notes"];

    internal sealed record StudentEdited(int ClassId, int Token, int EditedBy);

    public static IEndpointRouteBuilder MapClassStudentEdit(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/classes/{class_id}/students/{token}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id,
        string token,
        HttpContext context,
        ClassesContext db,
        Permissions permissions,
        TimeProvider clock,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var head = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "classes:update", AccessTarget.ForClass(head.Id), ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to manage this class");
        }

        var student = ClassGuards.TokenOf(token);
        if (!await ClassRoster.IsActiveAsync(db, head.Id, student, ct))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Student not found in this class");
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var values = ReadFields(body!, out var fieldError);
        if (fieldError is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, fieldError);
        }

        var emailError = StudentEditRules.EmailError(student, values["email"]);
        if (emailError is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, emailError);
        }

        var saved = await SaveAsync(db, clock, head.Id, student, values, caller.Token, ct);
        return saved switch
        {
            Outcome.EmailTaken => Problem.Detail(StatusCodes.Status422UnprocessableEntity, "This email already belongs to another member."),
            Outcome.EmailRefused => Problem.Detail(StatusCodes.Status422UnprocessableEntity, "This member signs in with their own email; it cannot be changed here."),
            Outcome.Failed => Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Failed to update student"),
            _ => Results.Json(await ClassRoster.BuildAsync(db, permissions, caller, head.Id, ct)),
        };
    }

    private static Dictionary<string, string> ReadFields(JsonBody body, out string? error)
    {
        var values = new Dictionary<string, string>();
        error = null;
        foreach (var field in Fields)
        {
            var value = body.Get(field);
            var text = value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null ? string.Empty : value.ValueKind == JsonValueKind.String ? value.GetString()! : null;
            if (text is null || PhpText.CodePointCount(text) > MaxField || text.Contains('\0', StringComparison.Ordinal))
            {
                error = $"{field} must be text of at most {MaxField} characters";
                return values;
            }

            values[field] = PhpText.Trim(text);
        }

        return values;
    }

    private enum Outcome
    {
        Saved,
        EmailRefused,
        EmailTaken,
        Failed,
    }

    private static async Task<Outcome> SaveAsync(ClassesContext db, TimeProvider clock, int classId, int student, Dictionary<string, string> values, int by, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var tx = EfTransaction.Join(db);
        try
        {
            if (values["email"].Length > 0 && await IdentityCommands.EmailTakenAsync(tx, student, values["email"], ct))
            {
                return Outcome.EmailTaken;
            }

            if (values["email"].Length > 0 && !await IdentityCommands.ChangeEmailAsync(tx, student, values["email"], clock, ct))
            {
                return Outcome.EmailRefused;
            }

            var name = StudentEditRules.NameToWrite(values["name"]);
            if ((name?.Length ?? 0) > MembershipCommands.MaxNameLength || values["mobile"].Length > MembershipCommands.MaxMobileLength)
            {
                return Outcome.Failed;
            }

            await MembershipCommands.ChangeContactAsync(tx, student, name, values["mobile"], clock, ct);
            var notes = values["notes"];
            await db.Database.ExecuteSqlAsync($"update classes.class_students set notes = {notes} where class_id = {classId} and token_no = {student}", ct);
            await Outbox.WriteAsync(db, "classes.student_edited", new StudentEdited(classId, student, by), clock, ct);
            await transaction.CommitAsync(ct);
            return Outcome.Saved;
        }
        catch (DbException)
        {
            return Outcome.Failed;
        }
    }
}
