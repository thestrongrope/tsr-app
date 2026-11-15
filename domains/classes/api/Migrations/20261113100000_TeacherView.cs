using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Classes.Api.Migrations
{
    // Publishes the teacher list as classes.v_teachers: search re-checks a teacher hit against it (an active teacher, status 'A'; PHP searchsource teacherRow and TeachersModel::canView).
    // Views only: no table changes. A view is a contract: add columns last, never remove one.
    /// <inheritdoc />
    [DbContext(typeof(ClassesContext))]
    [Migration("20261113100000_TeacherView")]
    public sealed class TeacherView : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view classes.v_teachers as
                select token, status
                from classes.teachers;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view classes.v_teachers;");
        }
    }
}
