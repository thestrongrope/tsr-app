using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Platform.Api.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "platform");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "feedback",
                schema: "platform",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    user_id = table.Column<int>(type: "integer", nullable: true),
                    client_id = table.Column<string>(type: "citext", maxLength: 36, nullable: false),
                    message = table.Column<string>(type: "citext", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    handled_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    handled_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_feedback", x => x.id);
                    table.CheckConstraint("ck_feedback_client_id_length", "char_length(\"client_id\") <= 36");
                });

            migrationBuilder.CreateTable(
                name: "outbox",
                schema: "platform",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    event_type = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    payload = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    published_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_outbox", x => x.id);
                    table.CheckConstraint("ck_outbox_event_type_length", "char_length(\"event_type\") <= 100");
                });

            migrationBuilder.CreateIndex(
                name: "idx_feedback_handled_created",
                schema: "platform",
                table: "feedback",
                columns: new[] { "handled_at", "created_at" });

            migrationBuilder.CreateIndex(
                name: "uq_feedback_user_client",
                schema: "platform",
                table: "feedback",
                columns: new[] { "user_id", "client_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_outbox_unpublished",
                schema: "platform",
                table: "outbox",
                columns: new[] { "published_at", "created_at" });

            // Hand-added: foreign keys to identity.users, which the model cannot express across two contexts.
            // Safe because identity's migrations run first (DomainContexts, registration order).
            migrationBuilder.Sql(
                "alter table platform.feedback add constraint fk_feedback_user foreign key (user_id) references identity.users (id) on delete set null");
            migrationBuilder.Sql(
                "alter table platform.feedback add constraint fk_feedback_handled_by foreign key (handled_by) references identity.users (id) on delete set null");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "feedback",
                schema: "platform");

            migrationBuilder.DropTable(
                name: "outbox",
                schema: "platform");
        }
    }
}
