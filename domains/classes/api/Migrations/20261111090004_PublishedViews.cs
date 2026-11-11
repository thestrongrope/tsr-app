using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // The views this domain publishes to the others (domains/CLAUDE.md rule 2): a view is a contract; change one with its readers.
    /// <inheritdoc />
    [DbContext(typeof(ClassesContext))]
    [Migration("20261111090004_PublishedViews")]
    public sealed class PublishedViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view classes.v_classes as
                select id, code, name, class_level_id, gender, teacher, status, city, country
                from classes.classes;
                """);
            migrationBuilder.Sql(
                """
                create view classes.v_enrolments as
                select id, class_id, token_no, status, removed_at, mcq_admin
                from classes.class_students;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view classes.v_enrolments;");
            migrationBuilder.Sql("drop view classes.v_classes;");
        }
    }
}
