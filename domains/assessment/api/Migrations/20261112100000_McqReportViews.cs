using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    // The MCQ adherence reports of classes list each standard MCQ of a class (PHP getClassMcqAdherence): v_standard_mcqs gains topic, subject, lesson, name and sort_order, appended after the existing columns
    // (the pending report keeps reading the first three). The columns keep their citext type. A view is a contract: classes reads it.
    /// <inheritdoc />
    [DbContext(typeof(AssessmentContext))]
    [Migration("20261112100000_McqReportViews")]
    public sealed class McqReportViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create or replace view assessment.v_standard_mcqs as
                select m.code, m.level_id, m.language_id, m.topic, m.subject, m.lesson, m.name, m.sort_order
                from assessment.standard_mcqs m
                where m.deleted_at is null;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view assessment.v_standard_mcqs;");
            migrationBuilder.Sql(
                """
                create view assessment.v_standard_mcqs as
                select m.code, m.level_id, m.language_id
                from assessment.standard_mcqs m
                where m.deleted_at is null;
                """);
        }
    }
}
