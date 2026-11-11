using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Identity.Api.Migrations
{
    /// <inheritdoc />
    public partial class DeletionRequestRest : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "cancelled_at",
                schema: "identity",
                table: "account_deletion_requests",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "confirmation_sent_at",
                schema: "identity",
                table: "account_deletion_requests",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "contact_name",
                schema: "identity",
                table: "account_deletion_requests",
                type: "citext",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "handled_by",
                schema: "identity",
                table: "account_deletion_requests",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "operator_note",
                schema: "identity",
                table: "account_deletion_requests",
                type: "citext",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "reason",
                schema: "identity",
                table: "account_deletion_requests",
                type: "citext",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "source",
                schema: "identity",
                table: "account_deletion_requests",
                type: "citext",
                maxLength: 3,
                nullable: false,
                defaultValue: "app");

            migrationBuilder.CreateIndex(
                name: "idx_status_requested",
                schema: "identity",
                table: "account_deletion_requests",
                columns: new[] { "status", "requested_at" });

            migrationBuilder.CreateIndex(
                name: "uq_active_token",
                schema: "identity",
                table: "account_deletion_requests",
                column: "token",
                unique: true,
                filter: "status in ('pending', 'awaiting_prize_delivery')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_account_deletion_requests_contact_name_length",
                schema: "identity",
                table: "account_deletion_requests",
                sql: "char_length(\"contact_name\") <= 200");

            migrationBuilder.AddCheckConstraint(
                name: "ck_account_deletion_requests_operator_note_length",
                schema: "identity",
                table: "account_deletion_requests",
                sql: "char_length(\"operator_note\") <= 1000");

            migrationBuilder.AddCheckConstraint(
                name: "ck_account_deletion_requests_reason_length",
                schema: "identity",
                table: "account_deletion_requests",
                sql: "char_length(\"reason\") <= 500");

            migrationBuilder.AddCheckConstraint(
                name: "ck_account_deletion_requests_source",
                schema: "identity",
                table: "account_deletion_requests",
                sql: "source in ('app', 'web')");

            migrationBuilder.AddCheckConstraint(
                name: "ck_account_deletion_requests_source_length",
                schema: "identity",
                table: "account_deletion_requests",
                sql: "char_length(\"source\") <= 3");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "idx_status_requested",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropIndex(
                name: "uq_active_token",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropCheckConstraint(
                name: "ck_account_deletion_requests_contact_name_length",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropCheckConstraint(
                name: "ck_account_deletion_requests_operator_note_length",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropCheckConstraint(
                name: "ck_account_deletion_requests_reason_length",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropCheckConstraint(
                name: "ck_account_deletion_requests_source",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropCheckConstraint(
                name: "ck_account_deletion_requests_source_length",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropColumn(
                name: "cancelled_at",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropColumn(
                name: "confirmation_sent_at",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropColumn(
                name: "contact_name",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropColumn(
                name: "handled_by",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropColumn(
                name: "operator_note",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropColumn(
                name: "reason",
                schema: "identity",
                table: "account_deletion_requests");

            migrationBuilder.DropColumn(
                name: "source",
                schema: "identity",
                table: "account_deletion_requests");
        }
    }
}
