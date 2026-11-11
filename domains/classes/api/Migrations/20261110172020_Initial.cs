using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "classes");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "class_attendance",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    session_id = table.Column<int>(type: "integer", nullable: false),
                    token = table.Column<int>(type: "integer", nullable: false),
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    extra_student = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    present = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    recitation = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    pages_read = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    assignments_done = table.Column<float>(type: "real", nullable: false, defaultValue: 0f),
                    followup = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_attendance", x => x.id);
                    table.CheckConstraint("ck_class_attendance_followup_length", "char_length(\"followup\") <= 1000");
                    table.CheckConstraint("ck_class_attendance_name_length", "char_length(\"name\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "class_audit_log",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    class_id = table.Column<int>(type: "integer", nullable: false),
                    action = table.Column<string>(type: "citext", maxLength: 11, nullable: false),
                    details = table.Column<string>(type: "citext", nullable: true),
                    performed_by = table.Column<int>(type: "integer", nullable: false),
                    performed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_audit_log", x => x.id);
                    table.CheckConstraint("ck_class_audit_log_action", "action in ('created', 'updated', 'deactivated', 'reactivated')");
                    table.CheckConstraint("ck_class_audit_log_action_length", "char_length(\"action\") <= 11");
                    table.CheckConstraint("ck_class_audit_log_details_json", "details::text is json");
                });

            migrationBuilder.CreateTable(
                name: "class_levels",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    code = table.Column<string>(type: "citext", maxLength: 10, nullable: false),
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_levels", x => x.id);
                    table.CheckConstraint("ck_class_levels_code_length", "char_length(\"code\") <= 10");
                    table.CheckConstraint("ck_class_levels_name_length", "char_length(\"name\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "class_schedule_topics",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    class_schedule_id = table.Column<int>(type: "integer", nullable: false),
                    topic_id = table.Column<int>(type: "integer", nullable: true),
                    sort_order = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_schedule_topics", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "class_schedules",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    class_id = table.Column<int>(type: "integer", nullable: false),
                    day = table.Column<int>(type: "integer", nullable: true),
                    hour = table.Column<int>(type: "integer", nullable: true),
                    minute = table.Column<int>(type: "integer", nullable: true),
                    timezone = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_schedules", x => x.id);
                    table.CheckConstraint("ck_class_schedules_timezone_length", "char_length(\"timezone\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "class_sessions",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    class_id = table.Column<int>(type: "integer", nullable: true),
                    teacher = table.Column<int>(type: "integer", nullable: false),
                    conducted_on = table.Column<DateOnly>(type: "date", nullable: false),
                    conducted = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)1),
                    non_conduction_reason = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    conducted_by = table.Column<int>(type: "integer", nullable: true),
                    duration = table.Column<int>(type: "integer", nullable: true),
                    attendance = table.Column<int>(type: "integer", nullable: true),
                    quran_recitation_surah = table.Column<int>(type: "integer", nullable: true),
                    quran_recitation_verse = table.Column<int>(type: "integer", nullable: true),
                    arabic_conducted = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "N"),
                    arabic_topic = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    aqaed_conducted = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "Y"),
                    aqaed_topic = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    ahkam_conducted = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "N"),
                    ahkam_topic = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    akhlaq_conducted = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "N"),
                    akhlaq_topic = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    other_conducted = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "N"),
                    other_topic = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    assignments = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    assignment_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    team_request = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_sessions", x => x.id);
                    table.CheckConstraint("ck_class_sessions_ahkam_conducted_length", "char_length(\"ahkam_conducted\") <= 1");
                    table.CheckConstraint("ck_class_sessions_ahkam_topic_length", "char_length(\"ahkam_topic\") <= 1000");
                    table.CheckConstraint("ck_class_sessions_akhlaq_conducted_length", "char_length(\"akhlaq_conducted\") <= 1");
                    table.CheckConstraint("ck_class_sessions_akhlaq_topic_length", "char_length(\"akhlaq_topic\") <= 1000");
                    table.CheckConstraint("ck_class_sessions_aqaed_conducted_length", "char_length(\"aqaed_conducted\") <= 1");
                    table.CheckConstraint("ck_class_sessions_aqaed_topic_length", "char_length(\"aqaed_topic\") <= 1000");
                    table.CheckConstraint("ck_class_sessions_arabic_conducted_length", "char_length(\"arabic_conducted\") <= 1");
                    table.CheckConstraint("ck_class_sessions_arabic_topic_length", "char_length(\"arabic_topic\") <= 1000");
                    table.CheckConstraint("ck_class_sessions_assignments_length", "char_length(\"assignments\") <= 1000");
                    table.CheckConstraint("ck_class_sessions_non_conduction_reason_length", "char_length(\"non_conduction_reason\") <= 100");
                    table.CheckConstraint("ck_class_sessions_other_conducted_length", "char_length(\"other_conducted\") <= 1");
                    table.CheckConstraint("ck_class_sessions_other_topic_length", "char_length(\"other_topic\") <= 1000");
                    table.CheckConstraint("ck_class_sessions_team_request_length", "char_length(\"team_request\") <= 1000");
                });

            migrationBuilder.CreateTable(
                name: "class_students",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    class_id = table.Column<int>(type: "integer", nullable: true),
                    token_no = table.Column<int>(type: "integer", nullable: true),
                    joined_on = table.Column<DateOnly>(type: "date", nullable: true),
                    data_admin = table.Column<short>(type: "smallint", nullable: true, defaultValue: (short)0),
                    mcq_admin = table.Column<short>(type: "smallint", nullable: true, defaultValue: (short)0),
                    assignment_admin = table.Column<short>(type: "smallint", nullable: true, defaultValue: (short)0),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    removed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    removed_reason = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    removed_by = table.Column<int>(type: "integer", nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "A"),
                    notes = table.Column<string>(type: "citext", maxLength: 65535, nullable: true),
                    added_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_students", x => x.id);
                    table.CheckConstraint("ck_class_students_notes_length", "char_length(\"notes\") <= 65535");
                    table.CheckConstraint("ck_class_students_removed_reason_length", "char_length(\"removed_reason\") <= 500");
                    table.CheckConstraint("ck_class_students_status_length", "char_length(\"status\") <= 1");
                });

            migrationBuilder.CreateTable(
                name: "class_tags",
                schema: "classes",
                columns: table => new
                {
                    class_id = table.Column<int>(type: "integer", nullable: false),
                    tag_id = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_tags", x => new { x.class_id, x.tag_id });
                });

            migrationBuilder.CreateTable(
                name: "classes",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    code = table.Column<string>(type: "citext", maxLength: 50, nullable: false),
                    language_id = table.Column<int>(type: "integer", nullable: true),
                    link = table.Column<string>(type: "citext", maxLength: 10, nullable: true),
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    class_level_id = table.Column<int>(type: "integer", nullable: true),
                    started_on = table.Column<DateOnly>(type: "date", nullable: true),
                    teacher = table.Column<int>(type: "integer", nullable: true),
                    gender = table.Column<int>(type: "integer", nullable: true),
                    format = table.Column<string>(type: "citext", maxLength: 100, nullable: false, defaultValue: "Offline"),
                    address = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    city = table.Column<string>(type: "text", maxLength: 300, nullable: true, collation: "geo_ci_ai"),
                    country = table.Column<string>(type: "text", maxLength: 300, nullable: true, collation: "geo_ci_ai"),
                    lat = table.Column<decimal>(type: "numeric(10,8)", precision: 10, scale: 8, nullable: true),
                    lng = table.Column<decimal>(type: "numeric(11,8)", precision: 11, scale: 8, nullable: true),
                    location = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    extra_students = table.Column<string>(type: "citext", maxLength: 3000, nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 1, nullable: false, defaultValue: "A"),
                    shutdown_on = table.Column<DateOnly>(type: "date", nullable: true),
                    completed_on = table.Column<DateOnly>(type: "date", nullable: true),
                    comments = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_classes", x => x.id);
                    table.CheckConstraint("ck_classes_address_length", "char_length(\"address\") <= 300");
                    table.CheckConstraint("ck_classes_city_length", "char_length(\"city\") <= 300");
                    table.CheckConstraint("ck_classes_code_length", "char_length(\"code\") <= 50");
                    table.CheckConstraint("ck_classes_comments_length", "char_length(\"comments\") <= 300");
                    table.CheckConstraint("ck_classes_country_length", "char_length(\"country\") <= 300");
                    table.CheckConstraint("ck_classes_extra_students_length", "char_length(\"extra_students\") <= 3000");
                    table.CheckConstraint("ck_classes_format_length", "char_length(\"format\") <= 100");
                    table.CheckConstraint("ck_classes_link_length", "char_length(\"link\") <= 10");
                    table.CheckConstraint("ck_classes_location_length", "char_length(\"location\") <= 300");
                    table.CheckConstraint("ck_classes_name_length", "char_length(\"name\") <= 100");
                    table.CheckConstraint("ck_classes_status_length", "char_length(\"status\") <= 1");
                });

            migrationBuilder.CreateTable(
                name: "guides",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    level_id = table.Column<int>(type: "integer", nullable: false),
                    language_id = table.Column<int>(type: "integer", nullable: false),
                    guide = table.Column<string>(type: "citext", maxLength: 65535, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_guides", x => x.id);
                    table.CheckConstraint("ck_guides_guide_length", "char_length(\"guide\") <= 65535");
                });

            migrationBuilder.CreateTable(
                name: "student_transfers",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    token_no = table.Column<int>(type: "integer", nullable: false),
                    from_class_id = table.Column<int>(type: "integer", nullable: false),
                    to_class_id = table.Column<int>(type: "integer", nullable: false),
                    type = table.Column<string>(type: "citext", maxLength: 9, nullable: false, defaultValue: "transfer"),
                    reason = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    transferred_by = table.Column<int>(type: "integer", nullable: false),
                    transferred_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_student_transfers", x => x.id);
                    table.CheckConstraint("ck_student_transfers_reason_length", "char_length(\"reason\") <= 500");
                    table.CheckConstraint("ck_student_transfers_type", "type in ('transfer', 'promotion', 'demotion')");
                    table.CheckConstraint("ck_student_transfers_type_length", "char_length(\"type\") <= 9");
                });

            migrationBuilder.CreateTable(
                name: "tags",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "citext", maxLength: 50, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_tags", x => x.id);
                    table.CheckConstraint("ck_tags_name_length", "char_length(\"name\") <= 50");
                });

            migrationBuilder.CreateTable(
                name: "teachers",
                schema: "classes",
                columns: table => new
                {
                    token = table.Column<int>(type: "integer", nullable: false),
                    salman = table.Column<int>(type: "integer", nullable: false),
                    abuzar = table.Column<int>(type: "integer", nullable: false),
                    miqdad = table.Column<int>(type: "integer", nullable: false),
                    ammar = table.Column<int>(type: "integer", nullable: false),
                    bilal = table.Column<int>(type: "integer", nullable: false),
                    comments = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 1, nullable: false),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_teachers", x => x.token);
                    table.CheckConstraint("ck_teachers_comments_length", "char_length(\"comments\") <= 1000");
                    table.CheckConstraint("ck_teachers_status_length", "char_length(\"status\") <= 1");
                });

            migrationBuilder.CreateTable(
                name: "teachers_history",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    token = table.Column<int>(type: "integer", nullable: true),
                    salman = table.Column<int>(type: "integer", nullable: false),
                    abuzar = table.Column<int>(type: "integer", nullable: false),
                    miqdad = table.Column<int>(type: "integer", nullable: false),
                    ammar = table.Column<int>(type: "integer", nullable: false),
                    bilal = table.Column<int>(type: "integer", nullable: false),
                    comments = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 1, nullable: true),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_teachers_history", x => x.id);
                    table.CheckConstraint("ck_teachers_history_comments_length", "char_length(\"comments\") <= 1000");
                    table.CheckConstraint("ck_teachers_history_status_length", "char_length(\"status\") <= 1");
                });

            migrationBuilder.CreateTable(
                name: "topics",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    is_vocational = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    sort_order = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    modified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_topics", x => x.id);
                    table.CheckConstraint("ck_topics_name_length", "char_length(\"name\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "syllabus",
                schema: "classes",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    level_id = table.Column<int>(type: "integer", nullable: false),
                    subject_name = table.Column<string>(type: "citext", maxLength: 150, nullable: false),
                    description = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    link_type = table.Column<string>(type: "citext", maxLength: 8, nullable: false, defaultValue: "pdf"),
                    url = table.Column<string>(type: "citext", maxLength: 1000, nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: true, defaultValue: 0),
                    is_active = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)1),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    modified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_syllabus", x => x.id);
                    table.CheckConstraint("ck_syllabus_description_length", "char_length(\"description\") <= 500");
                    table.CheckConstraint("ck_syllabus_link_type", "link_type in ('pdf', 'external')");
                    table.CheckConstraint("ck_syllabus_link_type_length", "char_length(\"link_type\") <= 8");
                    table.CheckConstraint("ck_syllabus_subject_name_length", "char_length(\"subject_name\") <= 150");
                    table.CheckConstraint("ck_syllabus_url_length", "char_length(\"url\") <= 1000");
                    table.ForeignKey(
                        name: "fk_syllabus_level",
                        column: x => x.level_id,
                        principalSchema: "classes",
                        principalTable: "class_levels",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "idx_ca_session_token",
                schema: "classes",
                table: "class_attendance",
                columns: new[] { "session_id", "token" });

            migrationBuilder.CreateIndex(
                name: "idx_action",
                schema: "classes",
                table: "class_audit_log",
                column: "action");

            migrationBuilder.CreateIndex(
                name: "idx_at",
                schema: "classes",
                table: "class_audit_log",
                column: "performed_at");

            migrationBuilder.CreateIndex(
                name: "idx_class",
                schema: "classes",
                table: "class_audit_log",
                column: "class_id");

            migrationBuilder.CreateIndex(
                name: "idx_cs_class_conducted",
                schema: "classes",
                table: "class_sessions",
                columns: new[] { "class_id", "conducted_on" });

            migrationBuilder.CreateIndex(
                name: "idx_cs_conducted_on",
                schema: "classes",
                table: "class_sessions",
                column: "conducted_on");

            migrationBuilder.CreateIndex(
                name: "idx_cls_class",
                schema: "classes",
                table: "class_students",
                column: "class_id");

            migrationBuilder.CreateIndex(
                name: "idx_cls_token_no",
                schema: "classes",
                table: "class_students",
                column: "token_no");

            migrationBuilder.CreateIndex(
                name: "IDX_levelid_languageid",
                schema: "classes",
                table: "guides",
                columns: new[] { "level_id", "language_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_from_class",
                schema: "classes",
                table: "student_transfers",
                column: "from_class_id");

            migrationBuilder.CreateIndex(
                name: "idx_to_class",
                schema: "classes",
                table: "student_transfers",
                column: "to_class_id");

            migrationBuilder.CreateIndex(
                name: "idx_token",
                schema: "classes",
                table: "student_transfers",
                column: "token_no");

            migrationBuilder.CreateIndex(
                name: "idx_transferred_by",
                schema: "classes",
                table: "student_transfers",
                column: "transferred_by");

            migrationBuilder.CreateIndex(
                name: "idx_deleted_at",
                schema: "classes",
                table: "syllabus",
                column: "deleted_at");

            migrationBuilder.CreateIndex(
                name: "idx_level_active",
                schema: "classes",
                table: "syllabus",
                columns: new[] { "level_id", "is_active" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "class_attendance",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "class_audit_log",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "class_schedule_topics",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "class_schedules",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "class_sessions",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "class_students",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "class_tags",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "classes",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "guides",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "student_transfers",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "syllabus",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "tags",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "teachers",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "teachers_history",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "topics",
                schema: "classes");

            migrationBuilder.DropTable(
                name: "class_levels",
                schema: "classes");
        }
    }
}
