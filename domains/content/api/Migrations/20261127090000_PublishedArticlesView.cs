using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Content.Api.Migrations
{
    // A view this domain publishes to the others (domains/CLAUDE.md rule 2): a view is a contract; change one with its readers.
    // The article feed and the database fallback of article search (domain `search`) read the published articles through it. The HTML body stays private.
    // The API role's read-only grant on every view is made by the migrate job (DomainContexts.GrantAppRoleAsync).
    /// <inheritdoc />
    [DbContext(typeof(ContentContext))]
    [Migration("20261127090000_PublishedArticlesView")]
    public sealed class PublishedArticlesView : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view content.v_published_articles as
                select slug, title, excerpt, body_markdown, published_at, published_date_text, modified_date_text,
                       author, language, reading_minutes, legacy_id, categories, tags
                from content.published_articles;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view content.v_published_articles;");
        }
    }
}
