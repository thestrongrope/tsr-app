using System.Text.Json;
using System.Data.Common;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminTeachersTraining;

// Slice: POST /admin/teachers/training {changes: [{token, level, action}], comments} -> {changed}: add or remove the levels teachers are trained for. teachers:read with no target (403 "You do not have permission to
// do that") BEFORE the body is read; changes that are not a list, and comments that are not text, count as empty. Then, in PHP's order: comments trimmed (422 "A comment is required"; over 500 characters "The comment
// must be 500 characters or fewer"), at least one change (422 "There is nothing to change"), then each change in turn (422 "Each change needs a teacher, a level and added or removed", 404 "Teacher #t not found", 403
// "You do not have permission to change teacher #t" when the teacher's gender is not 1 or 2 or the caller lacks teachers:read for it), so an early 404 or 403 can come before a later malformed change. Nothing is
// written until every change passes. One transaction then writes each teacher (domain/TeacherWriter.cs); a failure is 500 "The training could not be changed, and nothing was changed. Please try again."
// "changed" counts the distinct tokens. Contract: spec/api.yaml.
// PHP: routes/teachers.php route_admin_teachers_training (:134), TeachersModel::changeTrainingLevels. Training is authorised by teachers:read, so a gender administrator can write (PHP's rule, kept). Event:
// classes.teacher_training_changed per teacher (outbox, same transaction), also when no flag flipped (PHP writes the history row then too). Deviation: at most 1000 changes (422).

internal static partial class AdminTeachersTrainingSlice
{
    private const int MaxChanges = 1000;
    private const int MaxComment = 500;

    internal sealed record Done(int Changed);

    [LoggerMessage(Level = LogLevel.Error, Message = "Teacher training change failed and was rolled back")]
    private static partial void LogFailed(ILogger logger, Exception exception);

    public static IEndpointRouteBuilder MapAdminTeachersTraining(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/teachers/training", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        TimeProvider clock,
        ILogger<ClassesLog> log,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "teachers:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var comments = body!.Get("comments");
        var note = comments.ValueKind == JsonValueKind.String ? PhpText.Trim(comments.GetString()!) : string.Empty;
        var list = body.Get("changes");
        var items = list.ValueKind is JsonValueKind.Array or JsonValueKind.Object ? JsonBody.Entries(list) : [];
        var invalid = InvalidInput(note, items.Count);
        if (invalid is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid);
        }

        var planned = await PlanAsync(source, permissions, caller, items, ct);
        if (planned.Refusal is not null)
        {
            return planned.Refusal;
        }

        try
        {
            await using var tx = await source.BeginAsync(ct);
            await TeacherWriter.WriteBatchAsync(tx, planned.Teachers!, note, caller.Token, clock, ct);
            await tx.CommitAsync(ct);
        }
        catch (DbException e)
        {
            LogFailed(log, e);
            return Problem.Detail(StatusCodes.Status500InternalServerError, "The training could not be changed, and nothing was changed. Please try again.");
        }

        return Results.Json(new Done(planned.Teachers!.Count), ClassesJson.Answers.TeachersTrainingDone);
    }

    private static string? InvalidInput(string note, int changes)
    {
        if (note.Length == 0)
        {
            return "A comment is required";
        }

        if (PhpText.CodePointCount(note) > MaxComment)
        {
            return "The comment must be 500 characters or fewer";
        }

        if (note.Contains('\0', StringComparison.Ordinal))
        {
            return "The comment must not contain a NUL byte"; // PHP stores it; PostgreSQL text cannot.
        }

        if (changes == 0)
        {
            return "There is nothing to change";
        }

        return changes > MaxChanges ? "At most 1000 changes at a time" : null;
    }

    private sealed record Plan(IResult? Refusal, List<(int Token, TeacherTraining.Flags Flags)>? Teachers);

    // PHP changeTrainingLevels' loop and updateTeacherLevels' consolidation: judge each change in turn, then fold them per teacher onto the teacher's current flags (all off without a record).
    private static async Task<Plan> PlanAsync(NpgsqlDataSource source, Permissions permissions, Caller caller, IReadOnlyList<KeyValuePair<string, JsonElement>> items, CancellationToken ct)
    {
        var genders = new Dictionary<long, int?>();
        var flags = new Dictionary<int, TeacherTraining.Flags>();
        foreach (var item in items)
        {
            var change = TeacherTraining.ReadChange(item.Value);
            if (change is null)
            {
                return new Plan(Problem.Detail(StatusCodes.Status422UnprocessableEntity, "Each change needs a teacher, a level and added or removed"), null);
            }

            if (!genders.TryGetValue(change.Token, out var gender))
            {
                gender = await GenderOfAsync(source, change.Token, ct);
                genders[change.Token] = gender;
            }

            var refusal = await RefusalAsync(permissions, caller, change.Token, gender, ct);
            if (refusal is not null)
            {
                return new Plan(refusal, null);
            }

            if (!flags.TryGetValue(change.Token, out var current))
            {
                current = await TeacherWriter.ExistingAsync(source, change.Token, ct) ?? TeacherTraining.Flags.None;
            }

            flags[change.Token] = current.With(change.Level, change.Added ? 1 : 0);
        }

        return new Plan(null, flags.Select(f => (f.Key, f.Value)).ToList());
    }

    private static async Task<IResult?> RefusalAsync(Permissions permissions, Caller caller, int token, int? gender, CancellationToken ct)
    {
        if (gender is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, $"Teacher #{token} not found");
        }

        var allowed = gender is 1 or 2 && await permissions.CanAsync(caller, "teachers:read", AccessTarget.ForGender(gender.Value), ct);
        return allowed ? null : Problem.Detail(StatusCodes.Status403Forbidden, $"You do not have permission to change teacher #{token}");
    }

    // PHP genderOf: the member's stored gender cast with (int) ("Male" is 0), null when there is no such member.
    private static async Task<int?> GenderOfAsync(NpgsqlDataSource source, int token, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""select coalesce(gender::text, '') as "Value" from membership.v_members where token = {token} order by user_id limit 1""",
            row => row.Text("Value"),
            ct);
        return rows.Count == 0 ? null : (int)Math.Clamp(PhpValue.IntOfText(rows[0]), int.MinValue, int.MaxValue);
    }
}
