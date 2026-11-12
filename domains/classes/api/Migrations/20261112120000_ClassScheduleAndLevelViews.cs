using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // One new published view (views only, no table change). v_class_schedules: a class's weekly slots, deleted ones included (deleted_at), for notifications' scheduled
    // reminders. (The level names notifications' history needs come from v_class_levels, created by the earlier migration ClassLevelsView; this migration first created a second copy, removed when the lanes were merged, before it was ever applied.) A view is a contract: add columns last, never change one.
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
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view classes.v_class_schedules;");
        }
    }
}
