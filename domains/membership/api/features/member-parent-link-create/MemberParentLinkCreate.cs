using System.Security.Cryptography;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Microsoft.Extensions.Configuration;
using Tsr.Access.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.MemberParentLinkCreate;

// Slice: POST /members/{child_token}/parent-links -> 201 {code, link, url, expires_at}: a one-time invite a parent can accept, made by the child (parents:manage) or by staff in
// reach (parents:add). Order: guard (domain/GuardianChecks.RequireParentLinkAsync: token <= 0 is 404 "Student not found" first, then the permission rules), the child must be one
// registered member (a guest, an unknown or an ambiguous token is 404 "Student not found"), then under the child's guardian lock at most 5 unexpired invites (422 "At most 5
// pending invites allowed"), then the row (source link, 32 hex characters of code, expires in 7 days). Contract: spec/api.yaml.
// PHP: routes/children.php route_member_parent_links_create (api_require_parent_link_create), GuardiansModel::createInvite and insertInvite. `link` and `url` are the same:
// PHP's public_web_base() (from REDIRECT_URI) plus /link/<code>; here TSR_PUBLIC_WEB_BASE (unset: no base, as PHP without REDIRECT_URI). Event membership.parent_invite_created
// (inviteId, childToken, createdBy; never the code).

internal static class MemberParentLinkCreateSlice
{
    internal sealed record InviteCreated(int InviteId, int ChildToken, int CreatedBy);

    public static IEndpointRouteBuilder MapMemberParentLinkCreate(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/members/{child_token}/parent-links", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string child_token,
        HttpContext context,
        NpgsqlDataSource source,
        Permissions permissions,
        UserDirectory users,
        IConfiguration configuration,
        TimeProvider clock,
        CancellationToken ct)
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

        var child = await GuardianChecks.ValidateMemberAsync(source, users, childToken, ct);
        if (child.Status != MemberCheck.Ok)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, GuardianChecks.StudentNotFound);
        }

        var code = Convert.ToHexStringLower(RandomNumberGenerator.GetBytes(16));
        var now = clock.GetUtcNow();
        var expires = now.AddDays(GuardianRules.InviteExpiryDays);
        await using var tx = await source.BeginAsync(ct);
        await GuardianLock.TakeAsync(tx, child.UserId, ct);
        var token = (int)childToken;
        var pending = await tx.ScalarAsync<long>(
            $"select count(*) as \"Value\" from membership.user_guardians where child_token = {token} and status = 'invited' and (expires_at is null or expires_at > {now})",
            ct);
        if (pending >= GuardianRules.MaxPendingInvites)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "At most 5 pending invites allowed");
        }

        var inviteId = await tx.ScalarAsync<int>(
            $"""
            insert into membership.user_guardians (child_token, status, source, code, expires_at, created_by, created_at)
            values ({token}, 'invited', 'link', {code}, {expires}, {caller.UserId}, {now})
            returning id as "Value"
            """,
            ct);
        await Outbox.WriteAsync(tx, "membership.parent_invite_created", new InviteCreated(inviteId!.Value, token, caller.UserId), MembershipJson.Default.InviteCreated, clock, ct);
        await tx.CommitAsync(ct);

        var link = (configuration["TSR_PUBLIC_WEB_BASE"] ?? string.Empty).TrimEnd('/') + "/link/" + code;
        return Results.Json(
            new Dictionary<string, object?> { ["code"] = code, ["link"] = link, ["url"] = link, ["expires_at"] = LinkRowView.Stamp(expires) },
            MembershipJson.Answers.Answer,
            statusCode: StatusCodes.Status201Created);
    }
}
