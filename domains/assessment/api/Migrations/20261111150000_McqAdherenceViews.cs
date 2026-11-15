using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    // The pending report of classes (PHP getClassMcqAdherence) compares the standard MCQs of a class's level and language with the quizzes the class's teacher copied from them.
    // v_standard_mcqs lists the standard MCQs not deleted; v_class_mcq_copies collapses the copies of one standard MCQ in one class to a single row (the latest quiz and publish time), deactivated copies left out.
    // Both are new views; the text column keeps its citext type so a code compares case-insensitively, as MariaDB's did. A view is a contract: classes reads them.
    /// <inheritdoc />
    [DbContext(typeof(AssessmentContext))]
    [Migration("20261111150000_McqAdherenceViews")]
    public sealed class McqAdherenceViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view assessment.v_standard_mcqs as
                select m.code, m.level_id, m.language_id
                from assessment.standard_mcqs m
                where m.deleted_at is null;
                """);
            migrationBuilder.Sql(
                """
                create view assessment.v_class_mcq_copies as
                select q.class_id, q.mcq_code, max(q.id) as quiz_id, max(q.published_at) as published_at
                from assessment.spot_quizzes q
                where q.deactivated_at is null and q.mcq_code is not null and q.class_id is not null
                group by q.class_id, q.mcq_code;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view assessment.v_class_mcq_copies;");
            migrationBuilder.Sql("drop view assessment.v_standard_mcqs;");
        }
    }
}
