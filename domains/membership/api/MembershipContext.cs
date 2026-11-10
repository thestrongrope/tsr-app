using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api;

/// <summary>
/// membership's tables, schema "membership": the profile columns PHP kept on <c>users</c>, the class request form's
/// tables and the guardian links. Column names follow PHP's, so the data move is a copy. Keys that name a member are plain
/// integers (the identity user id, or PHP's token): no foreign key leaves this schema, and PHP's own keys by token stay as they were.
/// PHP's enums and its one SET become text with a CHECK; the columns are citext, so a CHECK matches ignoring case, as MariaDB's did.
/// </summary>
internal sealed class MembershipContext(DbContextOptions<MembershipContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "membership";

    /// <summary>The length of an invite code (PHP: <c>bin2hex(random_bytes(16))</c>, the column is 32 characters).</summary>
    public const int CodeLength = 32;

    public DbSet<MemberProfile> MemberProfiles => Set<MemberProfile>();

    public DbSet<ClassRegistration> ClassRegistrations => Set<ClassRegistration>();

    public DbSet<RegistrationLanguage> RegistrationLanguages => Set<RegistrationLanguage>();

    public DbSet<InterestOption> InterestOptions => Set<InterestOption>();

    public DbSet<StudentInterest> StudentInterests => Set<StudentInterest>();

    public DbSet<UserGuardian> UserGuardians => Set<UserGuardian>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        ConfigureProfiles(modelBuilder);
        ConfigureRegistrations(modelBuilder);
        ConfigureInterests(modelBuilder);
        ConfigureGuardians(modelBuilder);
    }

    private static void ConfigureProfiles(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<MemberProfile>(profile =>
        {
            profile.HasKey(p => p.UserId);
            profile.Property(p => p.UserId).ValueGeneratedNever();
            profile.Property(p => p.Name).HasMaxLength(200);
            profile.Property(p => p.FirstName).HasMaxLength(200);
            profile.Property(p => p.LastName).HasMaxLength(200);
            profile.Property(p => p.Picture).HasMaxLength(2000);
            profile.Property(p => p.Gender).HasMaxLength(200);
            profile.Property(p => p.AgeRange).HasMaxLength(200);
            profile.Property(p => p.Mobile).HasMaxLength(100).HasDefaultValue(string.Empty);
            profile.Property(p => p.Country).HasMaxLength(200);
            profile.Property(p => p.State).HasMaxLength(200);
            profile.Property(p => p.City).HasMaxLength(200);
            profile.Property(p => p.Zip).HasMaxLength(100);
            profile.Property(p => p.Language).HasDefaultValue(0);
            profile.Property(p => p.SendUpdates).HasColumnName("sendupdates").HasMaxLength(1).HasDefaultValue("N");
            profile.Property(p => p.Unsubscribe).HasMaxLength(1).HasDefaultValue("N");
        });
    }

    private static void ConfigureRegistrations(ModelBuilder modelBuilder)
    {
        // No unique key on the token: PHP's table holds duplicates per token, and an update changes every row of the token.
        modelBuilder.Entity<ClassRegistration>(registration =>
        {
            registration.Property(r => r.ForClassId).HasColumnName("for_classid");
            registration.Property(r => r.ResidenceLocation).HasMaxLength(300);
            registration.Property(r => r.WorkLocation).HasMaxLength(300);
            registration.Property(r => r.PreferredLocation).HasMaxLength(1000);
            registration.Property(r => r.ClassLevel).HasMaxLength(20);
            registration.Property(r => r.ClassNumber).HasMaxLength(100);
            registration.Property(r => r.Profession).HasMaxLength(500);
            registration.Property(r => r.Interests).HasMaxLength(400);
            registration.Property(r => r.OtherInterests).HasMaxLength(500);
            registration.Property(r => r.Education).HasMaxLength(100);
            registration.Property(r => r.FieldOfStudy).HasColumnType("jsonb");
            registration.Property(r => r.FieldOfStudyOther).HasMaxLength(200);
            registration.Property(r => r.ProfessionalCourses).HasColumnType("jsonb");
            registration.Property(r => r.ProfessionalCoursesOther).HasMaxLength(200);
            registration.Property(r => r.OccupationType).HasMaxLength(100);
            registration.Property(r => r.FieldOfWork).HasMaxLength(100);
            registration.Property(r => r.YearsExperience).HasMaxLength(50);
            registration.Property(r => r.RoleLevel).HasMaxLength(100);
            registration.Property(r => r.LinkedinUrl).HasMaxLength(500);
            registration.Property(r => r.Status).HasMaxLength(20).HasDefaultValue("Pending");
            registration.Property(r => r.StatusReason).HasMaxLength(500);
            registration.Property(r => r.CreatedAt).HasDefaultValueSql("now()");
            registration.HasIndex(r => r.Token).HasDatabaseName("idx_class_registrations_token");
            registration.ToTable(t =>
            {
                t.HasCheckConstraint("ck_class_registrations_class_level", In("class_level", "IKP", "IJP", "IBP", "Primary", "Secondary", "Advance"));
                t.HasCheckConstraint("ck_class_registrations_status", In("status", "Pending", "Accepted", "Rejected"));
                t.HasCheckConstraint("ck_class_registrations_interests", InterestsSet);
            });
        });

        modelBuilder.Entity<RegistrationLanguage>(language =>
        {
            language.ToTable("class_registrations_languages");
            language.Property(l => l.Language).HasMaxLength(20);
            language.Property(l => l.Skill).HasMaxLength(20);
            language.Property(l => l.Proficiency).HasMaxLength(20);
            language.HasIndex(l => l.Token).HasDatabaseName("idx_class_registrations_languages_token");
            language.ToTable(t =>
            {
                t.HasCheckConstraint("ck_class_registrations_languages_language", In("language", "English", "Hindi", "Urdu", "Gujarati", "Arabic", "Persian"));
                t.HasCheckConstraint("ck_class_registrations_languages_skill", In("skill", "Read", "Write", "Speak", "Understand"));
                t.HasCheckConstraint("ck_class_registrations_languages_proficiency", In("proficiency", "Don't Know", "Beginner", "Learning", "Fluent"));
            });
        });
    }

    private static void ConfigureInterests(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<InterestOption>(option =>
        {
            option.Property(o => o.Name).HasMaxLength(100);
            option.Property(o => o.SortOrder).HasDefaultValue(0);
            option.Property(o => o.IsActive).HasDefaultValue(true);
            option.Property(o => o.CreatedAt).HasDefaultValueSql("now()");
            option.HasIndex(o => o.Name).IsUnique().HasDatabaseName("uq_interest_options_name");
        });

        // The one foreign key, inside this schema, as PHP has it: removing an option removes the choices that name it.
        modelBuilder.Entity<StudentInterest>(choice =>
        {
            choice.Property(s => s.CreatedAt).HasDefaultValueSql("now()");
            choice.HasIndex(s => new { s.Token, s.InterestId }).IsUnique().HasDatabaseName("uq_student_interests_token_interest");
            choice.HasIndex(s => s.Token).HasDatabaseName("idx_student_interests_token");
            choice.HasOne<InterestOption>().WithMany().HasForeignKey(s => s.InterestId).OnDelete(DeleteBehavior.Cascade);
        });
    }

    private static void ConfigureGuardians(ModelBuilder modelBuilder)
    {
        // As PHP: keyed by token, no foreign keys. "One active link per pair" and "five invites" have no key, only the
        // lock the handlers take (phase-3-membership-design.md decision 5), because old data may hold a duplicate pair.
        modelBuilder.Entity<UserGuardian>(guardian =>
        {
            guardian.Property(g => g.Relationship).HasMaxLength(20);
            guardian.Property(g => g.Status).HasMaxLength(20).HasDefaultValue("invited");
            guardian.Property(g => g.Source).HasMaxLength(20);
            guardian.Property(g => g.Code).HasMaxLength(32);
            guardian.Property(g => g.CreatedAt).HasDefaultValueSql("now()");
            guardian.HasIndex(g => g.Code).IsUnique().HasDatabaseName("idx_code");
            guardian.HasIndex(g => g.ParentToken).HasDatabaseName("idx_parent_token");
            guardian.HasIndex(g => g.ChildToken).HasDatabaseName("idx_child_token");
            guardian.ToTable(t =>
            {
                t.HasCheckConstraint("ck_user_guardians_relationship", In("relationship", "father", "mother", "guardian"));
                t.HasCheckConstraint("ck_user_guardians_status", In("status", "invited", "active", "revoked"));
                t.HasCheckConstraint("ck_user_guardians_source", In("source", "link", "token_entry"));
            });
        });
    }

    // A NULL passes a CHECK, as a nullable MariaDB enum accepts NULL.
    private static string In(string column, params string[] values) =>
        column + " in (" + string.Join(", ", values.Select(v => "'" + v.Replace("'", "''", StringComparison.Ordinal) + "'")) + ")";

    // MariaDB's SET holds a comma separated list of the listed values, in any case. The legacy column is read by classes' enrolment
    // code and wiped by the registration form (phase-3-membership-recon.md, 2.16).
    private static readonly string[] InterestValues =
    [
        "Teaching", "Creating Audio-Video Content", "Organizing Programs", "Research", "Writing (articles / scripts)", "Debates",
        "Social Media Marketing", "Software Development", "Devops / Infra", "Coordination / Administration", "HR", "Other",
    ];

    private static readonly string InterestsSet =
        "string_to_array(lower(interests::text), ',') <@ array["
        + string.Join(", ", InterestValues.Select(v => "'" + v.ToLowerInvariant() + "'"))
        + "]";
}

/// <summary>The profile columns of PHP's <c>users</c>, one row per member, keyed by identity's user id. Created on first read or write.</summary>
internal sealed class MemberProfile
{
    public int UserId { get; set; }

    public string? Name { get; set; }

    public string? FirstName { get; set; }

    public string? LastName { get; set; }

    public string? Picture { get; set; }

    /// <summary>PHP's raw text: '1', '2', 'Male', 'Female', empty or null. Kept as it is so every PHP reading of it stays identical.</summary>
    public string? Gender { get; set; }

    public string? AgeRange { get; set; }

    public string Mobile { get; set; } = string.Empty;

    public string? Country { get; set; }

    public string? State { get; set; }

    public string? City { get; set; }

    public string? Zip { get; set; }

    public int? Language { get; set; }

    public string SendUpdates { get; set; } = "N";

    public string Unsubscribe { get; set; } = "N";
}

/// <summary>One row of PHP's <c>class_registrations</c>. A token may have several (duplicates exist).</summary>
internal sealed class ClassRegistration
{
    public int Id { get; set; }

    public int? Token { get; set; }

    public int? ForClassId { get; set; }

    public string? ResidenceLocation { get; set; }

    public string? WorkLocation { get; set; }

    public string? PreferredLocation { get; set; }

    public string? ClassLevel { get; set; }

    public string? ClassNumber { get; set; }

    public int? BirthYear { get; set; }

    public string? Profession { get; set; }

    public int? IslamicStudyYears { get; set; }

    public string? Interests { get; set; }

    public string? OtherInterests { get; set; }

    public string? Education { get; set; }

    public string? FieldOfStudy { get; set; }

    public string? FieldOfStudyOther { get; set; }

    public string? ProfessionalCourses { get; set; }

    public string? ProfessionalCoursesOther { get; set; }

    public string? OccupationType { get; set; }

    public string? FieldOfWork { get; set; }

    public string? YearsExperience { get; set; }

    public string? RoleLevel { get; set; }

    public string? LinkedinUrl { get; set; }

    public string Status { get; set; } = "Pending";

    public DateTimeOffset? StatusDate { get; set; }

    public string? StatusReason { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? ModifiedAt { get; set; }

    public int? ModifiedBy { get; set; }
}

/// <summary>One language skill of a registrant (PHP <c>class_registrations_languages</c>).</summary>
internal sealed class RegistrationLanguage
{
    public int Id { get; set; }

    public int? Token { get; set; }

    public string? Language { get; set; }

    public string? Skill { get; set; }

    public string? Proficiency { get; set; }
}

/// <summary>A choice on the registration form's interest list.</summary>
internal sealed class InterestOption
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public int SortOrder { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTimeOffset? CreatedAt { get; set; }
}

/// <summary>An interest a member picked (PHP <c>student_interests</c>).</summary>
internal sealed class StudentInterest
{
    public int Id { get; set; }

    public int Token { get; set; }

    public int InterestId { get; set; }

    public DateTimeOffset? CreatedAt { get; set; }
}

/// <summary>A link between a parent and a child, by token (PHP <c>user_guardians</c>). An invite has no parent until it is accepted.</summary>
internal sealed class UserGuardian
{
    public int Id { get; set; }

    public int? ParentToken { get; set; }

    public int ChildToken { get; set; }

    public string? Relationship { get; set; }

    public string Status { get; set; } = "invited";

    public string Source { get; set; } = string.Empty;

    public string? Code { get; set; }

    public DateTimeOffset? ExpiresAt { get; set; }

    public int CreatedBy { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? ActivatedAt { get; set; }

    public int? RevokedBy { get; set; }

    public DateTimeOffset? RevokedAt { get; set; }
}
