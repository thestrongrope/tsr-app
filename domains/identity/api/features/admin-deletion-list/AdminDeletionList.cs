using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.AdminDeletionList;

// Slice: GET /admin/deletion-requests?status= (PHP admin_deletion_requests.php route_admin_deletion_requests): the queue an administrator works, newest first, with a count per status.
// Signed in (a create route), deletion-requests:manage (403). A status that is not one of the four is no filter. At most 1000 requests (PHP has no limit). Contract: spec/api.yaml.
// Privacy: the postal code and mobile of a member appear only while their request is held for prize delivery (DeletionViews.AdminView).

internal static class AdminDeletionListSlice
{
    public static IEndpointRouteBuilder MapAdminDeletionList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/deletion-requests", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, IdentityContext db, Permissions permissions, CancellationToken ct)
    {
        var refusal = await DeletionRequests.RefuseAsync(context.GetCaller(), permissions, "deletion-requests:manage", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        string? status = context.Request.Query["status"].ToString();
        if (!DeletionViews.Statuses.Contains(status, StringComparer.Ordinal))
        {
            status = null;
        }

        var rows = await DeletionRequests.QueryAsync(db, null, status, null, ct);
        var demo = await DeletionRequests.DemoTokensAsync(db, ct);
        return Results.Json(new Dictionary<string, object?>
        {
            ["counts"] = await DeletionRequests.CountsAsync(db, ct),
            ["requests"] = rows.Select(row => DeletionViews.AdminView(row, demo)).ToList(),
        });
    }
}
