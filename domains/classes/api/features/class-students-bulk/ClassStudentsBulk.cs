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

namespace Tsr.Classes.Api.Features.ClassStudentsBulk;

// Slice: POST /classes/{class_id}/students/bulk {lines: [text], resolutions: {lineNo: add|enrol|skip}} -> enrol a pasted list, each line "name" or "name, mobile". Contract: spec/api.yaml.
// PHP: routes/class_manage.php route_class_students_bulk_add (:740), ClassStudentsModel::bulkEnrol, createClassStudent. Order: active complete class (404), students:enrol on the class (403), the admin audit row for a
// privileged caller (platform's command), 10 calls a minute per member (429 "Too many bulk adds. Please wait a minute and try again."; counted here, after the 403, 422s included; MemberRateLimit), then lines a list of at
// most 200 texts of at most 300 characters with one non-blank (422), resolutions each add, enrol or skip (422). domain/BulkLines.cs decides every line (rejected with a reason, duplicate_name, mobile_match with the masked
// name only, ready); a flagged line without a usable answer holds the WHOLE batch back (status "confirm", nothing written). Otherwise one transaction writes every wanted line: an existing member through
// Enrolment.AddAsync (gender checked again), a new one through identity's CreateMemberAsync (token = highest + 1 under the advisory lock), membership's CreateProfileAsync (name, the class's gender, mobile) and
// Enrolment.AddAsync. Any failure rolls everything back: 500 "Nothing was added. Please try again." Answer {status, added, lines[], roster when added > 0}.
// Only members of the class's gender (or none recorded) are matched by mobile; a line carries no email, role or token. PHP has no cap besides the 200 lines. Events: classes.student_enrolled (source "bulk"), one per
// enrolled member as the single add writes it, plus identity.member_created and membership.member_created per created member. PHP's search touch is not sent.
// Deviations: a NUL in a line is 422 (PostgreSQL cannot store it); the 10 a minute count is in memory per API process (PHP: a file per member).

internal static class ClassStudentsBulkSlice
{
    private const string Bucket = "class_bulk_add";
    private const int MobileMatchRows = 5000;

    private sealed record Candidate(int Token, string Name, string? Gender, string Key);

    public static IEndpointRouteBuilder MapClassStudentsBulk(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/classes/{class_id}/students/bulk", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string class_id,
        HttpContext context,
        ClassesContext db,
        Permissions permissions,
        MemberRateLimit limit,
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

        if (!await permissions.CanAsync(caller, "students:enrol", AccessTarget.ForClass(head.Id), ct))
        {
            return Refusals.NotPermittedToChangeStudents();
        }

        await ClassGuards.LogAdminAccessAsync(db, context, permissions, caller, ct);
        if (!limit.Allow(Bucket, caller.Token, 10, 60))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, "Too many bulk adds. Please wait a minute and try again.");
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var lines = ReadLines(body!, out var lineError);
        if (lineError is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, lineError);
        }

        var resolutions = ReadResolutions(body!, out var resolutionError);
        if (resolutionError is not null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, resolutionError);
        }

        var result = BulkLines.Classify(lines!, resolutions!, await MatchesAsync(db, lines!, head.Gender, ct), await EnrolledTokensAsync(db, head.Id, ct), await EnrolledNamesAsync(db, head.Id, ct));
        if (result.Plan.Count == 0)
        {
            return Results.Json(Answer(result, new Dictionary<int, string>()));
        }

        var written = await WriteAsync(db, clock, head.Id, head.Gender, result.Plan, caller.Token, ct);
        if (written is null)
        {
            return Problem.Detail(StatusCodes.Status500InternalServerError, "Nothing was added. Please try again.");
        }

        var answer = Answer(result, written);
        answer["roster"] = await ClassRoster.BuildAsync(db, permissions, caller, head.Id, ct);
        return Results.Json(answer);
    }

    private static List<string>? ReadLines(JsonBody body, out string? error)
    {
        error = null;
        var value = body.Get("lines");
        if (value.ValueKind != JsonValueKind.Array || value.GetArrayLength() > BulkLines.MaxLines)
        {
            error = "lines must be a list of at most 200 lines";
            return null;
        }

        var lines = new List<string>();
        var any = false;
        foreach (var item in value.EnumerateArray())
        {
            var text = item.ValueKind == JsonValueKind.String ? item.GetString()! : null;
            if (text is null || PhpText.CodePointCount(text) > BulkLines.MaxLineLength || text.Contains('\0', StringComparison.Ordinal))
            {
                error = "each line must be text of at most 300 characters";
                return null;
            }

            any = any || PhpText.Trim(text).Length > 0;
            lines.Add(text);
        }

        if (!any)
        {
            error = "Add at least one student, one per line: a name, then an optional mobile number.";
            return null;
        }

        return lines;
    }

    // PHP's (array)($body['resolutions'] ?? []): absent or null is none; a list or object is its entries (a key is (int)-cast); a lone text is one entry at 0, any other scalar a bad entry.
    private static Dictionary<int, string>? ReadResolutions(JsonBody body, out string? error)
    {
        error = null;
        var resolutions = new Dictionary<int, string>();
        var value = body.Get("resolutions");
        if (value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            return resolutions;
        }

        var entries = value.ValueKind is JsonValueKind.Array or JsonValueKind.Object
            ? JsonBody.Entries(value)
            : [new KeyValuePair<string, JsonElement>("0", value)];
        foreach (var (key, choice) in entries)
        {
            var text = choice.ValueKind == JsonValueKind.String ? choice.GetString() : null;
            if (text is not ("add" or "enrol" or "skip"))
            {
                error = "a resolution must be add, enrol or skip";
                return null;
            }

            var number = PhpValue.IntOfText(key);
            if (number is >= 1 and <= BulkLines.MaxLines)
            {
                resolutions[(int)number] = text;
            }
        }

        return resolutions;
    }

    // PHP memberByMobile: the stored number without spaces, dashes and plus signs, its last ten characters (MariaDB substr(x, -10) is empty for a shorter one), the first member by id whose gender fits.
    private static async Task<Dictionary<string, BulkLines.Member>> MatchesAsync(ClassesContext db, List<string> lines, int classGender, CancellationToken ct)
    {
        var keys = lines
            .Where(l => PhpText.Trim(l).Length > 0)
            .Select(BulkLines.Parse)
            .Where(p => p.Error is null && p.Mobile.Length > 0)
            .Select(p => BulkLines.MobileKey(p.Mobile))
            .Distinct()
            .ToArray();
        var matches = new Dictionary<string, BulkLines.Member>();
        if (keys.Length == 0)
        {
            return matches;
        }

        var rows = await db.Database
            .SqlQuery<Candidate>($"""
                select m.token as "Token", coalesce(m.name, '') as "Name", m.gender as "Gender", x.k as "Key"
                from membership.v_members m
                cross join lateral (
                    select case when length(s.v) >= 10 then right(s.v, 10) else '' end as k
                    from (select replace(replace(replace(coalesce(m.mobile, ''), ' ', ''), '-', ''), '+', '') as v) s
                ) x
                where m.token > 0 and x.k = any({keys})
                order by m.user_id
                limit {MobileMatchRows}
                """)
            .ToListAsync(ct);
        foreach (var row in rows.Where(r => EnrolmentRules.GenderAllows(r.Gender, classGender)))
        {
            matches.TryAdd(row.Key, new BulkLines.Member(row.Token, row.Name));
        }

        return matches;
    }

    private static async Task<HashSet<int>> EnrolledTokensAsync(ClassesContext db, int classId, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<int>($"""select token_no as "Value" from classes.class_students where class_id = {classId} and status = 'A' and removed_at is null""")
            .ToListAsync(ct)).ToHashSet();

    private static async Task<HashSet<string>> EnrolledNamesAsync(ClassesContext db, int classId, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<string>($"""
                select coalesce(m.name, '') as "Value"
                from classes.class_students cs
                join membership.v_members m on m.token = cs.token_no
                where cs.class_id = {classId} and cs.status = 'A' and cs.removed_at is null
                """)
            .ToListAsync(ct)).Select(BulkLines.NameKey).ToHashSet();

    // The statuses the written lines end with, by line number; null when the batch failed and nothing was kept.
    private static async Task<Dictionary<int, string>?> WriteAsync(ClassesContext db, TimeProvider clock, int classId, int classGender, IReadOnlyList<BulkLines.Step> plan, int by, CancellationToken ct)
    {
        var statuses = new Dictionary<int, string>();
        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            foreach (var step in plan)
            {
                var token = step.EnrolToken ?? await CreateMemberAsync(db, clock, classGender, step, ct);
                if (!await Enrolment.AddAsync(db, classId, token, by, ct))
                {
                    return null;
                }

                await Outbox.WriteAsync(db, "classes.student_enrolled", new StudentEnrolled(classId, token, by, "bulk"), clock, ct);
                statuses[step.Line] = step.EnrolToken is null ? "added" : "enrolled";
            }

            await transaction.CommitAsync(ct);
            return statuses;
        }
        catch (Exception e) when (e is DbException or InvalidOperationException or ArgumentException)
        {
            return null;
        }
    }

    private static async Task<int> CreateMemberAsync(ClassesContext db, TimeProvider clock, int classGender, BulkLines.Step step, CancellationToken ct)
    {
        var token = await IdentityCommands.CreateMemberAsync(db, clock, ct);
        await MembershipCommands.CreateProfileAsync(db, token, step.Name, classGender.ToString(System.Globalization.CultureInfo.InvariantCulture), step.Mobile, clock, ct);
        return token;
    }

    private static Dictionary<string, object?> Answer(BulkLines.Result result, Dictionary<int, string> written)
    {
        var lines = new List<Dictionary<string, object?>>();
        foreach (var line in result.Lines)
        {
            var entry = new Dictionary<string, object?>
            {
                ["line"] = line.Number,
                ["name"] = line.Name,
                ["status"] = written.TryGetValue(line.Number, out var status) ? status : line.Status,
            };
            if (line.Reason is not null)
            {
                entry["reason"] = line.Reason;
            }

            if (line.MemberName is not null)
            {
                entry["member"] = new Dictionary<string, object?> { ["name"] = line.MemberName };
            }

            lines.Add(entry);
        }

        return new Dictionary<string, object?> { ["status"] = result.Status, ["added"] = written.Count, ["lines"] = lines };
    }
}
