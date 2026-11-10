using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Identity.Api.Migrations
{
    /// <inheritdoc />
    public partial class IdentityUsersAndDeletion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "roleid",
                schema: "identity",
                table: "users");

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "createdon",
                schema: "identity",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "device",
                schema: "identity",
                table: "users",
                type: "citext",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "firebase_uid",
                schema: "identity",
                table: "users",
                type: "citext",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "lastdevice",
                schema: "identity",
                table: "users",
                type: "citext",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "lastlogin",
                schema: "identity",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "lastloginip",
                schema: "identity",
                table: "users",
                type: "citext",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "platform",
                schema: "identity",
                table: "users",
                type: "citext",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "provider",
                schema: "identity",
                table: "users",
                type: "citext",
                maxLength: 10,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "version",
                schema: "identity",
                table: "users",
                type: "citext",
                maxLength: 200,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "account_deletion_requests",
                schema: "identity",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    token = table.Column<int>(type: "integer", nullable: true),
                    status = table.Column<string>(type: "citext", maxLength: 30, nullable: false),
                    contact_email = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    requested_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_account_deletion_requests", x => x.id);
                    table.CheckConstraint("ck_account_deletion_requests_contact_email_length", "char_length(\"contact_email\") <= 200");
                    table.CheckConstraint("ck_account_deletion_requests_status", "status in ('pending', 'awaiting_prize_delivery', 'completed', 'cancelled')");
                    table.CheckConstraint("ck_account_deletion_requests_status_length", "char_length(\"status\") <= 30");
                });

            migrationBuilder.CreateIndex(
                name: "idx_users_email",
                schema: "identity",
                table: "users",
                column: "email");

            migrationBuilder.CreateIndex(
                name: "idx_users_firebase_uid",
                schema: "identity",
                table: "users",
                column: "firebase_uid",
                unique: true);

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_device_length",
                schema: "identity",
                table: "users",
                sql: "char_length(\"device\") <= 200");

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_firebase_uid_length",
                schema: "identity",
                table: "users",
                sql: "char_length(\"firebase_uid\") <= 128");

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_lastdevice_length",
                schema: "identity",
                table: "users",
                sql: "char_length(\"lastdevice\") <= 2000");

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_lastloginip_length",
                schema: "identity",
                table: "users",
                sql: "char_length(\"lastloginip\") <= 100");

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_platform_length",
                schema: "identity",
                table: "users",
                sql: "char_length(\"platform\") <= 200");

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_provider_length",
                schema: "identity",
                table: "users",
                sql: "char_length(\"provider\") <= 10");

            migrationBuilder.AddCheckConstraint(
                name: "ck_users_version_length",
                schema: "identity",
                table: "users",
                sql: "char_length(\"version\") <= 200");

            migrationBuilder.CreateIndex(
                name: "idx_account_deletion_requests_contact_email",
                schema: "identity",
                table: "account_deletion_requests",
                column: "contact_email");

            migrationBuilder.CreateIndex(
                name: "idx_account_deletion_requests_token",
                schema: "identity",
                table: "account_deletion_requests",
                column: "token");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "account_deletion_requests",
                schema: "identity");

            migrationBuilder.DropIndex(
                name: "idx_users_email",
                schema: "identity",
                table: "users");

            migrationBuilder.DropIndex(
                name: "idx_users_firebase_uid",
                schema: "identity",
                table: "users");

            migrationBuilder.DropCheckConstraint(
                name: "ck_users_device_length",
                schema: "identity",
                table: "users");

            migrationBuilder.DropCheckConstraint(
                name: "ck_users_firebase_uid_length",
                schema: "identity",
                table: "users");

            migrationBuilder.DropCheckConstraint(
                name: "ck_users_lastdevice_length",
                schema: "identity",
                table: "users");

            migrationBuilder.DropCheckConstraint(
                name: "ck_users_lastloginip_length",
                schema: "identity",
                table: "users");

            migrationBuilder.DropCheckConstraint(
                name: "ck_users_platform_length",
                schema: "identity",
                table: "users");

            migrationBuilder.DropCheckConstraint(
                name: "ck_users_provider_length",
                schema: "identity",
                table: "users");

            migrationBuilder.DropCheckConstraint(
                name: "ck_users_version_length",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "createdon",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "device",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "firebase_uid",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "lastdevice",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "lastlogin",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "lastloginip",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "platform",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "provider",
                schema: "identity",
                table: "users");

            migrationBuilder.DropColumn(
                name: "version",
                schema: "identity",
                table: "users");

            migrationBuilder.AddColumn<int>(
                name: "roleid",
                schema: "identity",
                table: "users",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }
    }
}
