using System.Globalization;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The admin access log as data, for the screen (GET /admin/access-log) and its download. PHP: AuditLogModel (models/auditlog.php) and the filters of routes/access_log.php.
/// Names come from membership.v_members and emails from identity.v_users (PHP joined its own users table). The summaries cover the last 30 days; the recent list is
/// the latest 500 whenever; a download holds every access in the window (PHP: no bound; here at most <see cref="MaxDownloadRows"/>). The permission (audit-log:read) is checked by the caller.
/// </summary>
internal static class AccessLog
{
    public const int WindowDays = 30;

    public const int RecentLimit = 500;

    public const int MaxDownloadRows = 50_000;

    /// <summary>The filters of the query string: the member's token and a part of the page name (PHP api_access_log_filters).</summary>
    internal sealed record Filters(long? Token, string Page)
    {
        /// <summary>No stored page name holds a NUL byte, and the database refuses one in text: such a filter matches nothing.</summary>
        public bool MatchesNothing => Page.Contains('\0', StringComparison.Ordinal);
    }

    internal sealed record MemberRow(int Token, string Name, string Email, long Hits, long ActiveDays, string LastAccessed);

    internal sealed record PageRow(string Page, long Hits, string LastAccessed);

    internal sealed record RecentRow(long Id, string AccessedAt, int Token, string Name, string Email, int? RoleId, string Method, string Page, string Ip);

    internal sealed record AccessRow(string AccessedAt, int Token, string Name, string Email, int? RoleId, string Method, string Page, string Ip, string UserAgent, string Referer);

    /// <summary>The filters, or the 422 PHP gives a token that is not all digits. PHP trims spaces, tabs, line ends, NUL and vertical tab first.</summary>
    public static (Filters? Filters, IResult? Refusal) ReadFilters(HttpContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var token = Trimmed(context.Request.Query["token"].LastOrDefault());
        var page = Trimmed(context.Request.Query["page"].LastOrDefault());
        if (token.Length == 0)
        {
            return (new Filters(null, page), null);
        }

        if (!token.All(char.IsAsciiDigit))
        {
            return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, "token must be a member number"));
        }

        // PHP's (int) cast saturates; a number past the range matches no member.
        var parsed = long.TryParse(token, NumberStyles.None, CultureInfo.InvariantCulture, out var value) ? value : long.MaxValue;
        return (new Filters(parsed, page), null);
    }

    public static DateTimeOffset WindowStart(TimeProvider clock) => clock.GetUtcNow().AddDays(-WindowDays);

    /// <summary>PHP ROLE_NAMES: an unknown role reads "Role n", none reads "".</summary>
    public static string RoleName(int? roleId) => roleId switch
    {
        null => string.Empty,
        0 => "Member",
        1 => "Admin",
        3 => "Gents admin",
        4 => "Ladies admin",
        5 => "Class admin",
        6 => "Class teacher",
        7 => "Finance",
        var other => "Role " + other.Value.ToString(CultureInfo.InvariantCulture),
    };

    /// <summary>PHP spreadsheetSafe: a value that starts, after any spaces, with = + - or @ gets a leading apostrophe, so a spreadsheet never reads it as a formula.</summary>
    public static string SpreadsheetSafe(string? value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var first = value.TrimStart(' ', '\t', '\n', '\r', '\0', '\v');
        return first.Length > 0 && first[0] is '=' or '+' or '-' or '@' ? "'" + value : value;
    }

    public static async Task<List<MemberRow>> SummaryByMemberAsync(PlatformContext db, DateTimeOffset since, Filters filters, CancellationToken ct)
    {
        if (filters.MatchesNothing)
        {
            return [];
        }

        // Grouped by token as PHP does; the name and email are the same for every row of a token, so max() only satisfies the grouping.
        return await db.Database.SqlQuery<MemberRow>($"""
            select coalesce(l.token, 0) as "Token", coalesce(max(m.name), '') as "Name", coalesce(max(u.email), '') as "Email",
                   count(*) as "Hits", count(distinct (l.accessed_at at time zone 'UTC')::date) as "ActiveDays",
                   to_char(max(l.accessed_at) at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') as "LastAccessed"
            from platform.admin_access_log l
            left join membership.v_members m on m.user_id = l.user_id
            left join identity.v_users u on u.id = l.user_id
            where l.accessed_at >= {since}
              and ({filters.Token}::bigint is null or l.token = {filters.Token}::bigint)
              and ({filters.Page}::text = '' or l.page like '%' || {filters.Page}::text || '%')
            group by l.token
            order by count(*) desc, max(l.accessed_at) desc
            limit {MaxDownloadRows}
            """).ToListAsync(ct);
    }

    public static async Task<List<PageRow>> SummaryByPageAsync(PlatformContext db, DateTimeOffset since, Filters filters, CancellationToken ct)
    {
        if (filters.MatchesNothing)
        {
            return [];
        }

        return await db.Database.SqlQuery<PageRow>($"""
            select l.page as "Page", count(*) as "Hits", to_char(max(l.accessed_at) at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') as "LastAccessed"
            from platform.admin_access_log l
            where l.accessed_at >= {since}
              and ({filters.Token}::bigint is null or l.token = {filters.Token}::bigint)
              and ({filters.Page}::text = '' or l.page like '%' || {filters.Page}::text || '%')
            group by l.page
            order by count(*) desc, max(l.accessed_at) desc
            limit {MaxDownloadRows}
            """).ToListAsync(ct);
    }

    /// <summary>The latest 500 accesses, not limited to the window, newest first.</summary>
    public static async Task<List<RecentRow>> RecentAsync(PlatformContext db, Filters filters, CancellationToken ct)
    {
        if (filters.MatchesNothing)
        {
            return [];
        }

        return await db.Database.SqlQuery<RecentRow>($"""
            select l.id as "Id", to_char(l.accessed_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') as "AccessedAt", coalesce(l.token, 0) as "Token",
                   coalesce(m.name, '') as "Name", coalesce(u.email, '') as "Email", l.roleid as "RoleId", l.method as "Method", l.page as "Page", coalesce(l.ip, '') as "Ip"
            from platform.admin_access_log l
            left join membership.v_members m on m.user_id = l.user_id
            left join identity.v_users u on u.id = l.user_id
            where ({filters.Token}::bigint is null or l.token = {filters.Token}::bigint)
              and ({filters.Page}::text = '' or l.page like '%' || {filters.Page}::text || '%')
            order by l.id desc
            limit {RecentLimit}
            """).ToListAsync(ct);
    }

    /// <summary>Every access in the window that matches, newest first: what a download holds.</summary>
    public static async Task<List<AccessRow>> AccessesAsync(PlatformContext db, DateTimeOffset since, Filters filters, CancellationToken ct)
    {
        if (filters.MatchesNothing)
        {
            return [];
        }

        return await db.Database.SqlQuery<AccessRow>($"""
            select to_char(l.accessed_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS') as "AccessedAt", coalesce(l.token, 0) as "Token",
                   coalesce(m.name, '') as "Name", coalesce(u.email, '') as "Email", l.roleid as "RoleId", l.method as "Method", l.page as "Page",
                   coalesce(l.ip, '') as "Ip", coalesce(l.user_agent, '') as "UserAgent", coalesce(l.referer, '') as "Referer"
            from platform.admin_access_log l
            left join membership.v_members m on m.user_id = l.user_id
            left join identity.v_users u on u.id = l.user_id
            where l.accessed_at >= {since}
              and ({filters.Token}::bigint is null or l.token = {filters.Token}::bigint)
              and ({filters.Page}::text = '' or l.page like '%' || {filters.Page}::text || '%')
            order by l.id desc
            limit {MaxDownloadRows}
            """).ToListAsync(ct);
    }

    private static string Trimmed(string? value) => (value ?? string.Empty).Trim(' ', '\t', '\n', '\r', '\0', '\v');
}
