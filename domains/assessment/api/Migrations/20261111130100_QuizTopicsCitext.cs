using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    // QuizTopics cast the topic to text; every text column of the schema is citext (db/tests SchemaGuardTests), so the views carry the column's own type.
    /// <inheritdoc />
    [DbContext(typeof(AssessmentContext))]
    [Migration("20261111130100_QuizTopicsCitext")]
    public sealed class QuizTopicsCitext : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
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
                       min(r.created_at) as answered_at,
                       q.topic as topic
                from assessment.spot_quizzes q
                join assessment.spot_quiz_responses r on r.spot_quiz_id = q.id
                group by q.class_id, r.token, q.id, q.published_at, q.topic;
                """);
            migrationBuilder.Sql(
                """
                create view assessment.v_quizzes as
                select q.id as quiz_id, q.class_id, q.topic as topic, q.published_at,
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
    }
}
