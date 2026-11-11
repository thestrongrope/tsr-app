using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api;

/// <summary>
/// The platform tables ported from PHP in the schema phase: the audit log of the admin pages, the two lookup tables other tables
/// store ids of (genders, languages) and the delivery queue (push, WhatsApp, search). Names and keys follow PHP's, so the data move is a copy.
/// User references (<c>user_id</c>, <c>token</c>, <c>created_by</c>) are plain integers. Their entities are below.
/// </summary>
internal static class PlatformTables
{
    public static void Configure(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AdminAccessLogEntry>(entry =>
        {
            entry.ToTable("admin_access_log");
            entry.Property(e => e.AccessedAt).HasDefaultValueSql("now()");
            entry.Property(e => e.Page).HasMaxLength(255);
            entry.Property(e => e.Method).HasMaxLength(10);
            entry.Property(e => e.Ip).HasMaxLength(45);
            entry.Property(e => e.UserAgent).HasMaxLength(512);
            entry.Property(e => e.Referer).HasMaxLength(512);
            entry.Property(e => e.SessionId).HasMaxLength(128);
            entry.HasIndex(e => e.AccessedAt).HasDatabaseName("idx_accessed_at");
            entry.HasIndex(e => e.Token).HasDatabaseName("idx_token");
            entry.HasIndex(e => e.Page).HasDatabaseName("idx_page");
        });

        modelBuilder.Entity<Gender>(gender =>
        {
            gender.ToTable("genders");
            gender.Property(g => g.Name).HasMaxLength(100);
        });

        modelBuilder.Entity<Language>(language =>
        {
            language.ToTable("languages");
            language.Property(l => l.Name).HasMaxLength(100);
            language.Property(l => l.CreatedAt).HasDefaultValueSql("now()");
        });

        modelBuilder.Entity<OutboundMessage>(message =>
        {
            message.ToTable("outbound_messages");
            message.Property(m => m.Channel).HasMaxLength(20);
            message.Property(m => m.Recipient).HasMaxLength(500);
            message.Property(m => m.DedupeKey).HasMaxLength(191);
            message.Property(m => m.Status).HasMaxLength(20).HasDefaultValue("queued");
            message.Property(m => m.Attempts).HasDefaultValue(0);
            message.Property(m => m.CreatedAt).HasDefaultValueSql("now()");
            message.Property(m => m.Error).HasMaxLength(65535);
            message.HasIndex(m => new { m.Channel, m.DedupeKey }).IsUnique().HasDatabaseName("uq_channel_dedupe");
            message.HasIndex(m => new { m.Channel, m.Status, m.NextAttemptAt }).HasDatabaseName("idx_claim");
            message.HasIndex(m => m.CreatedAt).HasDatabaseName("idx_created_at");
            message.ToTable(t => t.HasCheckConstraint("ck_outbound_messages_payload_json", CheckSql.IsJson("payload")));
        });
    }
}

/// <summary>A page view of the admin web pages (PHP <c>admin_access_log</c>). <c>UserId</c> is identity's user id, <c>Token</c> the member token.</summary>
internal sealed class AdminAccessLogEntry
{
    public long Id { get; set; }

    public DateTimeOffset AccessedAt { get; set; }

    public int? UserId { get; set; }

    public int? Token { get; set; }

    public int? Roleid { get; set; }

    public string Page { get; set; } = string.Empty;

    public string Method { get; set; } = string.Empty;

    public string? Ip { get; set; }

    public string? UserAgent { get; set; }

    public string? Referer { get; set; }

    public string? SessionId { get; set; }
}

/// <summary>PHP <c>genders</c>: classes and others store these ids.</summary>
internal sealed class Gender
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;
}

/// <summary>PHP <c>languages</c>: classes, quizzes and guides store these ids.</summary>
internal sealed class Language
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public int? SortOrder { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset? ModifiedAt { get; set; }

    public int? ModifiedBy { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public int? DeletedBy { get; set; }
}

/// <summary>One message waiting for delivery (PHP <c>outbound_messages</c>): push, WhatsApp or the search feed. <c>Payload</c> is JSON kept as text.</summary>
internal sealed class OutboundMessage
{
    public long Id { get; set; }

    public string Channel { get; set; } = string.Empty;

    public string Recipient { get; set; } = string.Empty;

    public string? Payload { get; set; }

    public string? DedupeKey { get; set; }

    public string Status { get; set; } = "queued";

    public int Attempts { get; set; }

    public DateTimeOffset? NextAttemptAt { get; set; }

    public int? CreatedBy { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? SentAt { get; set; }

    public string? Error { get; set; }
}
