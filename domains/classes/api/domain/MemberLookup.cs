using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// What the two member routes under /admin/members share (PHP routes/member_enrol.php and EntityAccessModel::memberDetails): the token of the path, the one-member rule (none is 404, several is 422 with a code), the
/// answers that carry a <c>code</c> and the lookup itself. The reads use membership.v_members and identity.v_users in SQL (domains/CLAUDE.md rule 2).
/// </summary>
internal static partial class MemberLookup
{
    public const string Throttled = "Too many lookups. Please wait a while and try again.";
    public const string NotFound = "No registered member has this token";
    public const string Ambiguous = "More than one member has that token number. Please contact an admin.";

    private const int MaxClasses = 50;

    internal sealed record Coded(string Detail, string Code);

    // PHP: preg_match('/^\d{1,18}$/'): ASCII digits only, and "$" also matches before one final newline.
    [GeneratedRegex(@"^[0-9]{1,18}\n?\z", RegexOptions.CultureInvariant, matchTimeoutMilliseconds: 200)]
    private static partial Regex PlainDigits();

    /// <summary>The token of the path: plain digits (up to 18), else 0, which is never found. A number beyond what a token holds is 0 too.</summary>
    public static int TokenOf(string raw)
    {
        if (!PlainDigits().IsMatch(raw))
        {
            return 0;
        }

        return long.TryParse(raw.Trim(), NumberStyles.None, CultureInfo.InvariantCulture, out var number) && number <= int.MaxValue ? (int)number : 0;
    }

    /// <summary>An answer with a machine-readable code beside the detail ({"detail": ..., "code": ...}).</summary>
    public static IResult Refusal(int status, string detail, string code) => Results.Json(new Coded(detail, code), ClassesJson.Answers.MemberLookupCoded, statusCode: status);

    public static IResult NotFoundAnswer() => Problem.Detail(StatusCodes.Status404NotFound, NotFound);

    public static IResult AmbiguousAnswer() => Refusal(StatusCodes.Status422UnprocessableEntity, Ambiguous, "ambiguous_token");

    /// <summary>How many members hold the token (PHP: "select id from users where token limit 2": 0, 1 or 2).</summary>
    public static async Task<int> HoldersAsync(DbTx tx, int token, CancellationToken ct) =>
        token <= 0
            ? 0
            : (await tx.ListAsync($"""select id as "Value" from identity.v_users where token = {token} limit 2""", row => row.Int("Value"), ct)).Count;

    internal sealed record Row(string? Name, string? Gender, string? Email, string? Mobile, string? City, string? Country, DateTimeOffset? CreatedOn);

    public static async Task<Row?> RowAsync(DbTx tx, int token, CancellationToken ct)
    {
        var rows = await tx.ListAsync(
            $"""
                select m.name as "Name", m.gender::text as "Gender", u.email as "Email", m.mobile as "Mobile", m.city::text as "City", m.country::text as "Country", u.created_on as "CreatedOn"
                from identity.v_users u
                left join membership.v_members m on m.user_id = u.id
                where u.token = {token}
                limit 1
                """,
            row => new Row(
                row.TextOrNull("Name"),
                row.TextOrNull("Gender"),
                row.TextOrNull("Email"),
                row.TextOrNull("Mobile"),
                row.TextOrNull("City"),
                row.TextOrNull("Country"),
                row.InstantOrNull("CreatedOn")),
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    internal sealed record Requested(int? ForClassId, string? Status, string? Code, string? Name);

    /// <summary>The class the member's latest request asked for, or null (no request, no class, a class that is gone, or an Accepted request: it says nothing about what was asked).</summary>
    public static async Task<Requested?> RequestedClassAsync(DbTx tx, int token, CancellationToken ct)
    {
        var rows = await tx.ListAsync(
            $"""
                select r.for_classid as "ForClassId", r.status as "Status", c.code as "Code", c.name as "Name"
                from membership.v_registrations r
                left join classes.classes c on c.id = r.for_classid
                where r.token = {token}
                order by r.id desc
                limit 1
                """,
            row => new Requested(row.IntOrNull("ForClassId"), row.TextOrNull("Status"), row.TextOrNull("Code"), row.TextOrNull("Name")),
            ct);
        if (rows.Count == 0 || rows[0].ForClassId is null or <= 0 || rows[0].Code is null || rows[0].Status == "Accepted")
        {
            return null;
        }

        return rows[0];
    }

    internal sealed record Now(int Id, string Code, string Name, string? Level);

    public static async Task<List<Now>> ClassesNowAsync(DbTx tx, int token, CancellationToken ct) =>
        await tx.ListAsync(
            $"""
                select distinct c.id as "Id", c.code::text as "Code", c.name as "Name", l.name as "Level"
                from classes.class_students cs
                join classes.classes c on c.id = cs.class_id and c.status = 'A'
                left join classes.class_levels l on l.id = c.class_level_id
                where cs.token_no = {token} and cs.removed_at is null and cs.status = 'A'
                order by c.code::text
                limit {MaxClasses}
                """,
            row => new Now(row.Int("Id"), row.Text("Code"), row.Text("Name"), row.TextOrNull("Level")),
            ct);

    internal sealed record Left(int Id, string Code, string Name, DateTimeOffset? RemovedAt);

    /// <summary>The latest enrolment row of each class the member is not in now (duplicate rows exist), newest first: a removed, moved or closed-class row all count as left.</summary>
    public static async Task<List<Left>> ClassesLeftAsync(DbTx tx, int token, CancellationToken ct) =>
        await tx.ListAsync(
            $"""
                select c.id as "Id", c.code::text as "Code", c.name as "Name", cs.removed_at as "RemovedAt"
                from classes.class_students cs
                join classes.classes c on c.id = cs.class_id
                where cs.token_no = {token}
                  and cs.id = (select max(latest.id) from classes.class_students latest where latest.token_no = {token} and latest.class_id = cs.class_id)
                  and not exists (select 1 from classes.class_students n join classes.classes nc on nc.id = n.class_id
                                  where n.token_no = {token} and n.class_id = cs.class_id and n.removed_at is null and n.status = 'A' and nc.status = 'A')
                order by cs.id desc
                limit {MaxClasses}
                """,
            row => new Left(row.Int("Id"), row.Text("Code"), row.Text("Name"), row.InstantOrNull("RemovedAt")),
            ct);
}
