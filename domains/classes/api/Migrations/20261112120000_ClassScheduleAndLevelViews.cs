using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // Two new published views (views only, no table change). v_class_schedules: a class's weekly slots, deleted ones included (deleted_at), for notifications' scheduled
    // reminders; v_class_levels: the level names, for notifications' history. A view is a contract: add columns last, never change one.
    /// <inheritdoc />
    [DbContext(typeof(ClassesContext))]
    [Migration("20261112120000_ClassScheduleAndLevelViews")]
    public sealed class ClassScheduleAndLevelViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view classes.v_class_schedules as
                select id, class_id, day, hour, minute, timezone, deleted_at
                from classes.class_schedules;
                """);
            migrationBuilder.Sql(
                """
                create view classes.v_class_levels as
                select id, name
                from classes.class_levels;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view classes.v_class_levels;");
            migrationBuilder.Sql("drop view classes.v_class_schedules;");
        }
    }
}
