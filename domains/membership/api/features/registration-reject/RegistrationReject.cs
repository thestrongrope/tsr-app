using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.RegistrationReject;

// Slice: POST /registrations/{registration_id}/reject {reason} -> {rejected: true, registrationId}: turn a waiting registrant down. Order (PHP routes/registrations.php
// route_registrations_reject, api_require_waiting_registrant): registrations:read for the registrations of NEITHER gender is 403 (before the id is looked up); the registrant
// (the registration whose id is the highest of its member, whose status is not Rejected by the member's highest status, holding no live enrolment in an active class, whose email does
// not end @thestrongrope.com; none is 409 "This registrant is no longer waiting: they have been placed or rejected."); registrations:read for the registrant's gender (403); then
// registrations:reject for that gender (403, "You do not have permission to do that"), so a grant reaching one gender cannot reject the other's; the body (422 Invalid JSON);
// the reason a string, trimmed, 1 to 500 characters (422 "reason is required, at most 500 characters"; a NUL byte is the same 422, a deviation: PHP stores it). The UPDATE changes
// EVERY registration row of the member: status Rejected, reason, status date, modified at and by (SubscribersModel::rejectRegistration). Contract: spec/api.yaml.
// Event membership.registration_rejected (registrationId, token, rejectedBy). The waiting-registrant query is classes' WaitingRegistrant ported on membership's own tables
// (classes owns its copy; they share no code across domains).

internal static class RegistrationRejectSlice
{
    internal sealed record RegistrationRejected(long RegistrationId, int Token, int RejectedBy);

    private sealed record Row(int Token, string? Gender);

    public static IEndpointRouteBuilder MapRegistrationReject(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/registrations/{registration_id}/reject", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string registration_id, HttpContext context, MembershipContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "registrations:read", AccessTarget.ForGender(1), ct)
            && !await permissions.CanAsync(caller, "registrations:read", AccessTarget.ForGender(2), ct))
        {
            return Refusals.NotPermitted();
        }

        var registrationId = PhpValue.IntOfText(registration_id);
        var registrant = await FindWaitingAsync(db, registrationId, ct);
        if (registrant is null)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This registrant is no longer waiting: they have been placed or rejected.");
        }

        var gender = AccessTarget.ForGender((int)PhpValue.IntOfText(registrant.Gender ?? string.Empty));
        if (!await permissions.CanAsync(caller, "registrations:read", gender, ct) || !await permissions.CanAsync(caller, "registrations:reject", gender, ct))
        {
            return Refusals.NotPermitted();
        }

        var raw = await BodyReader.ReadAsync(context.Request, ct);
        if (raw is null)
        {
            return Problem.Detail(StatusCodes.Status413PayloadTooLarge, "Request body too large");
        }

        var parsed = JsonBody.Parse(raw);
        if (!parsed.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, parsed.Error!);
        }

        var typed = parsed.Value!.Get("reason");
        var reason = RejectReason.Parse(typed.ValueKind == JsonValueKind.String ? typed.GetString() : null);
        if (reason is null)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, RejectReason.Required);
        }

        if (!await RejectAsync(db, clock, registrationId, registrant.Token, reason, caller.UserId, ct))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This registrant is no longer waiting: they have been placed or rejected.");
        }

        return Results.Json(new Dictionary<string, object?> { ["rejected"] = true, ["registrationId"] = registrationId });
    }

    // False when the registrant stopped waiting since the handler looked (another rejection got there first): nothing is written. The member's rows are locked, then the
    // waiting check is asked again, so two rejections at the same moment write one event (PHP has the same race, and no event).
    private static async Task<bool> RejectAsync(MembershipContext db, TimeProvider clock, long registrationId, int token, string reason, int userId, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.SqlQuery<long>($"""select id::bigint as "Value" from membership.class_registrations where token = {token} order by id for update""").ToListAsync(ct);
        if (await FindWaitingAsync(db, registrationId, ct) is null)
        {
            return false;
        }

        await db.ClassRegistrations
            .Where(r => r.Token == token)
            .ExecuteUpdateAsync(
                set => set.SetProperty(r => r.Status, "Rejected").SetProperty(r => r.StatusReason, reason)
                    .SetProperty(r => r.StatusDate, now).SetProperty(r => r.ModifiedAt, now).SetProperty(r => r.ModifiedBy, userId),
                ct);
        await Outbox.WriteAsync(db, "membership.registration_rejected", new RegistrationRejected(registrationId, token, userId), clock, ct);
        await transaction.CommitAsync(ct);
        return true;
    }

    // PHP groups the registrations by token and takes each column's MAX, so the "latest" row is the one with the highest id and the status is the highest of the member's.
    private static async Task<Row?> FindWaitingAsync(MembershipContext db, long registrationId, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<Row>($"""
                select r.token as "Token", p.gender as "Gender"
                from (select max(id) as id, max(token) as token, max(status) as status, max(created_at) as created_at from membership.class_registrations group by token) r
                join identity.v_users u on u.token = r.token
                left join membership.member_profiles p on p.user_id = u.id
                where r.status <> 'Rejected'
                  and not exists (select 1 from classes.v_enrolments cs join classes.v_classes c on c.id = cs.class_id
                                  where cs.token_no = r.token and c.status = 'A' and cs.removed_at is null)
                  and u.email not like '%@thestrongrope.com'
                  and r.id = {registrationId}
                order by r.created_at desc, u.id
                limit 1
                """)
            .ToListAsync(ct);
        return rows.Count == 0 ? null : rows[0];
    }
}
