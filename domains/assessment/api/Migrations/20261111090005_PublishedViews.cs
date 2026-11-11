using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    // The views this domain publishes to the others (domains/CLAUDE.md rule 2): a view is a contract; change one with its readers.
    /// <inheritdoc />
    [DbContext(typeof(AssessmentContext))]
    [Migration("20261111090005_PublishedViews")]
    public sealed class PublishedViews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create view assessment.v_quiz_results as
                select q.class_id, r.token, q.id as quiz_id, q.published_at,
                       sum(r.is_correct)::int as correct,
                       (select count(*) from assessment.spot_quiz_questions qq where qq.spot_quiz_id = q.id)::int as max_marks
                from assessment.spot_quizzes q
                join assessment.spot_quiz_responses r on r.spot_quiz_id = q.id
                group by q.class_id, r.token, q.id, q.published_at;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view assessment.v_quiz_results;");
        }
    }
}
