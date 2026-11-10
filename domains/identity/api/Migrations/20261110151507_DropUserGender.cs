using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Identity.Api.Migrations
{
    /// <inheritdoc />
    public partial class DropUserGender : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "gender",
                schema: "identity",
                table: "users");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "gender",
                schema: "identity",
                table: "users",
                type: "smallint",
                nullable: true);
        }
    }
}
