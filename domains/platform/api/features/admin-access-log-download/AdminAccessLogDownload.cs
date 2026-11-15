using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Features.AdminAccessLogDownload;

// Slice: GET /admin/access-log/download?format=xlsx|pdf&token=&page= -> every access of the last 30 days that matches, as a file (the web CSV's columns). Contract: spec/api.yaml.
// PHP: routes/access_log.php route_admin_access_log_download (:84). Order as PHP: format (422, before the sign-in), sign-in, audit-log:read (403), filters (422), 404 "No accesses match" when none.
// Title "Admin access log", heading "Admin access log, last 30 days, <today>", file "TSR_Admin_Access_Log_<YYYYMMDD_HHMMSS>.<format>" (UTC). Every cell goes through AccessLog.SpreadsheetSafe (a leading apostrophe on a formula-like value), so the numbers are text, as PHP.

internal static class AdminAccessLogDownloadSlice
{
    private static readonly string[] Headers = ["Time", "Member", "Name", "Email", "Role", "Method", "Page", "Address", "Device", "Referrer"];

    public static IEndpointRouteBuilder MapAdminAccessLogDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/access-log/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, PlatformContext db, Permissions permissions, ReportExport export, TimeProvider clock, CancellationToken ct)
    {
        if (!ReportExport.TryGetFormat(context, out var format))
        {
            return ReportExport.FormatRefusal(context)!;
        }

        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "audit-log:read", AccessTarget.None, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that");
        }

        var (filters, refusal) = AccessLog.ReadFilters(context);
        if (filters is null)
        {
            return refusal!;
        }

        var accesses = await AccessLog.AccessesAsync(db, AccessLog.WindowStart(clock), filters, ct);
        if (accesses.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "No accesses match");
        }

        IReadOnlyList<IReadOnlyList<object?>> rows = [.. accesses.Select(a => (IReadOnlyList<object?>)new object?[]
        {
            AccessLog.SpreadsheetSafe(a.AccessedAt),
            AccessLog.SpreadsheetSafe(a.Token.ToString(CultureInfo.InvariantCulture)),
            AccessLog.SpreadsheetSafe(a.Name),
            AccessLog.SpreadsheetSafe(a.Email),
            AccessLog.SpreadsheetSafe(AccessLog.RoleName(a.RoleId)),
            AccessLog.SpreadsheetSafe(a.Method),
            AccessLog.SpreadsheetSafe(a.Page),
            AccessLog.SpreadsheetSafe(a.Ip),
            AccessLog.SpreadsheetSafe(a.UserAgent),
            AccessLog.SpreadsheetSafe(a.Referer),
        })];
        var now = clock.GetUtcNow().UtcDateTime;
        var heading = "Admin access log, last 30 days, " + now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        return await export.DownloadAsync(format, "Admin access log", [new ReportSection(heading, Headers, rows)], "TSR_Admin_Access_Log_" + now.ToString("yyyyMMdd_HHmmss", CultureInfo.InvariantCulture), ct);
    }
}
