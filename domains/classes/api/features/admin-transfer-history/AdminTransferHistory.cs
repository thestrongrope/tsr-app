using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminTransferHistory;

// Slice: GET /admin/transfers/history?q=&page=&pageSize= -> {total, page, pageSize, items}: the transfer log, newest first (transferred_at, id). students:transfer (403), no audit row. page is at least 1,
// pageSize 1 to 100 (default 50, camelCase); neither is ever a 4xx. q (trimmed) matches the student's or the operator's name, either class's code or the reason as a substring, or the student's token exactly;
// "%" and "_" in q are live wildcards (not escaped, as PHP). Contract: spec/api.yaml.
// PHP: routes/student_transfers.php route_admin_transfer_history (:176), ClassStudentsModel::searchTransferHistory. Names come from membership.v_members in the same query (no interface call). Quirks: a
// transfer whose student, operator or class has no row is missing from the list and the count; a token shared by two members doubles the row. The patterns are cast to citext (case-insensitive, as MariaDB's).
// Deviation: the offset is bounded (page above a billion reads as a billion).

internal static class AdminTransferHistorySlice
{
    private const int MaxPage = 1_000_000_000;

    internal sealed record Row(
        long Id,
        int StudentToken,
        string? StudentName,
        string Type,
        string? FromCode,
        string? ToCode,
        string? Reason,
        string? TransferredBy,
        DateTimeOffset TransferredAt);

    internal sealed record Item(long Id, int StudentToken, object StudentName, string Type, string FromCode, string ToCode, string? Reason, object TransferredBy, string TransferredAt);

    internal sealed record Body(int Total, long Page, long PageSize, IReadOnlyList<Item> Items);

    public static IEndpointRouteBuilder MapAdminTransferHistory(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/transfers/history", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
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

        var page = Math.Max(1, ClassGuards.QueryInt(context, "page", 1));
        var pageSize = Math.Min(100, Math.Max(1, ClassGuards.QueryInt(context, "pageSize", 50)));
        var qValues = context.Request.Query["q"];
        var q = PhpText.Trim(qValues.Count == 0 ? string.Empty : qValues[^1] ?? string.Empty);
        if (q.Contains('\0', StringComparison.Ordinal))
        {
            return Results.Json(new Body(0, page, pageSize, []), ClassesJson.Answers.TransferHistoryBody); // PostgreSQL text cannot hold a NUL byte, so nothing matches.
        }

        // As PHP: the permission is the only gate; a caller limited to assigned classes still sees every move (owner's decision, 14 Nov 2026).
        var like = "%" + q + "%";
        var offset = (Math.Min(page, MaxPage) - 1) * pageSize;

        var total = (await source.ListAsync(
            $"""
                select count(*)::int as "Value"
                from classes.student_transfers st
                join membership.v_members u on u.token = st.token_no
                join classes.classes fc on fc.id = st.from_class_id
                join classes.classes tc on tc.id = st.to_class_id
                join membership.v_members ab on ab.token = st.transferred_by
                where ({q} = '' or u.name like {like}::citext or st.token_no::text = {q} or fc.code like {like}::citext or tc.code like {like}::citext
                   or st.reason like {like}::citext or ab.name like {like}::citext)
                """,
            row => row.Int("Value"),
            ct))[0];
        var rows = await source.ListAsync(
            $"""
                select st.id::bigint as "Id", st.token_no as "StudentToken", u.name as "StudentName", st.type as "Type", fc.code as "FromCode", tc.code as "ToCode",
                       st.reason::text as "Reason", ab.name as "TransferredBy", st.transferred_at as "TransferredAt"
                from classes.student_transfers st
                join membership.v_members u on u.token = st.token_no
                join classes.classes fc on fc.id = st.from_class_id
                join classes.classes tc on tc.id = st.to_class_id
                join membership.v_members ab on ab.token = st.transferred_by
                where ({q} = '' or u.name like {like}::citext or st.token_no::text = {q} or fc.code like {like}::citext or tc.code like {like}::citext
                   or st.reason like {like}::citext or ab.name like {like}::citext)
                order by st.transferred_at desc, st.id desc
                limit {pageSize} offset {offset}
                """,
            row => new Row(
                row.Long("Id"),
                row.Int("StudentToken"),
                row.TextOrNull("StudentName"),
                row.Text("Type"),
                row.TextOrNull("FromCode"),
                row.TextOrNull("ToCode"),
                row.TextOrNull("Reason"),
                row.TextOrNull("TransferredBy"),
                row.Instant("TransferredAt")),
            ct);
        var items = rows.Select(r => new Item(
            r.Id,
            r.StudentToken,
            PhpCast.Text(r.StudentName),
            r.Type,
            PhpCast.Str(r.FromCode),
            PhpCast.Str(r.ToCode),
            PhpCast.TextOrNull(r.Reason),
            PhpCast.Text(r.TransferredBy),
            r.TransferredAt.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture))).ToList();
        return Results.Json(new Body(total, page, pageSize, items), ClassesJson.Answers.TransferHistoryBody);
    }
}
