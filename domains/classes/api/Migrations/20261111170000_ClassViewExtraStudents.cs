using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // Adds `extra_students` (the class's list of extra student names, one per line, null when none) to the published view classes.v_classes: membership's placed-registrations file counts them (PHP getAllocatedRegistrations).
    // A view is a contract: the new column is last, the others are unchanged. Hand-written like ClassViewLevelName (a views-only migration has no model change, so `dotnet ef` would add nothing).
    /// <inheritdoc />
    [DbContext(typeof(ClassesContext))]
    [Migration("20261111170000_ClassViewExtraStudents")]
    public sealed class ClassViewExtraStudents : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create or replace view classes.v_classes as
                select c.id, c.code, c.name, c.class_level_id, c.gender, c.teacher, c.status, c.city, c.country, l.name as level_name, c.extra_students
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
                select c.id, c.code, c.name, c.class_level_id, c.gender, c.teacher, c.status, c.city, c.country, l.name as level_name
                from classes.classes c
                left join classes.class_levels l on l.id = c.class_level_id;
                """);
        }
    }
}
