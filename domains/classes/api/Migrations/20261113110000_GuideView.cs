using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // Publishes the guides as classes.v_guides: search re-checks a guide hit against it (PHP SearchSourceModel guideSql: a non-empty guide, and the level's name).
    // The guide text itself is not published, only whether there is any. Views only: no table changes. A view is a contract: add columns last, never remove one.
    /// <inheritdoc />
    [DbContext(typeof(ClassesContext))]
    [Migration("20261113110000_GuideView")]
    public sealed class GuideView : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view classes.v_guides as
                select g.level_id, g.language_id, l.name as level_name, btrim(coalesce(g.guide, '')) <> '' as has_text
                from classes.guides g
                join classes.class_levels l on l.id = g.level_id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view classes.v_guides;");
        }
    }
}
