using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Features.AdminAccessLog;

// Slice: GET /admin/access-log?token=&page= -> {users, pages, recent}: who used the admin pages (30 days), which pages (30 days) and the latest 500 accesses. Permission audit-log:read. Contract: spec/api.yaml.
// PHP: routes/access_log.php route_admin_access_log (:35), AuditLogModel. Order as PHP: sign-in, audit-log:read (403), filters (422), the three reads. The queries are domain/AccessLog.cs (shared with the download).

internal static class AdminAccessLogSlice
{
    public static IEndpointRouteBuilder MapAdminAccessLog(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/access-log", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, PlatformContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
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

        var since = AccessLog.WindowStart(clock);
        var members = await AccessLog.SummaryByMemberAsync(db, since, filters, ct);
        var pages = await AccessLog.SummaryByPageAsync(db, since, filters, ct);
        var recent = await AccessLog.RecentAsync(db, filters, ct);

        return Results.Json(new Dictionary<string, object?>
        {
            ["users"] = members.Select(m => new Dictionary<string, object?>
            {
                ["token"] = m.Token,
                ["name"] = m.Name,
                ["email"] = m.Email,
                ["hits"] = m.Hits,
                ["activeDays"] = m.ActiveDays,
                ["lastAccessed"] = m.LastAccessed,
            }).ToList(),
            ["pages"] = pages.Select(p => new Dictionary<string, object?>
            {
                ["page"] = p.Page,
                ["hits"] = p.Hits,
                ["lastAccessed"] = p.LastAccessed,
            }).ToList(),
            ["recent"] = recent.Select(r => new Dictionary<string, object?>
            {
                ["id"] = r.Id,
                ["accessedAt"] = r.AccessedAt,
                ["token"] = r.Token,
                ["name"] = r.Name,
                ["email"] = r.Email,
                ["role"] = AccessLog.RoleName(r.RoleId),
                ["method"] = r.Method,
                ["page"] = r.Page,
                ["ip"] = r.Ip,
            }).ToList(),
        });
    }
}
