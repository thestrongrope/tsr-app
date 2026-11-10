using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api;

/// <summary>
/// platform's tables, schema "platform": the feedback table and the platform-owned outbox
/// (written by every domain through shared/api/Outbox.cs).
/// </summary>
internal sealed class PlatformContext(DbContextOptions<PlatformContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "platform";

    public DbSet<Feedback> Feedback => Set<Feedback>();

    public DbSet<OutboxMessage> Outbox => Set<OutboxMessage>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        // user_id and handled_by also reference identity.users(id) ON DELETE SET NULL; added by hand
        // in the first migration (a foreign key may not cross two contexts in the model).
        modelBuilder.Entity<Feedback>(feedback =>
        {
            feedback.Property(f => f.ClientId).HasMaxLength(36);
            feedback.Property(f => f.CreatedAt).HasDefaultValueSql("now()");
            feedback.HasIndex(f => new { f.UserId, f.ClientId }).IsUnique().HasDatabaseName("uq_feedback_user_client");
            feedback.HasIndex(f => new { f.HandledAt, f.CreatedAt }).HasDatabaseName("idx_feedback_handled_created");
        });

        modelBuilder.Entity<OutboxMessage>(outbox =>
        {
            outbox.ToTable("outbox");
            outbox.Property(o => o.EventType).HasMaxLength(100);
            outbox.Property(o => o.Payload).HasColumnType("jsonb");
            outbox.HasIndex(o => new { o.PublishedAt, o.CreatedAt }).HasDatabaseName("idx_outbox_unpublished");
        });
    }
}

internal sealed class Feedback
{
    public int Id { get; set; }

    public int? UserId { get; set; }

    public string ClientId { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? HandledAt { get; set; }

    public int? HandledBy { get; set; }
}

/// <summary>Domain event waiting to be relayed. Payloads carry ids, never message text. Written with SQL by shared Outbox.</summary>
internal sealed class OutboxMessage
{
    public Guid Id { get; set; }

    public string EventType { get; set; } = string.Empty;

    public string Payload { get; set; } = "{}";

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? PublishedAt { get; set; }
}
