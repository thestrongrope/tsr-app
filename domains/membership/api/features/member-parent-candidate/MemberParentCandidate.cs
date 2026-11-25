using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.MemberParentCandidate;

// Slice: GET /members/{child_token}/parents/candidate/{parent_token} -> {name}: the display name of a member, for staff to confirm before adding them as a parent by token.
// Order: parents:add-direct (403), 30 lookups an hour per caller (429 "Too many lookups; try again later", counted for every call that passes the permission), then staff in reach of
// the child (domain/GuardianChecks.StaffMayAddForAsync, direct): out of reach, a guest, an unknown or a missing member is 404 "Member not found"; a token shared by several members
// is 422 {detail, code: "ambiguous_token"}, told only to staff in reach. The answer carries the name only (null name is ""). Contract: spec/api.yaml.
// PHP: routes/children.php route_member_parent_candidate, GuardiansModel::candidateLookup and validateMemberToken. The limit is in memory per process here (PHP keeps it in a file).

internal static class MemberParentCandidateSlice
{
    public static IEndpointRouteBuilder MapMemberParentCandidate(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/members/{child_token}/parents/candidate/{parent_token}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string child_token,
        string parent_token,
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        UserDirectory users,
        MemberRateLimit limit,
        CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "parents:add-direct", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        if (!limit.Allow("parent_candidate", caller.Token, 30, 3600))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, GuardianRules.TooManyLookups);
        }

        if (!await GuardianChecks.StaffMayAddForAsync(source, permissions, caller, PhpValue.IntOfText(child_token), direct: true, ct))
        {
            return NotFound();
        }

        var parent = await GuardianChecks.ValidateMemberAsync(source, users, PhpValue.IntOfText(parent_token), ct);
        if (parent.Status == MemberCheck.Ambiguous)
        {
            return Refusals.AmbiguousToken();
        }

        if (parent.Status != MemberCheck.Ok)
        {
            return NotFound();
        }

        var name = (await source.ListAsync($"select name from membership.member_profiles where user_id = {parent.UserId}", row => row.TextOrNull("name"), ct)).FirstOrDefault();
        return Results.Json(new Dictionary<string, object?> { ["name"] = name ?? string.Empty }, MembershipJson.Answers.Answer);
    }

    private static IResult NotFound() => Problem.Detail(StatusCodes.Status404NotFound, "Member not found");
}
