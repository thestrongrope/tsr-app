using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Notifications.Api;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api.Features.AdminDeletionComplete;

// Slice: POST /admin/deletion-requests/{request_id}/complete (PHP route_admin_deletion_request_complete and AccountDeletionModel::complete). IRREVERSIBLE: deletes the member's Firebase
// sign-in, then in ONE transaction redacts the recipient of queued messages (mobile and device ids), anonymises the member (membership's profile and class requests through IMemberErasure,
// then identity's own users row), deletes the member's devices (notifications' command) and feedback (platform's command), and completes the request. Order as PHP: signed in (a create route),
// deletion-requests:manage (403), the request (404), a request naming token 0 (409), the rate limit of 1 a minute per request (409; the key is held even when a refusal follows, so a retry waits),
// then the model's refusals, each 409 with its text: not live, no confirmation recorded, a reviewer demo member, a token with no user row, a token with more than 20 user rows (before any Firebase call), Firebase failing (the database is then untouched).
// A token can have several user rows: every row's Firebase account is deleted (a row's stored uid, which is unique; a row with none by its own email), then every row is anonymised and its feedback erased.
// The Firebase call is OUTSIDE the transaction and cannot be rolled back, so a later database failure leaves the sign-in deleted and the request open for a retry.
// Deviation: a bug or database failure is a 500 here, not a 409 carrying the exception text (PHP catches Throwable and shows it). Events identity.member_erased (token, userId) and
// identity.deletion_completed (requestId, token, handledBy). Contract: spec/api.yaml.

internal static class AdminDeletionCompleteSlice
{
    private const string RateLimited = "This request was just completed or is being completed. Wait a minute and reload.";
    // A token is not unique; more rows than this is refused before any Firebase call so the work stays bounded.
    private const int MaxUserRows = 20;
    private const string NeedsConfirmation = "Send the confirmation email and record it before completing this request";

    private sealed record Member(int Id, string? Email, string? FirebaseUid, string? Mobile);

    private sealed record MemberErased(int Token, int UserId);

    private sealed record DeletionCompleted(int RequestId, int? Token, int HandledBy);

    public static IEndpointRouteBuilder MapAdminDeletionComplete(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/admin/deletion-requests/{request_id}/complete", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(
        string request_id, HttpContext context, IdentityContext db, Permissions permissions, IFirebaseAccounts firebase, IMemberErasure memberErasure,
        MemberRateLimit rateLimit, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        var refusal = await DeletionRequests.RefuseAsync(caller, permissions, "deletion-requests:manage", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var id = DeletionRequests.ParseId(request_id);
        var found = id is null ? null : await DeletionRequests.FindAsync(db, id.Value, ct);
        if (found is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Deletion request not found");
        }

        if (found.Token is <= 0)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, "This request names no member and cannot be completed");
        }

        if (!rateLimit.Allow("deletion_complete", found.Id, 1, 60))
        {
            return Problem.Detail(StatusCodes.Status409Conflict, RateLimited);
        }

        var outcome = await CompleteAsync(db, firebase, memberErasure, clock, found, caller!.Token, ct);
        if (!outcome.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status409Conflict, outcome.Error!);
        }

        var row = await DeletionRequests.FindAsync(db, found.Id, ct) ?? found;
        return Results.Json(new Dictionary<string, object?> { ["request"] = DeletionViews.AdminView(row, await DeletionRequests.DemoTokensAsync(db, ct)) });
    }

    private static async Task<Result<bool>> CompleteAsync(
        IdentityContext db, IFirebaseAccounts firebase, IMemberErasure memberErasure, TimeProvider clock, DeletionRow request, int operatorToken, CancellationToken ct)
    {
        var refusal = await RefusalAsync(db, request, ct);
        if (refusal is not null)
        {
            return Result.Fail<bool>(refusal);
        }

        var members = request.Token is int token ? await FindMembersAsync(db, token, ct) : [];
        if (request.Token is int named && members.Count == 0)
        {
            return Result.Fail<bool>(
                $"Deletion request {request.Id} names token {named}, which has no user row. Check whether a Firebase account still exists for it before closing this request.");
        }

        if (members.Count > MaxUserRows)
        {
            return Result.Fail<bool>(
                $"Deletion request {request.Id} names token {request.Token}, which has more than {MaxUserRows} user rows; at most {MaxUserRows} can be completed here. Remove the extra rows first.");
        }

        var deleted = await DeleteFirebaseAsync(firebase, members, ct);
        if (deleted is not null)
        {
            return Result.Fail<bool>(deleted);
        }

        var failure = await EraseAndCompleteAsync(db, memberErasure, clock, request, members, operatorToken, ct);
        if (failure is not null)
        {
            return Result.Fail<bool>(failure);
        }

        await PurgeExpiredContactDetailsAsync(db, clock, ct);
        return Result.Ok(true);
    }

    // The model's refusals that need no write, in PHP's order.
    private static async Task<string?> RefusalAsync(IdentityContext db, DeletionRow request, CancellationToken ct)
    {
        if (!DeletionViews.IsLive(request.Status))
        {
            return $"Deletion request {request.Id} is already {request.Status} and cannot be completed";
        }

        if (request.ConfirmationSentAt is null)
        {
            return NeedsConfirmation;
        }

        var demo = await DeletionRequests.DemoTokensAsync(db, ct);
        if (request.Token is int token && demo.Contains(token))
        {
            return $"Deletion request {request.Id} belongs to the reviewer demo cohort and cannot be completed. "
                + "Completing it would delete the account an app-store reviewer signs in with. "
                + "Cancel it instead, or run the cohort teardown when the review is finished.";
        }

        return null;
    }

    // Every row of the token in id order; one more than the limit is read so the caller can tell "too many" from "exactly the limit".
    private static async Task<List<Member>> FindMembersAsync(IdentityContext db, int token, CancellationToken ct) =>
        await db.Database
            .SqlQuery<Member>($"""
                select u.id as "Id", u.email as "Email", u.firebase_uid as "FirebaseUid", m.mobile as "Mobile"
                from identity.users u left join membership.v_members m on m.user_id = u.id
                where u.token = {token}
                order by u.id
                limit {MaxUserRows + 1}
                """)
            .ToListAsync(ct);

    // Outside the transaction on purpose: a Google call cannot be rolled back, so it happens first and a failure leaves the database clean.
    // Every row of the token: each row's stored uid (the unique index makes them distinct), and a row without one by its own email. The first failure stops here; accounts already deleted stay deleted, and a retry
    // succeeds because the real client counts an account Firebase no longer knows as done.
    private static async Task<string?> DeleteFirebaseAsync(IFirebaseAccounts firebase, List<Member> members, CancellationToken ct)
    {
        try
        {
            foreach (var member in members)
            {
                await firebase.DeleteAsync(string.IsNullOrEmpty(member.FirebaseUid) ? null : member.FirebaseUid, member.Email, ct);
            }

            return null;
        }
        catch (FirebaseAccountException e)
        {
            return e.Message;
        }
    }

    private static async Task<string?> EraseAndCompleteAsync(
        IdentityContext db, IMemberErasure memberErasure, TimeProvider clock, DeletionRow request, List<Member> members, int operatorToken, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);

        // Guarded on the live statuses: a completion or cancellation that landed since the read wins, and nothing here is written.
        var completed = await db.Database.ExecuteSqlAsync(
            $"""
            update identity.account_deletion_requests set status = 'completed', completed_at = {now}, handled_by = {operatorToken}
            where id = {request.Id} and status::text in ('pending', 'awaiting_prize_delivery')
            """,
            ct);
        if (completed == 0)
        {
            return $"Deletion request {request.Id} is no longer live and cannot be completed";
        }

        if (request.Token is int token && members.Count > 0)
        {
            await EraseMemberAsync(db, memberErasure, token, members, ct);
            await Outbox.WriteAsync(db, "identity.member_erased", new MemberErased(token, members[0].Id), clock, ct);
        }

        await Outbox.WriteAsync(db, "identity.deletion_completed", new DeletionCompleted(request.Id, request.Token, operatorToken), clock, ct);
        await transaction.CommitAsync(ct);
        return null;
    }

    // Before the profile mobile is cleared, not after: outbound_messages has no member key, so a member's rows are found only by matching their recipient values.
    private static async Task EraseMemberAsync(IdentityContext db, IMemberErasure memberErasure, int token, List<Member> members, CancellationToken ct)
    {
        var member = members[0];
        var recipients = new List<string>();
        if (!string.IsNullOrEmpty(member.Mobile))
        {
            recipients.Add(member.Mobile);
        }

        recipients.AddRange(await NotificationsErasure.EraseDevicesAsync(db, token, ct));
        await PlatformCommands.RedactRecipientsAsync(db, recipients, ct);
        await memberErasure.EraseAsync(db, token, ct);

        // The anonymised row: id, token, role, created-on and provider stay (attendance and quiz rows key on the token). The address is unique per member and ends .invalid (RFC 2606).
        var placeholder = $"deleted-{token}@deleted.invalid";
        await db.Database.ExecuteSqlAsync(
            $"""
            update identity.users
            set email = {placeholder}, firebase_uid = null, lastdevice = null, device = null, platform = null, version = null, lastloginip = null
            where token = {token}
            """,
            ct);
        foreach (var row in members)
        {
            await PlatformCommands.EraseFeedbackAsync(db, row.Id, ct);
        }
    }

    // PHP purgeExpiredContactDetails, run after every completion: contact details of completions older than the resurrection window are no longer needed.
    private static async Task PurgeExpiredContactDetailsAsync(IdentityContext db, TimeProvider clock, CancellationToken ct)
    {
        var cutoff = clock.GetUtcNow() - DeletionGate.ResurrectionWindow;
        await db.Database.ExecuteSqlAsync(
            $"""
            update identity.account_deletion_requests set contact_name = null, contact_email = null, reason = null
            where status::text = 'completed' and completed_at is not null and completed_at < {cutoff}
              and (contact_name is not null or contact_email is not null or reason is not null)
            """,
            ct);
    }
}
