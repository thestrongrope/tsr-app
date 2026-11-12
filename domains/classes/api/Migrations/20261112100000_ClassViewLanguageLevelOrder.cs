using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // Adds `language_id` (the class's teaching language, null when unset) and `level_sort_order` (the level's position, null with no level) to the published view classes.v_classes: assessment's manage and copy routes
    // choose the standard MCQs of a class by its language and list the classes a member may copy between in PHP's order (gender, level order, id).
    // A view is a contract: the new columns are last, the others are unchanged. Hand-written like ClassViewExtraStudents (a views-only migration has no model change, so `dotnet ef` would add nothing).
    /// <inheritdoc />
    [DbContext(typeof(ClassesContext))]
    [Migration("20261112100000_ClassViewLanguageLevelOrder")]
    public sealed class ClassViewLanguageLevelOrder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create or replace view classes.v_classes as
                select c.id, c.code, c.name, c.class_level_id, c.gender, c.teacher, c.status, c.city, c.country, l.name as level_name, c.extra_students, c.language_id, l.sort_order as level_sort_order
                from classes.classes c
                left join classes.class_levels l on l.id = c.class_level_id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                drop view classes.v_classes;
                create view classes.v_classes as
                select c.id, c.code, c.name, c.class_level_id, c.gender, c.teacher, c.status, c.city, c.country, l.name as level_name, c.extra_students
                from classes.classes c
                left join classes.class_levels l on l.id = c.class_level_id;
                """);
        }
    }
}
