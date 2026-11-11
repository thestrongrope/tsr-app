using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    // The class student figures (classes: GET /classes/{id}/students/performance) group quizzes by topic and need the quizzes nobody answered yet:
    // v_quiz_results gains topic (last, the others unchanged) and v_quizzes lists every quiz of a class with its question count. A view is a contract.
    /// <inheritdoc />
    [DbContext(typeof(AssessmentContext))]
    [Migration("20261111130000_QuizTopics")]
    public sealed class QuizTopics : Migration
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
                       min(r.created_at) as answered_at,
                       q.topic::text as topic
                from assessment.spot_quizzes q
                join assessment.spot_quiz_responses r on r.spot_quiz_id = q.id
                group by q.class_id, r.token, q.id, q.published_at, q.topic;
                """);
            migrationBuilder.Sql(
                """
                create view assessment.v_quizzes as
                select q.id as quiz_id, q.class_id, q.topic::text as topic, q.published_at,
                       (select count(*) from assessment.spot_quiz_questions qq where qq.spot_quiz_id = q.id)::int as max_marks
                from assessment.spot_quizzes q;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("drop view assessment.v_quizzes;");
            migrationBuilder.Sql("drop view assessment.v_quiz_results;");
            migrationBuilder.Sql(
                """
                create view assessment.v_quiz_results as
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
    }
}
