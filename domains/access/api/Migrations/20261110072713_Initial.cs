using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Access.Api.Migrations
{
    /// <inheritdoc />
    public partial class Initial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "access");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "permissions",
                schema: "access",
                columns: table => new
                {
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    description = table.Column<string>(type: "citext", maxLength: 255, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_permissions", x => x.name);
                    table.CheckConstraint("ck_permissions_description_length", "char_length(\"description\") <= 255");
                    table.CheckConstraint("ck_permissions_name_length", "char_length(\"name\") <= 100");
                });

            migrationBuilder.CreateTable(
                name: "role_permissions",
                schema: "access",
                columns: table => new
                {
                    roleid = table.Column<int>(type: "integer", nullable: false),
                    permission = table.Column<string>(type: "citext", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_role_permissions", x => new { x.roleid, x.permission });
                    table.CheckConstraint("ck_role_permissions_permission_length", "char_length(\"permission\") <= 100");
                    table.ForeignKey(
                        name: "FK_role_permissions_permissions_permission",
                        column: x => x.permission,
                        principalSchema: "access",
                        principalTable: "permissions",
                        principalColumn: "name",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "user_permissions",
                schema: "access",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    user_id = table.Column<int>(type: "integer", nullable: false),
                    permission = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    granted_by = table.Column<int>(type: "integer", nullable: true),
                    granted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    revoked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_permissions", x => x.id);
                    table.CheckConstraint("ck_user_permissions_permission_length", "char_length(\"permission\") <= 100");
                    table.ForeignKey(
                        name: "FK_user_permissions_permissions_permission",
                        column: x => x.permission,
                        principalSchema: "access",
                        principalTable: "permissions",
                        principalColumn: "name",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_role_permissions_permission",
                schema: "access",
                table: "role_permissions",
                column: "permission");

            migrationBuilder.CreateIndex(
                name: "idx_user_permissions_user",
                schema: "access",
                table: "user_permissions",
                columns: new[] { "user_id", "permission" });

            migrationBuilder.CreateIndex(
                name: "IX_user_permissions_permission",
                schema: "access",
                table: "user_permissions",
                column: "permission");

            // Hand-added: user_permissions.user_id references identity.users, which the model cannot express
            // across two contexts. Safe because identity's migrations run first.
            migrationBuilder.Sql(
                "alter table access.user_permissions add constraint fk_user_permissions_user foreign key (user_id) references identity.users (id)");

            // Base data: the feedback permissions in the catalog (access owns the catalog) and the role 1 grant.
            migrationBuilder.InsertData(
                schema: "access",
                table: "permissions",
                columns: new[] { "name", "description" },
                values: new object[,]
                {
                    { "feedback:create:self", "Send feedback to the team" },
                    { "feedback:review:all", "Review member feedback and mark items handled" },
                });
            migrationBuilder.InsertData(
                schema: "access",
                table: "role_permissions",
                columns: new[] { "roleid", "permission" },
                values: new object[] { 1, "feedback:review:all" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "role_permissions",
                schema: "access");

            migrationBuilder.DropTable(
                name: "user_permissions",
                schema: "access");

            migrationBuilder.DropTable(
                name: "permissions",
                schema: "access");
        }
    }
}
