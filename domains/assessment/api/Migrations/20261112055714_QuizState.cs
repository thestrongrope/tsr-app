using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    // The quiz competition's state documents (PHP kept them as JSON files): ONE new table. The EF tool generated this migration as a
    // create of the whole schema (every assessment table again), which fails on any existing database; it was cut down to the one new
    // table on 12 Nov 2026, before it was ever applied.
    /// <inheritdoc />
    public partial class QuizState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "quiz_state",
                schema: "assessment",
                columns: table => new
                {
                    name = table.Column<string>(type: "citext", maxLength: 50, nullable: false),
                    document = table.Column<string>(type: "jsonb", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_quiz_state", x => x.name);
                    table.CheckConstraint("ck_quiz_state_name_length", "char_length(\"name\") <= 50");
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "quiz_state",
                schema: "assessment");
        }
    }
}
