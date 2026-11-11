using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Notifications.Api.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "notifications");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "class_scheduled_notification_runs",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    scheduled_id = table.Column<int>(type: "integer", nullable: false),
                    class_id = table.Column<int>(type: "integer", nullable: false),
                    run_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    notification_id = table.Column<int>(type: "integer", nullable: true),
                    student_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    device_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    success_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    failure_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    skipped_reason = table.Column<string>(type: "citext", maxLength: 100, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_scheduled_notification_runs", x => x.id);
                    table.CheckConstraint("ck_class_scheduled_notification_runs_skipped_reason_length", "char_length(\"skipped_reason\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "class_scheduled_notifications",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    class_id = table.Column<int>(type: "integer", nullable: false),
                    created_by = table.Column<int>(type: "integer", nullable: false),
                    created_by_user_id = table.Column<int>(type: "integer", nullable: false),
                    title = table.Column<string>(type: "citext", maxLength: 255, nullable: false),
                    body = table.Column<string>(type: "citext", maxLength: 65535, nullable: false),
                    action_link = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    kind = table.Column<string>(type: "citext", maxLength: 8, nullable: false),
                    send_at = table.Column<DateTime>(type: "timestamp without time zone", nullable: true),
                    weekdays = table.Column<string>(type: "citext", maxLength: 20, nullable: true),
                    send_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    tz = table.Column<string>(type: "citext", maxLength: 64, nullable: false),
                    class_schedule_id = table.Column<int>(type: "integer", nullable: true),
                    offset_minutes = table.Column<int>(type: "integer", nullable: true),
                    repeat_weekly = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    status = table.Column<string>(type: "citext", maxLength: 6, nullable: false, defaultValue: "active"),
                    last_run_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    last_run_key = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_scheduled_notifications", x => x.id);
                    table.CheckConstraint("ck_class_scheduled_notifications_action_link_length", "char_length(\"action_link\") <= 500");
                    table.CheckConstraint("ck_class_scheduled_notifications_body_length", "char_length(\"body\") <= 65535");
                    table.CheckConstraint("ck_class_scheduled_notifications_kind", "kind in ('ONCE', 'WEEKLY', 'REMINDER')");
                    table.CheckConstraint("ck_class_scheduled_notifications_kind_length", "char_length(\"kind\") <= 8");
                    table.CheckConstraint("ck_class_scheduled_notifications_last_run_key_length", "char_length(\"last_run_key\") <= 100");
                    table.CheckConstraint("ck_class_scheduled_notifications_status", "status in ('active', 'done')");
                    table.CheckConstraint("ck_class_scheduled_notifications_status_length", "char_length(\"status\") <= 6");
                    table.CheckConstraint("ck_class_scheduled_notifications_title_length", "char_length(\"title\") <= 255");
                    table.CheckConstraint("ck_class_scheduled_notifications_tz_length", "char_length(\"tz\") <= 64");
                    table.CheckConstraint("ck_class_scheduled_notifications_weekdays_length", "char_length(\"weekdays\") <= 20");
                });

            migrationBuilder.CreateTable(
                name: "notifications",
                schema: "notifications",
                columns: table => new
                {
                    notification_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    title = table.Column<string>(type: "citext", maxLength: 255, nullable: false),
                    body = table.Column<string>(type: "citext", maxLength: 65535, nullable: false),
                    target_audience_criteria = table.Column<string>(type: "citext", nullable: false),
                    sent_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by = table.Column<int>(type: "integer", nullable: false),
                    device_count = table.Column<int>(type: "integer", nullable: true, defaultValue: 0),
                    success_count = table.Column<int>(type: "integer", nullable: true, defaultValue: 0),
                    failure_count = table.Column<int>(type: "integer", nullable: true, defaultValue: 0),
                    priority = table.Column<string>(type: "citext", maxLength: 20, nullable: true, defaultValue: "NORMAL"),
                    image_url = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    action_link = table.Column<string>(type: "citext", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_notifications", x => x.notification_id);
                    table.CheckConstraint("ck_notifications_action_link_length", "char_length(\"action_link\") <= 500");
                    table.CheckConstraint("ck_notifications_body_length", "char_length(\"body\") <= 65535");
                    table.CheckConstraint("ck_notifications_image_url_length", "char_length(\"image_url\") <= 500");
                    table.CheckConstraint("ck_notifications_priority_length", "char_length(\"priority\") <= 20");
                    table.CheckConstraint("ck_notifications_target_audience_criteria_json", "target_audience_criteria::text is json");
                    table.CheckConstraint("ck_notifications_title_length", "char_length(\"title\") <= 255");
                });

            migrationBuilder.CreateTable(
                name: "notifier_reminders",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "citext", maxLength: 80, nullable: false),
                    type = table.Column<string>(type: "citext", maxLength: 40, nullable: false, defaultValue: "cform_missing"),
                    gender = table.Column<string>(type: "citext", maxLength: 10, nullable: false, defaultValue: "gents"),
                    city = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    country = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    levels = table.Column<string>(type: "citext", maxLength: 255, nullable: false, defaultValue: "BILAL,AMMAR,MIQDAD,ABUZAR"),
                    lang = table.Column<string>(type: "citext", maxLength: 20, nullable: false, defaultValue: "english"),
                    leeway_days = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)10),
                    timezone = table.Column<string>(type: "citext", maxLength: 64, nullable: false, defaultValue: "Asia/Kolkata"),
                    weekday = table.Column<short>(type: "smallint", nullable: true),
                    send_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    schedule_on = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    enabled = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)1),
                    updated_by = table.Column<int>(type: "integer", nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_notifier_reminders", x => x.id);
                    table.CheckConstraint("ck_notifier_reminders_city_length", "char_length(\"city\") <= 100");
                    table.CheckConstraint("ck_notifier_reminders_country_length", "char_length(\"country\") <= 100");
                    table.CheckConstraint("ck_notifier_reminders_gender_length", "char_length(\"gender\") <= 10");
                    table.CheckConstraint("ck_notifier_reminders_lang_length", "char_length(\"lang\") <= 20");
                    table.CheckConstraint("ck_notifier_reminders_levels_length", "char_length(\"levels\") <= 255");
                    table.CheckConstraint("ck_notifier_reminders_name_length", "char_length(\"name\") <= 80");
                    table.CheckConstraint("ck_notifier_reminders_timezone_length", "char_length(\"timezone\") <= 64");
                    table.CheckConstraint("ck_notifier_reminders_type_length", "char_length(\"type\") <= 40");
                });

            migrationBuilder.CreateTable(
                name: "notifier_runs",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    reminder_id = table.Column<int>(type: "integer", nullable: true),
                    started_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    finished_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    from_date = table.Column<DateOnly>(type: "date", nullable: true),
                    to_date = table.Column<DateOnly>(type: "date", nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 20, nullable: false, defaultValue: "running"),
                    sent_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    skipped_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    failed_count = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    dry_run = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    triggered_by = table.Column<int>(type: "integer", nullable: true),
                    settings_snapshot = table.Column<string>(type: "citext", nullable: true),
                    error_message = table.Column<string>(type: "citext", maxLength: 65535, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_notifier_runs", x => x.id);
                    table.CheckConstraint("ck_notifier_runs_error_message_length", "char_length(\"error_message\") <= 65535");
                    table.CheckConstraint("ck_notifier_runs_settings_snapshot_json", "settings_snapshot::text is json");
                    table.CheckConstraint("ck_notifier_runs_status_length", "char_length(\"status\") <= 20");
                });

            migrationBuilder.CreateTable(
                name: "user_devices",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    token = table.Column<int>(type: "integer", nullable: false),
                    device_id = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    last_accessed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    registered_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_devices", x => x.id);
                    table.CheckConstraint("ck_user_devices_device_id_length", "char_length(\"device_id\") <= 500");
                });

            migrationBuilder.CreateTable(
                name: "user_notifications",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    notification_id = table.Column<int>(type: "integer", nullable: false),
                    user_token = table.Column<int>(type: "integer", nullable: false),
                    is_read = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    read_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_notifications", x => x.id);
                    table.ForeignKey(
                        name: "fk_user_notifications_notification",
                        column: x => x.notification_id,
                        principalSchema: "notifications",
                        principalTable: "notifications",
                        principalColumn: "notification_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "notifier_sent_messages",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    run_id = table.Column<long>(type: "bigint", nullable: false),
                    teacher_token = table.Column<int>(type: "integer", nullable: true),
                    teacher_mobile = table.Column<string>(type: "citext", maxLength: 20, nullable: false),
                    teacher_name = table.Column<string>(type: "citext", maxLength: 150, nullable: true),
                    total_missing = table.Column<int>(type: "integer", nullable: true),
                    message_excerpt = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 20, nullable: false),
                    error = table.Column<string>(type: "citext", maxLength: 65535, nullable: true),
                    sent_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_notifier_sent_messages", x => x.id);
                    table.CheckConstraint("ck_notifier_sent_messages_error_length", "char_length(\"error\") <= 65535");
                    table.CheckConstraint("ck_notifier_sent_messages_message_excerpt_length", "char_length(\"message_excerpt\") <= 500");
                    table.CheckConstraint("ck_notifier_sent_messages_status_length", "char_length(\"status\") <= 20");
                    table.CheckConstraint("ck_notifier_sent_messages_teacher_mobile_length", "char_length(\"teacher_mobile\") <= 20");
                    table.CheckConstraint("ck_notifier_sent_messages_teacher_name_length", "char_length(\"teacher_name\") <= 150");
                    table.ForeignKey(
                        name: "fk_notifier_sent_run",
                        column: x => x.run_id,
                        principalSchema: "notifications",
                        principalTable: "notifier_runs",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "idx_class_run_at",
                schema: "notifications",
                table: "class_scheduled_notification_runs",
                columns: new[] { "class_id", "run_at" });

            migrationBuilder.CreateIndex(
                name: "idx_run_at",
                schema: "notifications",
                table: "class_scheduled_notification_runs",
                column: "run_at");

            migrationBuilder.CreateIndex(
                name: "idx_scheduled_id",
                schema: "notifications",
                table: "class_scheduled_notification_runs",
                column: "scheduled_id");

            migrationBuilder.CreateIndex(
                name: "idx_class_id",
                schema: "notifications",
                table: "class_scheduled_notifications",
                column: "class_id");

            migrationBuilder.CreateIndex(
                name: "idx_status_kind",
                schema: "notifications",
                table: "class_scheduled_notifications",
                columns: new[] { "status", "kind" });

            migrationBuilder.CreateIndex(
                name: "idx_created_by",
                schema: "notifications",
                table: "notifications",
                column: "created_by");

            migrationBuilder.CreateIndex(
                name: "idx_sent_at",
                schema: "notifications",
                table: "notifications",
                column: "sent_at");

            migrationBuilder.CreateIndex(
                name: "uq_notifier_reminders_name",
                schema: "notifications",
                table: "notifier_reminders",
                column: "name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_reminder_started",
                schema: "notifications",
                table: "notifier_runs",
                columns: new[] { "reminder_id", "started_at" });

            migrationBuilder.CreateIndex(
                name: "idx_started_at",
                schema: "notifications",
                table: "notifier_runs",
                column: "started_at");

            migrationBuilder.CreateIndex(
                name: "idx_status",
                schema: "notifications",
                table: "notifier_runs",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "idx_mobile_sent_at",
                schema: "notifications",
                table: "notifier_sent_messages",
                columns: new[] { "teacher_mobile", "sent_at" });

            migrationBuilder.CreateIndex(
                name: "idx_run_id",
                schema: "notifications",
                table: "notifier_sent_messages",
                column: "run_id");

            migrationBuilder.CreateIndex(
                name: "idx_user_token",
                schema: "notifications",
                table: "user_notifications",
                column: "user_token");

            migrationBuilder.CreateIndex(
                name: "idx_user_unread",
                schema: "notifications",
                table: "user_notifications",
                columns: new[] { "user_token", "is_read" });

            migrationBuilder.CreateIndex(
                name: "unique_user_notification",
                schema: "notifications",
                table: "user_notifications",
                columns: new[] { "notification_id", "user_token" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "class_scheduled_notification_runs",
                schema: "notifications");

            migrationBuilder.DropTable(
                name: "class_scheduled_notifications",
                schema: "notifications");

            migrationBuilder.DropTable(
                name: "notifier_reminders",
                schema: "notifications");

            migrationBuilder.DropTable(
                name: "notifier_sent_messages",
                schema: "notifications");

            migrationBuilder.DropTable(
                name: "user_devices",
                schema: "notifications");

            migrationBuilder.DropTable(
                name: "user_notifications",
                schema: "notifications");

            migrationBuilder.DropTable(
                name: "notifier_runs",
                schema: "notifications");

            migrationBuilder.DropTable(
                name: "notifications",
                schema: "notifications");
        }
    }
}
