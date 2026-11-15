using System.Data.Common;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminTransferSave;

// Slice: POST /admin/transfers {fromClassId, toClassId, type, reason?, tokens} -> {moved, failed}: move several students between two classes of one gender; each student moves on their own (own transaction) and the
// answer, 200 even when all failed, says who did not and why. students:transfer (403 "Only administrators can transfer students"), then the body (422 Invalid JSON), then in PHP's order (422): both class ids JSON
// integers ("Source and destination classes are required"), different, type exactly transfer/promotion/demotion, reason (trimmed) at most 500 characters, tokens a non-empty list of JSON integers above 0 ("Choose at least
// one student", "tokens must be member tokens"); then either class missing 404 "Class not found", the destination not active, the genders different (422). Contract: spec/api.yaml.
// PHP: routes/student_transfers.php route_admin_transfer_save (:128), ClassStudentsModel::transferMany / transferStudent. Per distinct token, in order: active in the source, else (closed source only in effect) a member of the
// deactivation cohort who holds no active enrolment anywhere ("Student t is not active in source class #f" / "Student t already has an active class; skipped"); not active in the destination; then domain/StudentMove (a cohort
// member's removed rows stay). A database error is "Could not be moved". Names come from the source's roster (domain/TransferRoster.cs), null when the token is not on it. No lock, as PHP. Event: classes.student_transferred
// per move (outbox, same transaction). Deviations: at most 2000 tokens (422); a NUL byte in the reason is 422; a reason that makes the removal reason too long fails each student with "Could not be moved".

internal static partial class AdminTransferSaveSlice
{
    private const int MaxReason = 500;
    private const int MaxTokens = 2000;
    private static readonly string[] Types = ["transfer", "promotion", "demotion"];

    internal sealed record Moved(long Token, string? Name);

    internal sealed record Failed(long Token, string? Name, string Reason);

    internal sealed record Body(IReadOnlyList<Moved> Moved, IReadOnlyList<Failed> Failed);

    private sealed record Input(int FromId, int ToId, string Type, string Reason, IReadOnlyList<long> Tokens);

    [LoggerMessage(Level = LogLevel.Warning, Message = "A transfer failed for one student and was rolled back")]
    private static partial void LogMoveFailed(ILogger logger, Exception exception);

    public static IEndpointRouteBuilder MapAdminTransferSave(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/transfers", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        HttpContext context,
        ClassesContext db,
        Permissions permissions,
        TimeProvider clock,
        ILogger<ClassesContext> log,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await AdminGuards.TransfersAsync(permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var parsed = Parse(body!);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var input = parsed.Value!;
        var assigned = await ClassListing.AssignedAsync(permissions, caller, ct);
        var source = await ClassListing.FindAsync(db, assigned, input.FromId, ct);
        var destination = await ClassListing.FindAsync(db, assigned, input.ToId, ct);
        if (source is null || destination is null)
        {
            return Refusals.ClassNotFound();
        }

        if (destination.Status != "A")
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "The destination class is not active");
        }

        if ((destination.Gender ?? 0) != (source.Gender ?? 0))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "A student can only move to a class of the same gender");
        }

        var roster = await TransferRoster.ForAsync(db, source.Id, source.Status == "A", ct);
        var names = roster.GroupBy(s => s.Token).ToDictionary(g => (long)g.Key, g => g.First().Name ?? string.Empty);
        var moved = new List<Moved>();
        var failed = new List<Failed>();
        foreach (var token in input.Tokens)
        {
            var name = names.GetValueOrDefault(token);
            var failure = await MoveOneAsync(db, clock, log, input, token, caller.Token, ct);
            if (failure is null)
            {
                moved.Add(new Moved(token, name));
            }
            else
            {
                failed.Add(new Failed(token, name, failure));
            }
        }

        return Results.Json(new Body(moved, failed));
    }

    private static Result<Input> Parse(JsonBody body)
    {
        if (!PhpValue.IsInt(body.Get("fromClassId"), out var from) || !PhpValue.IsInt(body.Get("toClassId"), out var to))
        {
            return Fail("Source and destination classes are required");
        }

        if (from == to)
        {
            return Fail("Source and destination classes must be different");
        }

        var type = body.Get("type");
        if (type.ValueKind != JsonValueKind.String || !Types.Contains(type.GetString()))
        {
            return Fail("type must be transfer, promotion or demotion");
        }

        var reason = PhpText.Trim(PhpValue.Text(body.Get("reason")));
        if (PhpText.CodePointCount(reason) > MaxReason || reason.Contains('\0', StringComparison.Ordinal))
        {
            return Fail("reason must be at most 500 characters");
        }

        var list = body.Get("tokens");
        var entries = list.ValueKind is JsonValueKind.Array or JsonValueKind.Object ? JsonBody.Entries(list) : [];
        if (entries.Count == 0)
        {
            return Fail("Choose at least one student");
        }

        // PHP array_unique: first appearance kept. The set makes the check linear for a large list.
        var seen = new HashSet<long>();
        var tokens = new List<long>();
        foreach (var entry in entries)
        {
            if (!PhpValue.IsInt(entry.Value, out var token) || token <= 0)
            {
                return Fail("tokens must be member tokens");
            }

            if (seen.Add(token))
            {
                tokens.Add(token);
            }
        }

        return tokens.Count > MaxTokens
            ? Fail("Choose at most 2000 students at a time")
            : Result.Ok(new Input((int)Math.Clamp(from, int.MinValue, int.MaxValue), (int)Math.Clamp(to, int.MinValue, int.MaxValue), type.GetString()!, reason, tokens));
    }

    private static Result<Input> Fail(string message) => Result.Fail<Input>(message);

    // Null when the student moved; else the reason PHP gives (an exception message, or "Could not be moved" for a database error).
    private static async Task<string?> MoveOneAsync(ClassesContext db, TimeProvider clock, ILogger<ClassesContext> log, Input input, long token, int by, CancellationToken ct)
    {
        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var refusal = await CheckAsync(db, input, token, ct);
            if (refusal.Message is not null)
            {
                return refusal.Message;
            }

            await StudentMove.WriteAsync(db, clock, input.FromId, input.ToId, (int)token, input.Type, input.Reason, by, refusal.RemoveFromSource, ct);
            await transaction.CommitAsync(ct);
            return null;
        }
        catch (DbException e)
        {
            LogMoveFailed(log, e);
            return "Could not be moved";
        }
    }

    private sealed record Check(string? Message, bool RemoveFromSource);

    private static async Task<Check> CheckAsync(ClassesContext db, Input input, long token, CancellationToken ct)
    {
        var fromCohort = false;
        if (!await ActiveInAsync(db, input.FromId, token, ct))
        {
            if (!await InCohortAsync(db, input.FromId, token, ct))
            {
                return new Check($"Student {token} is not active in source class #{input.FromId}", false);
            }

            if (await ActiveAnywhereAsync(db, token, ct))
            {
                return new Check($"Student {token} already has an active class; skipped", false);
            }

            fromCohort = true;
        }

        return await ActiveInAsync(db, input.ToId, token, ct)
            ? new Check($"Student {token} is already enrolled in destination class #{input.ToId}", false)
            : new Check(null, !fromCohort);
    }

    private static async Task<bool> ActiveInAsync(ClassesContext db, int classId, long token, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<int>($"""select 1 as "Value" from classes.class_students where class_id = {classId} and token_no = {token} and removed_at is null and status = 'A' limit 1""")
            .ToListAsync(ct)).Count > 0;

    private static async Task<bool> InCohortAsync(ClassesContext db, int classId, long token, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<int>($"""
                select 1 as "Value" from classes.class_students
                where class_id = {classId} and token_no = {token} and status = 'I' and removed_at is not null and removed_reason like 'Class deactivated:%'
                limit 1
                """)
            .ToListAsync(ct)).Count > 0;

    private static async Task<bool> ActiveAnywhereAsync(ClassesContext db, long token, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<int>($"""select 1 as "Value" from classes.class_students where token_no = {token} and removed_at is null and status = 'A' limit 1""")
            .ToListAsync(ct)).Count > 0;
}
