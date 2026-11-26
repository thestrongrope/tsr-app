using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ChildrenLinks;

// Slice: GET /me/children/links -> the caller's own parent links, every status (a pending invite has no parent, so only active and
// revoked ones show). Permission children:read. Contract: spec/api.yaml. PHP: routes/children.php route_children_links_list,
// GuardiansModel::linksForParent.

internal static class ChildrenLinksEndpoint
{
    public const string Permission = "children:read";

    public static IEndpointRouteBuilder MapChildrenLinks(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/me/children/links",
            (HttpContext context, ChildrenLinksHandler handler) => handler.HandleAsync(context.GetCaller(), context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class ChildrenLinksHandler(NpgsqlDataSource source, Permissions permissions, LinkLister lister)
{
    public async Task<IResult> HandleAsync(Caller? caller, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, ChildrenLinksEndpoint.Permission, AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var token = caller.Token;
        var rows = await source.ListAsync(GuardianRows.OfParent(token, LinkLister.MaxRows), GuardianRows.Read, ct);
        return Results.Json(await lister.ShowAsync(rows, LinkRowView.ChildName, g => g.ChildToken, ct), MembershipJson.Answers.JsonArray);
    }
}
