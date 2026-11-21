using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// Finds, claims and creates the member row behind a verified Firebase identity, as PHP's
/// getFromFirebase / getOrCreateFromFirebase do: by Firebase uid first, then by email (citext, so case is
/// ignored), and an email claims a row only when the token says it is verified.
/// </summary>
internal sealed partial class MemberDirectory(IdentityContext db, TimeProvider clock, IProfileSink profiles, ILogger<MemberDirectory> logger)
{

    /// <summary>The member's row, or null (the caller answers 404). With <paramref name="create"/> a first sign-in adds the row.</summary>
    public async Task<User?> FindAsync(FirebaseIdentity who, bool create, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(who);

        var byUid = await db.Users.FirstOrDefaultAsync(u => u.FirebaseUid == who.Uid, ct);
        if (byUid is not null)
        {
            return byUid;
        }

        var byEmail = await db.Users.OrderBy(u => u.Id).FirstOrDefaultAsync(u => u.Email == who.Email, ct);
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
            byEmail.FirebaseUid = who.Uid;
            byEmail.Provider = "firebase";
            await db.SaveChangesAsync(ct);
            await profiles.RecordSignInAsync(byEmail.Id, who.Name, who.Picture, isNewMember: false, ct);
        }
        else if (string.IsNullOrEmpty(byEmail.FirebaseUid))
        {
            byEmail.FirebaseUid = who.Uid;
            await db.SaveChangesAsync(ct);
        }

        return byEmail;
    }

    /// <summary>The status of this member's live deletion request (pending, awaiting_prize_delivery), or null.</summary>
    public Task<string?> LiveDeletionStatusAsync(int token, CancellationToken ct) =>
        db.AccountDeletionRequests.AsNoTracking()
            .Where(r => r.Token == token && (r.Status == "pending" || r.Status == "awaiting_prize_delivery"))
            .Select(r => r.Status)
            .FirstOrDefaultAsync(ct);

    /// <summary>True when this email's account was deleted less than <see cref="DeletionGate.ResurrectionWindow"/> ago.</summary>
    public Task<bool> RecentlyDeletedAsync(string email, CancellationToken ct)
    {
        var cutoff = clock.GetUtcNow() - DeletionGate.ResurrectionWindow;
        return db.AccountDeletionRequests.AsNoTracking()
            .AnyAsync(r => r.Status == "completed" && r.ContactEmail == email && r.CompletedAt >= cutoff, ct);
    }

    /// <summary>
    /// Records this sign-in on the member's row, by email as PHP does, and only when the request carried at least one tracking value. A failure is logged and the
    /// request goes on: tracking must never fail a request.
    /// </summary>
    public async Task RecordSignInAsync(User user, LoginTracking tracking, CancellationToken ct)
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
            await db.Users.Where(u => u.Email == user.Email).ExecuteUpdateAsync(
                set =>
                {
                    set.SetProperty(u => u.LastLogin, now);
                    SetIfPresent(set, tracking);
                },
                ct);
        }
        catch (Exception e) when (e is DbException or InvalidOperationException)
        {
            LogTrackingFailed(e.GetType().Name);
        }
    }

    private static void SetIfPresent(Microsoft.EntityFrameworkCore.Query.UpdateSettersBuilder<User> set, LoginTracking tracking)
    {
        if (tracking.Ip is not null)
        {
            set.SetProperty(u => u.LastLoginIp, tracking.Ip);
        }

        if (tracking.UserAgent is not null)
        {
            set.SetProperty(u => u.LastDevice, tracking.UserAgent);
        }

        if (tracking.Device is not null)
        {
            set.SetProperty(u => u.Device, tracking.Device);
        }

        if (tracking.Platform is not null)
        {
            set.SetProperty(u => u.Platform, tracking.Platform);
        }

        if (tracking.Version is not null)
        {
            set.SetProperty(u => u.Version, tracking.Version);
        }
    }

    // PHP writes the token's name and picture into the same row on create and on a claim (getOrCreateFromFirebase): here that is the profile sink.
    private async Task<User> CreateAndRecordAsync(FirebaseIdentity who, CancellationToken ct)
    {
        var user = await CreateAsync(who, ct);
        await profiles.RecordSignInAsync(user.Id, who.Name, who.Picture, isNewMember: true, ct);
        return user;
    }

    // Token is max + 1 as in PHP, made safe by a transaction-scoped lock: two first sign-ins at once
    // cannot read the same maximum. A second sign-in racing on the same uid hits the unique index and reads the winner.
    private async Task<User> CreateAsync(FirebaseIdentity who, CancellationToken ct)
    {
        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(ct);
            var token = await TokenAllocation.NextAsync(EfTransaction.Join(db), ct);
            var user = new User
            {
                Email = who.Email,
                Provider = "firebase",
                FirebaseUid = who.Uid,
                Token = token,
                CreatedOn = clock.GetUtcNow(),
            };
            db.Users.Add(user);
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return user;
        }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            db.ChangeTracker.Clear();
            return await db.Users.FirstOrDefaultAsync(u => u.FirebaseUid == who.Uid, ct)
                ?? throw new InvalidOperationException("Duplicate key without a stored row", e);
        }
    }

    [LoggerMessage(Level = LogLevel.Information, Message = "auth.unverified_email_refused member={Member} firebase_uid={Uid}")]
    private partial void LogUnverifiedClaim(int member, string uid);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Sign-in tracking failed: {Reason}")]
    private partial void LogTrackingFailed(string reason);
}
