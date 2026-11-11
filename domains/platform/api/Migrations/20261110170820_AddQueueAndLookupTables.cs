using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Platform.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddQueueAndLookupTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "admin_access_log",
                schema: "platform",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    accessed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    user_id = table.Column<int>(type: "integer", nullable: true),
                    token = table.Column<int>(type: "integer", nullable: true),
                    roleid = table.Column<int>(type: "integer", nullable: true),
                    page = table.Column<string>(type: "citext", maxLength: 255, nullable: false),
                    method = table.Column<string>(type: "citext", maxLength: 10, nullable: false),
                    ip = table.Column<string>(type: "citext", maxLength: 45, nullable: true),
                    user_agent = table.Column<string>(type: "citext", maxLength: 512, nullable: true),
                    referer = table.Column<string>(type: "citext", maxLength: 512, nullable: true),
                    session_id = table.Column<string>(type: "citext", maxLength: 128, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_admin_access_log", x => x.id);
                    table.CheckConstraint("ck_admin_access_log_ip_length", "char_length(\"ip\") <= 45");
                    table.CheckConstraint("ck_admin_access_log_method_length", "char_length(\"method\") <= 10");
                    table.CheckConstraint("ck_admin_access_log_page_length", "char_length(\"page\") <= 255");
                    table.CheckConstraint("ck_admin_access_log_referer_length", "char_length(\"referer\") <= 512");
                    table.CheckConstraint("ck_admin_access_log_session_id_length", "char_length(\"session_id\") <= 128");
                    table.CheckConstraint("ck_admin_access_log_user_agent_length", "char_length(\"user_agent\") <= 512");
                });

            migrationBuilder.CreateTable(
                name: "genders",
                schema: "platform",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_genders", x => x.id);
                    table.CheckConstraint("ck_genders_name_length", "char_length(\"name\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "languages",
                schema: "platform",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
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
                    table.PrimaryKey("PK_languages", x => x.id);
                    table.CheckConstraint("ck_languages_name_length", "char_length(\"name\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "outbound_messages",
                schema: "platform",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    channel = table.Column<string>(type: "citext", maxLength: 20, nullable: false),
                    recipient = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    payload = table.Column<string>(type: "citext", nullable: true),
                    dedupe_key = table.Column<string>(type: "citext", maxLength: 191, nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 20, nullable: false, defaultValue: "queued"),
                    attempts = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    next_attempt_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    sent_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    error = table.Column<string>(type: "citext", maxLength: 65535, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_outbound_messages", x => x.id);
                    table.CheckConstraint("ck_outbound_messages_channel_length", "char_length(\"channel\") <= 20");
                    table.CheckConstraint("ck_outbound_messages_dedupe_key_length", "char_length(\"dedupe_key\") <= 191");
                    table.CheckConstraint("ck_outbound_messages_error_length", "char_length(\"error\") <= 65535");
                    table.CheckConstraint("ck_outbound_messages_payload_json", "payload::text is json");
                    table.CheckConstraint("ck_outbound_messages_recipient_length", "char_length(\"recipient\") <= 500");
                    table.CheckConstraint("ck_outbound_messages_status_length", "char_length(\"status\") <= 20");
                });

            migrationBuilder.CreateIndex(
                name: "idx_accessed_at",
                schema: "platform",
                table: "admin_access_log",
                column: "accessed_at");

            migrationBuilder.CreateIndex(
                name: "idx_page",
                schema: "platform",
                table: "admin_access_log",
                column: "page");

            migrationBuilder.CreateIndex(
                name: "idx_token",
                schema: "platform",
                table: "admin_access_log",
                column: "token");

            migrationBuilder.CreateIndex(
                name: "idx_claim",
                schema: "platform",
                table: "outbound_messages",
                columns: new[] { "channel", "status", "next_attempt_at" });

            migrationBuilder.CreateIndex(
                name: "idx_created_at",
                schema: "platform",
                table: "outbound_messages",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "uq_channel_dedupe",
                schema: "platform",
                table: "outbound_messages",
                columns: new[] { "channel", "dedupe_key" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "admin_access_log",
                schema: "platform");

            migrationBuilder.DropTable(
                name: "genders",
                schema: "platform");

            migrationBuilder.DropTable(
                name: "languages",
                schema: "platform");

            migrationBuilder.DropTable(
                name: "outbound_messages",
                schema: "platform");
        }
    }
}
