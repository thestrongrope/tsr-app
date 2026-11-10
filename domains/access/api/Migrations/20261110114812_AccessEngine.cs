using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Access.Api.Migrations
{
    /// <inheritdoc />
    public partial class AccessEngine : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // The first migration added a foreign key from user_permissions.user_id to another domain's table.
            // A domain never references another domain's tables, so it goes; user_id is a plain id.
            migrationBuilder.Sql("alter table access.user_permissions drop constraint fk_user_permissions_user");

            migrationBuilder.AddColumn<string>(
                name: "reason",
                schema: "access",
                table: "user_permissions",
                type: "citext",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "revoke_reason",
                schema: "access",
                table: "user_permissions",
                type: "citext",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "revoked_by",
                schema: "access",
                table: "user_permissions",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "class_access_rules",
                schema: "access",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    token = table.Column<int>(type: "integer", nullable: false),
                    gender = table.Column<int>(type: "integer", nullable: true),
                    note = table.Column<string>(type: "citext", maxLength: 255, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    granted_by = table.Column<int>(type: "integer", nullable: true),
                    reason = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    revoked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    revoked_by = table.Column<int>(type: "integer", nullable: true),
                    revoke_reason = table.Column<string>(type: "citext", maxLength: 300, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_access_rules", x => x.id);
                    table.CheckConstraint("ck_class_access_rules_gender", "gender in (1, 2)");
                    table.CheckConstraint("ck_class_access_rules_note_length", "char_length(\"note\") <= 255");
                    table.CheckConstraint("ck_class_access_rules_reason_length", "char_length(\"reason\") <= 300");
                    table.CheckConstraint("ck_class_access_rules_revoke_reason_length", "char_length(\"revoke_reason\") <= 300");
                });

            migrationBuilder.CreateTable(
                name: "roles",
                schema: "access",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false),
                    name = table.Column<string>(type: "citext", maxLength: 30, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_roles", x => x.id);
                    table.CheckConstraint("ck_roles_name_length", "char_length(\"name\") <= 30");
                });

            // The role ids PHP uses (web/functions.php) and the names it shows (routes/permissions.php api_role_name).
            // Role 2 is unused in PHP and not listed. Before role_permissions gets its foreign key to roles.
            migrationBuilder.Sql(
                """
                insert into access.roles (id, name) values
                  (0, 'USER'), (1, 'SUPER_ADMIN'), (3, 'GENTS_ADMIN'), (4, 'LADIES_ADMIN'),
                  (5, 'CLASS_ADMIN'), (6, 'CLASS_TEACHER'), (7, 'FINANCE');
                """);

            migrationBuilder.CreateTable(
                name: "class_access_rule_conditions",
                schema: "access",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    rule_id = table.Column<int>(type: "integer", nullable: false),
                    field = table.Column<string>(type: "citext", maxLength: 20, nullable: false),
                    negate = table.Column<bool>(type: "boolean", nullable: false),
                    value = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    level_id = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_class_access_rule_conditions", x => x.id);
                    table.CheckConstraint("ck_class_access_rule_conditions_field", "field in ('city', 'country', 'level', 'tag')");
                    table.CheckConstraint("ck_class_access_rule_conditions_field_length", "char_length(\"field\") <= 20");
                    table.CheckConstraint("ck_class_access_rule_conditions_value", "(field = 'level' and level_id is not null and value is null) or (field <> 'level' and value is not null and level_id is null)");
                    table.CheckConstraint("ck_class_access_rule_conditions_value_length", "char_length(\"value\") <= 300");
                    table.ForeignKey(
                        name: "FK_class_access_rule_conditions_class_access_rules_rule_id",
                        column: x => x.rule_id,
                        principalSchema: "access",
                        principalTable: "class_access_rules",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "user_roles",
                schema: "access",
                columns: table => new
                {
                    user_id = table.Column<int>(type: "integer", nullable: false),
                    roleid = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_roles", x => x.user_id);
                    table.ForeignKey(
                        name: "FK_user_roles_roles_roleid",
                        column: x => x.roleid,
                        principalSchema: "access",
                        principalTable: "roles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_user_permissions_reason_length",
                schema: "access",
                table: "user_permissions",
                sql: "char_length(\"reason\") <= 300");

            migrationBuilder.AddCheckConstraint(
                name: "ck_user_permissions_revoke_reason_length",
                schema: "access",
                table: "user_permissions",
                sql: "char_length(\"revoke_reason\") <= 300");

            migrationBuilder.CreateIndex(
                name: "idx_class_access_rule_conditions_rule",
                schema: "access",
                table: "class_access_rule_conditions",
                column: "rule_id");

            migrationBuilder.CreateIndex(
                name: "idx_class_access_rules_token",
                schema: "access",
                table: "class_access_rules",
                column: "token");

            migrationBuilder.CreateIndex(
                name: "IX_user_roles_roleid",
                schema: "access",
                table: "user_roles",
                column: "roleid");

            migrationBuilder.AddForeignKey(
                name: "FK_role_permissions_roles_roleid",
                schema: "access",
                table: "role_permissions",
                column: "roleid",
                principalSchema: "access",
                principalTable: "roles",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_role_permissions_roles_roleid",
                schema: "access",
                table: "role_permissions");

            migrationBuilder.DropTable(
                name: "class_access_rule_conditions",
                schema: "access");

            migrationBuilder.DropTable(
                name: "user_roles",
                schema: "access");

            migrationBuilder.DropTable(
                name: "class_access_rules",
                schema: "access");

            migrationBuilder.DropTable(
                name: "roles",
                schema: "access");

            migrationBuilder.DropCheckConstraint(
                name: "ck_user_permissions_reason_length",
                schema: "access",
                table: "user_permissions");

            migrationBuilder.DropCheckConstraint(
                name: "ck_user_permissions_revoke_reason_length",
                schema: "access",
                table: "user_permissions");

            migrationBuilder.DropColumn(
                name: "reason",
                schema: "access",
                table: "user_permissions");

            migrationBuilder.DropColumn(
                name: "revoke_reason",
                schema: "access",
                table: "user_permissions");

            migrationBuilder.DropColumn(
                name: "revoked_by",
                schema: "access",
                table: "user_permissions");
        }
    }
}
