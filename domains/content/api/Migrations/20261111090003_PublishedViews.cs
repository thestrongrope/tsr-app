using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Content.Api.Migrations
{
    // The views this domain publishes to the others (domains/CLAUDE.md rule 2): a view is a contract; change one with its readers.
    /// <inheritdoc />
    [DbContext(typeof(ContentContext))]
    [Migration("20261111090003_PublishedViews")]
    public sealed class PublishedViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view content.v_quran as
                select id, surah, arabic, verses from content.holy_quran;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view content.v_quran;");
        }
    }
}
