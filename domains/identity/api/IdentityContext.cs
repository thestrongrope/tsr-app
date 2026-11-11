using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// identity's tables, schema "identity": the <c>users</c> row (who someone is and when they last signed in)
/// and the account deletion requests that gate sign-in. Column names follow PHP's, so the data move is a copy.
/// </summary>
internal sealed class IdentityContext(DbContextOptions<IdentityContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "identity";

    public DbSet<User> Users => Set<User>();

    public DbSet<AccountDeletionRequest> AccountDeletionRequests => Set<AccountDeletionRequest>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(user =>
        {
            user.Property(u => u.CreatedOn).HasColumnName("createdon");
            user.Property(u => u.LastLogin).HasColumnName("lastlogin");
            user.Property(u => u.LastLoginIp).HasColumnName("lastloginip");
            user.Property(u => u.LastDevice).HasColumnName("lastdevice");
            user.Property(u => u.Email).HasMaxLength(255);
            user.Property(u => u.Provider).HasMaxLength(10);
            user.Property(u => u.FirebaseUid).HasMaxLength(128);
            user.Property(u => u.LastLoginIp).HasMaxLength(100);
            user.Property(u => u.LastDevice).HasMaxLength(2000);
            user.Property(u => u.Device).HasMaxLength(200);
            user.Property(u => u.Platform).HasMaxLength(200);
            user.Property(u => u.Version).HasMaxLength(200);
            user.HasIndex(u => u.Token).HasDatabaseName("idx_users_token");
            user.HasIndex(u => u.Email).HasDatabaseName("idx_users_email");
            user.HasIndex(u => u.FirebaseUid).IsUnique().HasDatabaseName("idx_users_firebase_uid");
        });

        modelBuilder.Entity<AccountDeletionRequest>(request =>
        {
            request.Property(r => r.Status).HasMaxLength(30);
            request.Property(r => r.ContactEmail).HasMaxLength(200);
            request.Property(r => r.Source).HasMaxLength(3).HasDefaultValue("app");
            request.Property(r => r.Reason).HasMaxLength(500);
            request.Property(r => r.ContactName).HasMaxLength(200);
            request.Property(r => r.OperatorNote).HasMaxLength(1000);
            request.HasIndex(r => r.Token).HasDatabaseName("idx_account_deletion_requests_token");
            request.HasIndex(r => r.ContactEmail).HasDatabaseName("idx_account_deletion_requests_contact_email");
            request.HasIndex(r => new { r.Status, r.RequestedAt }).HasDatabaseName("idx_status_requested");
            // PHP: a STORED generated column active_token behind a unique key. Here the same rule as a partial unique index: one live request per member.
            request.HasIndex(r => r.Token, "uq_active_token").IsUnique().HasFilter("status in ('pending', 'awaiting_prize_delivery')");
            request.ToTable(t => t.HasCheckConstraint(
                "ck_account_deletion_requests_status",
                "status in ('pending', 'awaiting_prize_delivery', 'completed', 'cancelled')"));
            request.ToTable(t => t.HasCheckConstraint("ck_account_deletion_requests_source", CheckSql.In("source", "app", "web")));
        });
    }
}

/// <summary>
/// One row of PHP's <c>users</c>: the identity columns only. The profile columns (gender among them) moved to membership's
/// <c>member_profiles</c>, the role to <c>access.user_roles</c>.
/// </summary>
internal sealed class User
{
    public int Id { get; set; }

    public int Token { get; set; }

    public string? Email { get; set; }

    public string? Provider { get; set; }

    public string? FirebaseUid { get; set; }

    public DateTimeOffset? CreatedOn { get; set; }

    public DateTimeOffset? LastLogin { get; set; }

    public string? LastLoginIp { get; set; }

    public string? LastDevice { get; set; }

    public string? Device { get; set; }

    public string? Platform { get; set; }

    public string? Version { get; set; }
}

/// <summary>
/// The part of PHP's <c>account_deletion_requests</c> that sign-in reads. Completion clears
/// <c>users.email</c>, so the "deleted a moment ago" check matches <c>ContactEmail</c> here, not the user row.
/// </summary>
internal sealed class AccountDeletionRequest
{
    public int Id { get; set; }

    public int? Token { get; set; }

    public string Status { get; set; } = "pending";

    public string? ContactEmail { get; set; }

    public DateTimeOffset RequestedAt { get; set; }

    public DateTimeOffset? CompletedAt { get; set; }

    /// <summary>Which front door raised the request: <c>app</c> or <c>web</c>.</summary>
    public string Source { get; set; } = "app";

    /// <summary>The member's own words, optional.</summary>
    public string? Reason { get; set; }

    /// <summary>Copied at request time, survives anonymisation.</summary>
    public string? ContactName { get; set; }

    /// <summary>Shown to the app while the request awaits prize delivery.</summary>
    public string? OperatorNote { get; set; }

    public DateTimeOffset? CancelledAt { get; set; }

    /// <summary>Completion is refused while this is null.</summary>
    public DateTimeOffset? ConfirmationSentAt { get; set; }

    /// <summary>The operator's <c>users.token</c>, null while unworked.</summary>
    public int? HandledBy { get; set; }
}
