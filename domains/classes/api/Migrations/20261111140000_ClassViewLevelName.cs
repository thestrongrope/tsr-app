using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // Adds `level_name` (the name of the class's level, null without one) to the published view classes.v_classes: membership's student card shows it (PHP entityaccess currentClasses).
    // A view is a contract: the new column is last, the others are unchanged.
    /// <inheritdoc />
    [DbContext(typeof(ClassesContext))]
    [Migration("20261111140000_ClassViewLevelName")]
    public sealed class ClassViewLevelName : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create or replace view classes.v_classes as
                select c.id, c.code, c.name, c.class_level_id, c.gender, c.teacher, c.status, c.city, c.country, l.name as level_name
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
                select id, code, name, class_level_id, gender, teacher, status, city, country
                from classes.classes;
                """);
        }
    }
}
