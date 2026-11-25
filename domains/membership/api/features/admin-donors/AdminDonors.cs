using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.AdminDonors;

// Slice: GET /admin/donors -> {donors: [{name, email, mobile, city, state, country, zip}]}: every member in an active class, ordered by name. Permission donors:read. Contract: spec/api.yaml.
// PHP: routes/donors.php route_admin_donors, SubscribersModel::getDonorList. The query and its quirks (no distinct, no reach limit, text? columns) are domain/DonorList.cs (shared with the download).

internal static class AdminDonorsSlice
{
    public static IEndpointRouteBuilder MapAdminDonors(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/donors", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "donors:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var rows = await DonorList.LoadAsync(source, ct);
        var donors = rows.Select(d => new Dictionary<string, object?>
        {
            ["name"] = d.Name,
            ["email"] = d.Email,
            ["mobile"] = d.Mobile,
            ["city"] = d.City,
            ["state"] = d.State,
            ["country"] = d.Country,
            ["zip"] = d.Zip,
        }).ToList();
        return Results.Json(new Dictionary<string, object?> { ["donors"] = donors }, MembershipJson.Answers.Answer);
    }
}
