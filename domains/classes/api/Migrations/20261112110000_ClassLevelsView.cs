using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // Publishes the class levels as classes.v_class_levels: access's class access screens offer them and check a rule's level exists (PHP ClassesModel::listLevels).
    // Views only: no table changes. A view is a contract: add columns last, never remove one.
    /// <inheritdoc />
    [DbContext(typeof(ClassesContext))]
    [Migration("20261112110000_ClassLevelsView")]
    public sealed class ClassLevelsView : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view classes.v_class_levels as
                select id, code, name, sort_order
                from classes.class_levels;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view classes.v_class_levels;");
        }
    }
}
