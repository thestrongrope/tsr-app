using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    /// <inheritdoc />
    public partial class QuizCodeUnique : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "spot_quizzes_code",
                schema: "assessment",
                table: "spot_quizzes",
                column: "code",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "spot_quizzes_code",
                schema: "assessment",
                table: "spot_quizzes");
        }
    }
}
