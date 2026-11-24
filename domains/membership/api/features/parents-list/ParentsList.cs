using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ParentsList;

// Slice: GET /me/parents -> the caller's active parents (the caller as the child). Permission parents:manage. Contract: spec/api.yaml.
// PHP: routes/children.php route_child_parents_list, GuardiansModel::linksForChild.

internal static class ParentsListEndpoint
{
    public const string Permission = "parents:manage";

    public static IEndpointRouteBuilder MapParentsList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/me/parents",
            (HttpContext context, ParentsListHandler handler) => handler.HandleAsync(context.GetCaller(), context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class ParentsListHandler(NpgsqlDataSource source, Permissions permissions, LinkLister lister)
{
    public async Task<IResult> HandleAsync(Caller? caller, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, ParentsListEndpoint.Permission, AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var token = caller.Token;
        var rows = await source.ListAsync(GuardianRows.ActiveOfChild(token, LinkLister.MaxRows), GuardianRows.Read, ct);
        return Results.Json(await lister.ShowAsync(rows, LinkRowView.ParentName, g => g.ParentToken, ct), MembershipJson.Answers.JsonArray);
    }
}
