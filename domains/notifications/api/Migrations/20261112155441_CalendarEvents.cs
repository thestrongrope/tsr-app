using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Notifications.Api.Migrations
{
    /// <inheritdoc />
    public partial class CalendarEvents : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "class_scheduled_events",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    class_id = table.Column<int>(type: "integer", nullable: false),
                    created_by = table.Column<int>(type: "integer", nullable: false),
                    created_by_user_id = table.Column<int>(type: "integer", nullable: false),
                    message = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    description = table.Column<string>(type: "citext", maxLength: 65535, nullable: true),
                    action_link = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    weekdays = table.Column<string>(type: "citext", maxLength: 20, nullable: false),
                    send_time = table.Column<TimeOnly>(type: "time without time zone", nullable: false),
                    tz = table.Column<string>(type: "citext", maxLength: 64, nullable: false),
                    status = table.Column<string>(type: "citext", maxLength: 7, nullable: false, defaultValue: "active"),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_scheduled_events", x => x.id);
                    table.CheckConstraint("ck_class_scheduled_events_action_link_length", "char_length(\"action_link\") <= 500");
                    table.CheckConstraint("ck_class_scheduled_events_description_length", "char_length(\"description\") <= 65535");
                    table.CheckConstraint("ck_class_scheduled_events_message_length", "char_length(\"message\") <= 500");
                    table.CheckConstraint("ck_class_scheduled_events_status", "status in ('active', 'deleted')");
                    table.CheckConstraint("ck_class_scheduled_events_status_length", "char_length(\"status\") <= 7");
                    table.CheckConstraint("ck_class_scheduled_events_tz_length", "char_length(\"tz\") <= 64");
                    table.CheckConstraint("ck_class_scheduled_events_weekdays_length", "char_length(\"weekdays\") <= 20");
                });

            migrationBuilder.CreateTable(
                name: "member_event_settings",
                schema: "notifications",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    user_id = table.Column<int>(type: "integer", nullable: false),
                    class_id = table.Column<int>(type: "integer", nullable: false),
                    event_key = table.Column<string>(type: "citext", maxLength: 64, nullable: false),
                    offset_minutes = table.Column<int>(type: "integer", nullable: true),
                    muted = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    deleted_for_me = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)0),
                    client_updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    server_updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    device_key = table.Column<string>(type: "citext", maxLength: 64, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_member_event_settings", x => x.id);
                    table.CheckConstraint("ck_member_event_settings_device_key_length", "char_length(\"device_key\") <= 64");
                    table.CheckConstraint("ck_member_event_settings_event_key_length", "char_length(\"event_key\") <= 64");
                });

            migrationBuilder.CreateIndex(
                name: "idx_class_status",
                schema: "notifications",
                table: "class_scheduled_events",
                columns: new[] { "class_id", "status" });

            migrationBuilder.CreateIndex(
                name: "idx_member_class",
                schema: "notifications",
                table: "member_event_settings",
                columns: new[] { "user_id", "class_id" });

            migrationBuilder.CreateIndex(
                name: "uq_member_event",
                schema: "notifications",
                table: "member_event_settings",
                columns: new[] { "user_id", "event_key" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "class_scheduled_events",
                schema: "notifications");

            migrationBuilder.DropTable(
                name: "member_event_settings",
                schema: "notifications");
        }
    }
}
