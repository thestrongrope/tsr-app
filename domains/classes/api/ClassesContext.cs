using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api;

/// <summary>
/// classes' tables, schema "classes": classes, levels, tags, schedules, sessions, attendance, enrolment (PHP <c>class_students</c>),
/// teachers, the syllabus and guides. Names, keys and indexes follow PHP's, so the data move is a copy. Every key that names a member
/// (<c>token</c>, <c>teacher</c>, <c>created_by</c> ...), a gender, a language or a class in another domain is a plain integer; the only
/// foreign key (syllabus to levels) stays inside the schema. Dates PHP stores as <c>date</c> stay <c>date</c> (a session's day is a
/// wall-clock day, not an instant); every <c>datetime</c> is <c>timestamptz</c>, read as UTC. PHP's two triggers (a class's share link,
/// a spot quiz's code) are not ported: the slice that creates the row will do it.
/// </summary>
internal sealed class ClassesContext(DbContextOptions<ClassesContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "classes";

    // The ICU collation platform's migration creates (public.geo_ci_ai). The two columns an access rule matches use it, as the geo
    // lists do: case AND accent insensitive, as MariaDB's utf8mb4_unicode_520_ci was (docs/specs/initial-build/phase-3-collation-proof.md).
    // Not declared again here (HasCollation): platform's migration owns it and runs first.
    private const string GeoCollation = "geo_ci_ai";

    private const string Now = "now()";

    public DbSet<ClassRow> Classes => Set<ClassRow>();

    public DbSet<ClassLevel> ClassLevels => Set<ClassLevel>();

    public DbSet<Tag> Tags => Set<Tag>();

    public DbSet<ClassTag> ClassTags => Set<ClassTag>();

    public DbSet<ClassSchedule> ClassSchedules => Set<ClassSchedule>();

    public DbSet<Topic> Topics => Set<Topic>();

    public DbSet<ClassScheduleTopic> ClassScheduleTopics => Set<ClassScheduleTopic>();

    public DbSet<ClassSession> ClassSessions => Set<ClassSession>();

    public DbSet<ClassAttendance> ClassAttendance => Set<ClassAttendance>();

    public DbSet<ClassStudent> ClassStudents => Set<ClassStudent>();

    public DbSet<StudentTransfer> StudentTransfers => Set<StudentTransfer>();

    public DbSet<ClassAuditEntry> ClassAuditLog => Set<ClassAuditEntry>();

    public DbSet<Teacher> Teachers => Set<Teacher>();

    public DbSet<TeacherHistory> TeachersHistory => Set<TeacherHistory>();

    public DbSet<SyllabusEntry> Syllabus => Set<SyllabusEntry>();

    public DbSet<Guide> Guides => Set<Guide>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        ConfigureClasses(modelBuilder);
        ConfigureSchedules(modelBuilder);
        ConfigureSessions(modelBuilder);
        ConfigureEnrolment(modelBuilder);
        ConfigureTeachers(modelBuilder);
        ConfigureTeaching(modelBuilder);
    }

    private static void ConfigureClasses(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ClassRow>(row =>
        {
            row.ToTable("classes");
            row.Property(c => c.Code).HasMaxLength(50);
            row.Property(c => c.Link).HasMaxLength(10);
            row.Property(c => c.Name).HasMaxLength(100);
            row.Property(c => c.Format).HasMaxLength(100).HasDefaultValue("Offline");
            row.Property(c => c.Address).HasMaxLength(300);
            row.Property(c => c.City).HasColumnType("text").UseCollation(GeoCollation).HasMaxLength(300);
            row.Property(c => c.Country).HasColumnType("text").UseCollation(GeoCollation).HasMaxLength(300);
            row.Property(c => c.Lat).HasPrecision(10, 8);
            row.Property(c => c.Lng).HasPrecision(11, 8);
            row.Property(c => c.Location).HasMaxLength(300);
            row.Property(c => c.ExtraStudents).HasMaxLength(3000);
            row.Property(c => c.Status).HasMaxLength(1).HasDefaultValue("A");
            row.Property(c => c.Comments).HasMaxLength(300);
            row.Property(c => c.CreatedAt).HasDefaultValueSql(Now);
            row.ToTable(t =>
            {
                // The two collated columns are not citext, so the convention writes no length check for them.
                t.HasCheckConstraint("ck_classes_city_length", "char_length(\"city\") <= 300");
                t.HasCheckConstraint("ck_classes_country_length", "char_length(\"country\") <= 300");
            });
        });

        modelBuilder.Entity<ClassLevel>(level =>
        {
            level.Property(l => l.Code).HasMaxLength(10);
            level.Property(l => l.Name).HasMaxLength(100);
            level.Property(l => l.CreatedAt).HasDefaultValueSql(Now);
        });

        modelBuilder.Entity<Tag>(tag =>
        {
            tag.Property(t => t.Name).HasMaxLength(50);
            tag.Property(t => t.CreatedAt).HasDefaultValueSql(Now);
        });

        modelBuilder.Entity<ClassTag>(tag =>
        {
            tag.HasKey(t => new { t.ClassId, t.TagId });
            tag.Property(t => t.CreatedAt).HasDefaultValueSql(Now);
        });
    }

    private static void ConfigureSchedules(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ClassSchedule>(schedule =>
        {
            schedule.Property(s => s.Timezone).HasMaxLength(100);
            schedule.Property(s => s.CreatedAt).HasDefaultValueSql(Now);
        });

        modelBuilder.Entity<Topic>(topic =>
        {
            topic.Property(t => t.Name).HasMaxLength(100);
            topic.Property(t => t.IsVocational).HasDefaultValue(0);
            topic.Property(t => t.CreatedAt).HasDefaultValueSql(Now);
        });

        modelBuilder.Entity<ClassScheduleTopic>(topic =>
        {
            topic.ToTable("class_schedule_topics");
            topic.Property(t => t.CreatedAt).HasDefaultValueSql(Now);
        });
    }

    private static void ConfigureSessions(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ClassSession>(session =>
        {
            session.Property(s => s.Conducted).HasDefaultValue((short)1);
            session.Property(s => s.NonConductionReason).HasMaxLength(100);
            session.Property(s => s.ArabicConducted).HasMaxLength(1).HasDefaultValue("N");
            session.Property(s => s.ArabicTopic).HasMaxLength(1000);
            session.Property(s => s.AqaedConducted).HasMaxLength(1).HasDefaultValue("Y");
            session.Property(s => s.AqaedTopic).HasMaxLength(1000);
            session.Property(s => s.AhkamConducted).HasMaxLength(1).HasDefaultValue("N");
            session.Property(s => s.AhkamTopic).HasMaxLength(1000);
            session.Property(s => s.AkhlaqConducted).HasMaxLength(1).HasDefaultValue("N");
            session.Property(s => s.AkhlaqTopic).HasMaxLength(1000);
            session.Property(s => s.OtherConducted).HasMaxLength(1).HasDefaultValue("N");
            session.Property(s => s.OtherTopic).HasMaxLength(1000);
            session.Property(s => s.Assignments).HasMaxLength(1000);
            session.Property(s => s.AssignmentCount).HasDefaultValue(0);
            session.Property(s => s.TeamRequest).HasMaxLength(1000);
            session.Property(s => s.CreatedAt).HasDefaultValueSql(Now);
            session.HasIndex(s => new { s.ClassId, s.ConductedOn }).HasDatabaseName("idx_cs_class_conducted");
            session.HasIndex(s => s.ConductedOn).HasDatabaseName("idx_cs_conducted_on");
        });

        modelBuilder.Entity<ClassAttendance>(attendance =>
        {
            attendance.ToTable("class_attendance");
            attendance.Property(a => a.Name).HasMaxLength(100);
            attendance.Property(a => a.ExtraStudent).HasDefaultValue((short)0);
            attendance.Property(a => a.Present).HasDefaultValue((short)0);
            attendance.Property(a => a.Recitation).HasDefaultValue(0);
            attendance.Property(a => a.PagesRead).HasDefaultValue(0);
            attendance.Property(a => a.AssignmentsDone).HasDefaultValue(0f);
            attendance.Property(a => a.Followup).HasMaxLength(1000);
            attendance.Property(a => a.CreatedAt).HasDefaultValueSql(Now);
            attendance.HasIndex(a => new { a.SessionId, a.Token }).HasDatabaseName("idx_ca_session_token");
        });
    }

    private static void ConfigureEnrolment(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ClassStudent>(student =>
        {
            student.Property(s => s.DataAdmin).HasDefaultValue((short)0);
            student.Property(s => s.McqAdmin).HasDefaultValue((short)0);
            student.Property(s => s.AssignmentAdmin).HasDefaultValue((short)0);
            student.Property(s => s.CreatedAt).HasDefaultValueSql(Now);
            student.Property(s => s.RemovedReason).HasMaxLength(500);
            student.Property(s => s.Status).HasMaxLength(1).HasDefaultValue("A");
            student.Property(s => s.Notes).HasMaxLength(65535);
            student.HasIndex(s => s.ClassId).HasDatabaseName("idx_cls_class");
            student.HasIndex(s => s.TokenNo).HasDatabaseName("idx_cls_token_no");
        });

        modelBuilder.Entity<StudentTransfer>(transfer =>
        {
            transfer.Property(t => t.Type).HasMaxLength(9).HasDefaultValue("transfer");
            transfer.Property(t => t.Reason).HasMaxLength(500);
            transfer.Property(t => t.TransferredAt).HasDefaultValueSql(Now);
            transfer.HasIndex(t => t.TokenNo).HasDatabaseName("idx_token");
            transfer.HasIndex(t => t.FromClassId).HasDatabaseName("idx_from_class");
            transfer.HasIndex(t => t.ToClassId).HasDatabaseName("idx_to_class");
            transfer.HasIndex(t => t.TransferredBy).HasDatabaseName("idx_transferred_by");
            transfer.ToTable(t => t.HasCheckConstraint("ck_student_transfers_type", CheckSql.In("type", "transfer", "promotion", "demotion")));
        });

        modelBuilder.Entity<ClassAuditEntry>(entry =>
        {
            entry.ToTable("class_audit_log");
            entry.Property(e => e.Action).HasMaxLength(11);
            entry.Property(e => e.PerformedAt).HasDefaultValueSql(Now);
            entry.HasIndex(e => e.ClassId).HasDatabaseName("idx_class");
            entry.HasIndex(e => e.Action).HasDatabaseName("idx_action");
            entry.HasIndex(e => e.PerformedAt).HasDatabaseName("idx_at");
            entry.ToTable(t =>
            {
                t.HasCheckConstraint("ck_class_audit_log_action", CheckSql.In("action", "created", "updated", "deactivated", "reactivated"));
                t.HasCheckConstraint("ck_class_audit_log_details_json", CheckSql.IsJson("details"));
            });
        });
    }

    private static void ConfigureTeachers(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Teacher>(teacher =>
        {
            teacher.HasKey(t => t.Token);
            teacher.Property(t => t.Token).ValueGeneratedNever();
            teacher.Property(t => t.Comments).HasMaxLength(1000);
            teacher.Property(t => t.Status).HasMaxLength(1);
            teacher.Property(t => t.CreatedAt).HasDefaultValueSql(Now);
        });

        modelBuilder.Entity<TeacherHistory>(history =>
        {
            history.ToTable("teachers_history");
            history.Property(h => h.Comments).HasMaxLength(1000);
            history.Property(h => h.Status).HasMaxLength(1);
            history.Property(h => h.CreatedAt).HasDefaultValueSql(Now);
        });
    }

    private static void ConfigureTeaching(ModelBuilder modelBuilder)
    {
        // The one foreign key, inside this schema, as PHP has it (no ON DELETE action: a level in use cannot be removed).
        modelBuilder.Entity<SyllabusEntry>(entry =>
        {
            entry.ToTable("syllabus");
            entry.Property(e => e.SubjectName).HasMaxLength(150);
            entry.Property(e => e.Description).HasMaxLength(500);
            entry.Property(e => e.LinkType).HasMaxLength(8).HasDefaultValue("pdf");
            entry.Property(e => e.Url).HasMaxLength(1000);
            entry.Property(e => e.SortOrder).HasDefaultValue(0);
            entry.Property(e => e.IsActive).HasDefaultValue((short)1);
            entry.Property(e => e.CreatedAt).HasDefaultValueSql(Now);
            entry.HasIndex(e => new { e.LevelId, e.IsActive }).HasDatabaseName("idx_level_active");
            entry.HasIndex(e => e.DeletedAt).HasDatabaseName("idx_deleted_at");
            entry.HasOne<ClassLevel>().WithMany().HasForeignKey(e => e.LevelId).OnDelete(DeleteBehavior.Restrict).HasConstraintName("fk_syllabus_level");
            entry.ToTable(t => t.HasCheckConstraint("ck_syllabus_link_type", CheckSql.In("link_type", "pdf", "external")));
        });

        modelBuilder.Entity<Guide>(guide =>
        {
            guide.Property(g => g.Text).HasColumnName("guide").HasMaxLength(65535);
            guide.Property(g => g.CreatedAt).HasDefaultValueSql(Now);
            guide.Property(g => g.CreatedBy).HasDefaultValue(0);
            guide.HasIndex(g => new { g.LevelId, g.LanguageId }).IsUnique().HasDatabaseName("IDX_levelid_languageid");
        });
    }
}
