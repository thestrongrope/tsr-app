using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Platform.Api.Migrations
{
    // The views this domain publishes to the others (domains/CLAUDE.md rule 2): a view is a contract; change one with its readers.
    /// <inheritdoc />
    [DbContext(typeof(PlatformContext))]
    [Migration("20261111090002_PublishedViews")]
    public sealed class PublishedViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view platform.v_genders as
                select id, name from platform.genders;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view platform.v_genders;");
        }
    }
}
