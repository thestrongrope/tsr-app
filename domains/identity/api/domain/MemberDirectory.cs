using System.Data.Common;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>The sign-in's view of a <c>users</c> row: the columns the middleware and the claim read.</summary>
internal sealed record SignedInUser(int Id, int Token, string? Email, string? FirebaseUid);

/// <summary>
/// Finds, claims and creates the member row behind a verified Firebase identity, as PHP's
/// getFromFirebase / getOrCreateFromFirebase do: by Firebase uid first, then by email (citext, so case is
/// ignored), and an email claims a row only when the token says it is verified.
/// </summary>
internal sealed partial class MemberDirectory(NpgsqlDataSource source, TimeProvider clock, IProfileSink profiles, ILogger<MemberDirectory> logger)
{
    /// <summary>The member's row, or null (the caller answers 404). With <paramref name="create"/> a first sign-in adds the row.</summary>
    public async Task<SignedInUser?> FindAsync(FirebaseIdentity who, bool create, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(who);

        var byUid = await FindByUidAsync(who.Uid, ct);
        if (byUid is not null)
        {
            return byUid;
        }

        var byEmail = (await source.ListAsync(
            $"select id as \"Id\", token as \"Token\", email as \"Email\", firebase_uid as \"FirebaseUid\" from identity.users where email = {who.Email}::citext order by id limit 1",
            ReadUser,
            ct)).FirstOrDefault();
        if (byEmail is null)
        {
            return create ? await CreateAndRecordAsync(who, ct) : null;
        }

        if (!who.EmailVerified)
        {
            // Anyone can make a Firebase account for any address; only a verified one may claim a member.
            LogUnverifiedClaim(byEmail.Token, who.Uid);
            return null;
        }

        // PHP: a create route always stamps the uid (and provider); a lookup route only fills an empty one.
        if (create)
        {
            await source.ExecuteAsync($"update identity.users set firebase_uid = {who.Uid}, provider = 'firebase' where id = {byEmail.Id}", ct);
            await profiles.RecordSignInAsync(byEmail.Id, who.Name, who.Picture, isNewMember: false, ct);
            return byEmail with { FirebaseUid = who.Uid };
        }

        if (string.IsNullOrEmpty(byEmail.FirebaseUid))
        {
            await source.ExecuteAsync($"update identity.users set firebase_uid = {who.Uid} where id = {byEmail.Id}", ct);
            return byEmail with { FirebaseUid = who.Uid };
        }

        return byEmail;
    }

    /// <summary>The status of this member's live deletion request (pending, awaiting_prize_delivery), or null.</summary>
    public async Task<string?> LiveDeletionStatusAsync(int token, CancellationToken ct) =>
        (await source.ListAsync(
            $"select status as \"Status\" from identity.account_deletion_requests where token = {token} and status in ('pending', 'awaiting_prize_delivery') limit 1",
            row => row.Text("Status"),
            ct)).FirstOrDefault();

    /// <summary>True when this email's account was deleted less than <see cref="DeletionGate.ResurrectionWindow"/> ago.</summary>
    public async Task<bool> RecentlyDeletedAsync(string email, CancellationToken ct)
    {
        var cutoff = clock.GetUtcNow() - DeletionGate.ResurrectionWindow;
        var found = await source.ScalarAsync<bool>(
            $"select exists (select 1 from identity.account_deletion_requests where status = 'completed' and contact_email = {email}::citext and completed_at >= {cutoff}) as \"Value\"",
            ct);
        return found ?? false;
    }

    /// <summary>
    /// Records this sign-in on the member's row, by email as PHP does, and only when the request carried at least one tracking value. A failure is logged and the
    /// request goes on: tracking must never fail a request.
    /// </summary>
    public async Task RecordSignInAsync(SignedInUser user, LoginTracking tracking, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(user);
        ArgumentNullException.ThrowIfNull(tracking);
        if (user.Email is null || !tracking.HasValues)
        {
            return;
        }

        var now = clock.GetUtcNow();
        try
        {
            // A value the request did not send keeps the stored one (coalesce).
            await source.ExecuteAsync(
                $"""
                update identity.users set
                    lastlogin = {now},
                    lastloginip = coalesce({tracking.Ip}::citext, lastloginip),
                    lastdevice = coalesce({tracking.UserAgent}::citext, lastdevice),
                    device = coalesce({tracking.Device}::citext, device),
                    platform = coalesce({tracking.Platform}::citext, platform),
                    version = coalesce({tracking.Version}::citext, version)
                where email = {user.Email}::citext
                """,
                ct);
        }
        catch (Exception e) when (e is DbException or InvalidOperationException)
        {
            LogTrackingFailed(e.GetType().Name);
        }
    }

    private static SignedInUser ReadUser(DbRow row) =>
        new(row.Int("Id"), row.Int("Token"), row.TextOrNull("Email"), row.TextOrNull("FirebaseUid"));

    private async Task<SignedInUser?> FindByUidAsync(string uid, CancellationToken ct) =>
        (await source.ListAsync(
            $"select id as \"Id\", token as \"Token\", email as \"Email\", firebase_uid as \"FirebaseUid\" from identity.users where firebase_uid = {uid}::citext limit 1",
            ReadUser,
            ct)).FirstOrDefault();

    // PHP writes the token's name and picture into the same row on create and on a claim (getOrCreateFromFirebase): here that is the profile sink.
    private async Task<SignedInUser> CreateAndRecordAsync(FirebaseIdentity who, CancellationToken ct)
    {
        var user = await CreateAsync(who, ct);
        await profiles.RecordSignInAsync(user.Id, who.Name, who.Picture, isNewMember: true, ct);
        return user;
    }

    // Token is max + 1 as in PHP, made safe by a transaction-scoped lock: two first sign-ins at once
    // cannot read the same maximum. A second sign-in racing on the same uid hits the unique index and reads the winner.
    // The catch sits outside the transaction, so the aborted one is rolled back and its connection released before the re-read.
    private async Task<SignedInUser> CreateAsync(FirebaseIdentity who, CancellationToken ct)
    {
        try
        {
            return await InsertAsync(who, ct);
        }
        catch (PostgresException e) when (e.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return await FindByUidAsync(who.Uid, ct)
                ?? throw new InvalidOperationException("Duplicate key without a stored row", e);
        }
    }

    private async Task<SignedInUser> InsertAsync(FirebaseIdentity who, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var token = await TokenAllocation.NextAsync(tx, ct);
        var id = await tx.ScalarAsync<int>(
            $"insert into identity.users (email, provider, firebase_uid, token, createdon) values ({who.Email}, 'firebase', {who.Uid}, {token}, {clock.GetUtcNow()}) returning id as \"Value\"",
            ct);
        await tx.CommitAsync(ct);
        return new SignedInUser(id ?? throw new InvalidOperationException("Insert returned no id"), token, who.Email, who.Uid);
    }

    [LoggerMessage(Level = LogLevel.Information, Message = "auth.unverified_email_refused member={Member} firebase_uid={Uid}")]
    private partial void LogUnverifiedClaim(int member, string uid);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Sign-in tracking failed: {Reason}")]
    private partial void LogTrackingFailed(string reason);
}
