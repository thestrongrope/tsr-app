using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Identity.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.DeletionRequestGet;

// Slice: GET /me/deletion-request (PHP route_deletion_request_get): what the app shows when the screen opens. Signed in (a create route), account:delete (403). The live request, or the
// same shape with status "none" (a settled request is not reported). Contract: spec/api.yaml.

internal static class DeletionRequestGetSlice
{
    public static IEndpointRouteBuilder MapDeletionRequestGet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/deletion-request", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, IdentityContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        var refusal = await DeletionRequests.RefuseAsync(caller, permissions, "account:delete", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var row = await DeletionRequests.ActiveForAsync(db, caller!.Token, ct);
        return Results.Json(DeletionViews.MemberView(row), IdentityJson.Answers.Answer);
    }
}
