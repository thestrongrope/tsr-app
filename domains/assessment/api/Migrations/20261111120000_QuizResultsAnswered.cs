using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    // Adds `answered` (how many questions the member answered) and `answered_at` (when they first answered the quiz) to the published view
    // assessment.v_quiz_results: classes' performance reads divide by the first, as PHP does (getStudentQuizSummary: correct * 100 / count of the
    // member's responses), and bound the quiz by the second (PHP bounds each response by its own time; a member answers a quiz in one sitting).
    // A view is a contract: the new columns are last, the others are unchanged.
    /// <inheritdoc />
    [DbContext(typeof(AssessmentContext))]
    [Migration("20261111120000_QuizResultsAnswered")]
    public sealed class QuizResultsAnswered : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                create or replace view assessment.v_quiz_results as
                select q.class_id, r.token, q.id as quiz_id, q.published_at,
                       sum(r.is_correct)::int as correct,
                       (select count(*) from assessment.spot_quiz_questions qq where qq.spot_quiz_id = q.id)::int as max_marks,
                       count(*)::int as answered,
                       min(r.created_at) as answered_at
                from assessment.spot_quizzes q
                join assessment.spot_quiz_responses r on r.spot_quiz_id = q.id
                group by q.class_id, r.token, q.id, q.published_at;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                drop view assessment.v_quiz_results;
                create view assessment.v_quiz_results as
                select q.class_id, r.token, q.id as quiz_id, q.published_at,
                       sum(r.is_correct)::int as correct,
                       (select count(*) from assessment.spot_quiz_questions qq where qq.spot_quiz_id = q.id)::int as max_marks
                from assessment.spot_quizzes q
                join assessment.spot_quiz_responses r on r.spot_quiz_id = q.id
                group by q.class_id, r.token, q.id, q.published_at;
                """);
        }
    }
}
