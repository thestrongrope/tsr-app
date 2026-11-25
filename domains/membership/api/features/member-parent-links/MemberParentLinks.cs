using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.MemberParentLinks;

// Slice: GET /members/{child_token}/parent-links -> the caller's own unused, unexpired invites for this child, newest first, at most 5: [{id, created_at, expires_at}]. The code is
// not returned. Same guard as the invite creation (domain/GuardianChecks.RequireParentLinkAsync). Contract: spec/api.yaml.
// PHP: routes/children.php route_member_parent_links_list, GuardiansModel::pendingInvitesFor. expires_at is "" when the stored value is empty (PHP casts null to a string).

internal static class MemberParentLinksSlice
{
    public static IEndpointRouteBuilder MapMemberParentLinks(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/members/{child_token}/parent-links", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string child_token, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var childToken = PhpValue.IntOfText(child_token);
        var refusal = await GuardianChecks.RequireParentLinkAsync(source, permissions, caller, childToken, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        if (childToken > int.MaxValue)
        {
            return Results.Json(new List<Dictionary<string, object?>>(), MembershipJson.Answers.AnswerList);
        }

        var token = (int)childToken;
        var now = clock.GetUtcNow();
        var rows = await source.ListAsync(GuardianRows.OpenInvites(token, caller.UserId, now, GuardianRules.MaxPendingInvites), GuardianRows.Read, ct);
        return Results.Json(rows.Select(r => new Dictionary<string, object?>
        {
            ["id"] = r.Id,
            ["created_at"] = LinkRowView.Stamp(r.CreatedAt),
            ["expires_at"] = r.ExpiresAt is { } expires ? LinkRowView.Stamp(expires) : string.Empty,
        }).ToList(), MembershipJson.Answers.AnswerList);
    }
}
