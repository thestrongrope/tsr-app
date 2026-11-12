using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Platform.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddOutboundClaimedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "claimed_at",
                schema: "platform",
                table: "outbound_messages",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "claimed_at",
                schema: "platform",
                table: "outbound_messages");
        }
    }
}
