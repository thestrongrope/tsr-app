using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api;

/// <summary>
/// platform's tables, schema "platform": the feedback table, the platform-owned outbox
/// (written by every domain through shared/api/Outbox.cs), geo and lookups, and the tables ported in the schema phase (PlatformTables, below).
/// </summary>
internal sealed class PlatformContext(DbContextOptions<PlatformContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "platform";

    private const string GeoCollation = "geo_ci_ai";

    // In public, not platform: a column definition names the collation unqualified, and only public is on the migration connection's search_path.
    private const string GeoCollationSchema = "public";

    public DbSet<Feedback> Feedback => Set<Feedback>();

    public DbSet<OutboxMessage> Outbox => Set<OutboxMessage>();

    public DbSet<GeoCountry> GeoCountries => Set<GeoCountry>();

    public DbSet<GeoPostalCode> GeoPostalCodes => Set<GeoPostalCode>();

    public DbSet<GeoCity> GeoCities => Set<GeoCity>();

    public DbSet<LookupEntry> LookupEntries => Set<LookupEntry>();

    public DbSet<AdminAccessLogEntry> AdminAccessLog => Set<AdminAccessLogEntry>();

    public DbSet<Gender> Genders => Set<Gender>();

    public DbSet<Language> Languages => Set<Language>();

    public DbSet<OutboundMessage> OutboundMessages => Set<OutboundMessage>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        ConfigureGeo(modelBuilder);
        PlatformTables.Configure(modelBuilder);

        // user_id and handled_by are plain integers: a domain never references another domain's tables. (The first migration
        // added foreign keys to identity.users by hand; DropIdentityForeignKeys removed them.)
        modelBuilder.Entity<Feedback>(feedback =>
        {
            feedback.Property(f => f.ClientId).HasMaxLength(36);
            feedback.Property(f => f.CreatedAt).HasDefaultValueSql("now()");
            feedback.HasIndex(f => new { f.UserId, f.ClientId }).IsUnique().HasDatabaseName("uq_feedback_user_client");
            feedback.HasIndex(f => new { f.HandledAt, f.CreatedAt }).HasDatabaseName("idx_feedback_handled_created");
        });

        modelBuilder.Entity<LookupEntry>(lookup =>
        {
            lookup.ToTable("lookups");
            lookup.Property(l => l.Type).HasMaxLength(50);
            lookup.Property(l => l.Code).HasMaxLength(100);
            lookup.Property(l => l.Label).HasMaxLength(255);
            lookup.Property(l => l.SortOrder).HasDefaultValue(0);
            lookup.Property(l => l.IsActive).HasDefaultValue(true);
            lookup.Property(l => l.CreatedAt).HasDefaultValueSql("now()");
            lookup.HasIndex(l => new { l.Type, l.Code }).IsUnique().HasDatabaseName("uniq_type_code");
            lookup.HasIndex(l => new { l.Type, l.IsActive, l.SortOrder }).HasDatabaseName("idx_type_active_sort");
        });

        modelBuilder.Entity<OutboxMessage>(outbox =>
        {
            outbox.ToTable("outbox");
            outbox.Property(o => o.EventType).HasMaxLength(100);
            outbox.Property(o => o.Payload).HasColumnType("jsonb");
            outbox.HasIndex(o => new { o.PublishedAt, o.CreatedAt }).HasDatabaseName("idx_outbox_unpublished");
        });
    }

    private static void ConfigureGeo(ModelBuilder modelBuilder)
    {
        // Written exception to "every text column is citext" (db/tests/SchemaGuardTests.cs allow-list): the geo name, code and city
        // columns the lookups search, sort and compare use ONE ICU collation that ignores case and accents, as MariaDB's
        // utf8mb4_unicode_520_ci does (docs/specs/initial-build/phase-3-collation-proof.md). Their length checks are written here
        // because TsrConvention adds them only to citext columns. The other geo text columns stay citext.
        modelBuilder.HasCollation(GeoCollationSchema, GeoCollation, "und-u-ks-level1", "icu", false);

        modelBuilder.Entity<GeoCountry>(country =>
        {
            country.ToTable("geo_countries");
            country.HasKey(c => c.Code);
            country.Property(c => c.Code).HasMaxLength(2);
            country.Property(c => c.Name).HasColumnType("text").UseCollation(GeoCollation).HasMaxLength(100);
            country.Property(c => c.PostalCodeRegex).HasMaxLength(255);
            country.ToTable(t => t.HasCheckConstraint("ck_geo_countries_name_length", "char_length(\"name\") <= 100"));
            country.HasIndex(c => c.Name).HasDatabaseName("idx_geo_countries_name");
        });

        modelBuilder.Entity<GeoPostalCode>(postal =>
        {
            postal.ToTable("geo_postal_codes");
            postal.HasKey(p => new { p.CountryCode, p.PostalCode });
            postal.Property(p => p.CountryCode).HasMaxLength(2);
            postal.Property(p => p.PostalCode).HasColumnType("text").UseCollation(GeoCollation).HasMaxLength(20);
            postal.Property(p => p.City).HasMaxLength(255);
            postal.Property(p => p.State).HasMaxLength(150);
            postal.ToTable(t => t.HasCheckConstraint("ck_geo_postal_codes_postal_code_length", "char_length(\"postal_code\") <= 20"));
        });

        modelBuilder.Entity<GeoCity>(city =>
        {
            city.ToTable("geo_cities");
            city.HasKey(c => c.GeonameId);
            city.Property(c => c.GeonameId).ValueGeneratedNever();
            city.Property(c => c.CountryCode).HasMaxLength(2);
            city.Property(c => c.Name).HasColumnType("text").UseCollation(GeoCollation).HasMaxLength(200);
            city.Property(c => c.State).HasMaxLength(150);
            city.Property(c => c.Population).HasDefaultValue(0);
            city.ToTable(t => t.HasCheckConstraint("ck_geo_cities_name_length", "char_length(\"name\") <= 200"));
            city.HasIndex(c => new { c.CountryCode, c.Name }).HasDatabaseName("idx_geo_cities_country_name");
        });
    }
}

/// <summary>One country of the geo lists (read only at run time). Loaded from GeoNames, public data, never member data.</summary>
internal sealed class GeoCountry
{
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public bool HasPostalCodes { get; set; }

    public string? PostalCodeRegex { get; set; }
}

/// <summary>A postal code of a country, with the city it suggests and its state. Primary key (country code, postal code).</summary>
internal sealed class GeoPostalCode
{
    public string CountryCode { get; set; } = string.Empty;

    public string PostalCode { get; set; } = string.Empty;

    public string? City { get; set; }

    public string? State { get; set; }
}

/// <summary>A city of a country, with its state and population (the search lists the biggest first).</summary>
internal sealed class GeoCity
{
    public int GeonameId { get; set; }

    public string CountryCode { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string? State { get; set; }

    public int Population { get; set; }
}

/// <summary>One enumerated option of PHP's <c>lookups</c> (the class request form's dropdown lists). <c>Code</c> is stable, <c>Label</c> is what is shown and what registrations store.</summary>
internal sealed class LookupEntry
{
    public int Id { get; set; }

    public string Type { get; set; } = string.Empty;

    public string Code { get; set; } = string.Empty;

    public string Label { get; set; } = string.Empty;

    public int SortOrder { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTimeOffset? CreatedAt { get; set; }
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

    /// <summary>When a worker last claimed the row (status <c>sending</c>); a claim older than ten minutes is taken over by the next worker (PlatformCommands.ClaimMessagesAsync).</summary>
    public DateTimeOffset? ClaimedAt { get; set; }
}
