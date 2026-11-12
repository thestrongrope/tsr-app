using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Tsr.Assessment.Api.Migrations
{
    /// <inheritdoc />
    public partial class QuizState : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "assessment");

            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:citext", ",,");

            migrationBuilder.CreateTable(
                name: "quiz_campaigns",
                schema: "assessment",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    year = table.Column<int>(type: "integer", nullable: true),
                    registrations_start = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    registrations_end = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    quiz_start = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    quiz_disabled = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    quiz_end = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    outof = table.Column<int>(type: "integer", nullable: true),
                    active = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_quiz_campaigns", x => x.id);
                    table.CheckConstraint("ck_quiz_campaigns_name_length", "char_length(\"name\") <= 300");
                });

            migrationBuilder.CreateTable(
                name: "quiz_state",
                schema: "assessment",
                columns: table => new
                {
                    name = table.Column<string>(type: "citext", maxLength: 50, nullable: false),
                    document = table.Column<string>(type: "jsonb", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_quiz_state", x => x.name);
                    table.CheckConstraint("ck_quiz_state_name_length", "char_length(\"name\") <= 50");
                });

            migrationBuilder.CreateTable(
                name: "spot_quiz_questions",
                schema: "assessment",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    spot_quiz_id = table.Column<int>(type: "integer", nullable: true),
                    is_arabic = table.Column<bool>(type: "boolean", nullable: true),
                    question = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    option1 = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    option2 = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    option3 = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    option4 = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    option5 = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    answer = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    option_display_order = table.Column<string>(type: "citext", maxLength: 50, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_spot_quiz_questions", x => x.id);
                    table.CheckConstraint("ck_spot_quiz_questions_option_display_order_length", "char_length(\"option_display_order\") <= 50");
                    table.CheckConstraint("ck_spot_quiz_questions_option1_length", "char_length(\"option1\") <= 1000");
                    table.CheckConstraint("ck_spot_quiz_questions_option2_length", "char_length(\"option2\") <= 1000");
                    table.CheckConstraint("ck_spot_quiz_questions_option3_length", "char_length(\"option3\") <= 1000");
                    table.CheckConstraint("ck_spot_quiz_questions_option4_length", "char_length(\"option4\") <= 1000");
                    table.CheckConstraint("ck_spot_quiz_questions_option5_length", "char_length(\"option5\") <= 1000");
                    table.CheckConstraint("ck_spot_quiz_questions_question_length", "char_length(\"question\") <= 1000");
                });

            migrationBuilder.CreateTable(
                name: "spot_quiz_responses",
                schema: "assessment",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    spot_quiz_id = table.Column<int>(type: "integer", nullable: true),
                    spot_quiz_question_id = table.Column<int>(type: "integer", nullable: false),
                    token = table.Column<int>(type: "integer", nullable: true),
                    response = table.Column<string>(type: "citext", maxLength: 1000, nullable: true),
                    correct_response = table.Column<string>(type: "citext", maxLength: 1000, nullable: false),
                    is_correct = table.Column<short>(type: "smallint", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_spot_quiz_responses", x => x.id);
                    table.CheckConstraint("ck_spot_quiz_responses_correct_response_length", "char_length(\"correct_response\") <= 1000");
                    table.CheckConstraint("ck_spot_quiz_responses_response_length", "char_length(\"response\") <= 1000");
                });

            migrationBuilder.CreateTable(
                name: "spot_quiz_submissions",
                schema: "assessment",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    spot_quiz_id = table.Column<int>(type: "integer", nullable: true),
                    token = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    modified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_spot_quiz_submissions", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "spot_quizzes",
                schema: "assessment",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    code = table.Column<string>(type: "citext", maxLength: 100, nullable: true),
                    mcq_code = table.Column<string>(type: "citext", maxLength: 200, nullable: true),
                    language_id = table.Column<int>(type: "integer", nullable: true),
                    level_id = table.Column<int>(type: "integer", nullable: true),
                    topic_id = table.Column<int>(type: "integer", nullable: true),
                    subject_id = table.Column<int>(type: "integer", nullable: true),
                    lesson_id = table.Column<int>(type: "integer", nullable: true),
                    name = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    class_id = table.Column<int>(type: "integer", nullable: true),
                    topic = table.Column<string>(type: "citext", maxLength: 300, nullable: true),
                    session = table.Column<int>(type: "integer", nullable: true),
                    restrict_to_class = table.Column<short>(type: "smallint", nullable: false, defaultValue: (short)1),
                    published_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    published_by = table.Column<int>(type: "integer", nullable: true),
                    deactivated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deactivated_by = table.Column<int>(type: "integer", nullable: true),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    modified_by = table.Column<int>(type: "integer", nullable: true),
                    modified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_spot_quizzes", x => x.id);
                    table.CheckConstraint("ck_spot_quizzes_code_length", "char_length(\"code\") <= 100");
                    table.CheckConstraint("ck_spot_quizzes_mcq_code_length", "char_length(\"mcq_code\") <= 200");
                    table.CheckConstraint("ck_spot_quizzes_name_length", "char_length(\"name\") <= 300");
                    table.CheckConstraint("ck_spot_quizzes_topic_length", "char_length(\"topic\") <= 300");
                });

            migrationBuilder.CreateTable(
                name: "standard_mcq_questions",
                schema: "assessment",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    mcq_code = table.Column<string>(type: "citext", maxLength: 200, nullable: false),
                    question = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    answer = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    option1 = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    option2 = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    option3 = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    reason_option1 = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    reason_option2 = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    reason_option3 = table.Column<string>(type: "citext", maxLength: 500, nullable: true),
                    sort_order = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    modified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_standard_mcq_questions", x => x.id);
                    table.CheckConstraint("ck_standard_mcq_questions_answer_length", "char_length(\"answer\") <= 500");
                    table.CheckConstraint("ck_standard_mcq_questions_mcq_code_length", "char_length(\"mcq_code\") <= 200");
                    table.CheckConstraint("ck_standard_mcq_questions_option1_length", "char_length(\"option1\") <= 500");
                    table.CheckConstraint("ck_standard_mcq_questions_option2_length", "char_length(\"option2\") <= 500");
                    table.CheckConstraint("ck_standard_mcq_questions_option3_length", "char_length(\"option3\") <= 500");
                    table.CheckConstraint("ck_standard_mcq_questions_question_length", "char_length(\"question\") <= 500");
                    table.CheckConstraint("ck_standard_mcq_questions_reason_option1_length", "char_length(\"reason_option1\") <= 500");
                    table.CheckConstraint("ck_standard_mcq_questions_reason_option2_length", "char_length(\"reason_option2\") <= 500");
                    table.CheckConstraint("ck_standard_mcq_questions_reason_option3_length", "char_length(\"reason_option3\") <= 500");
                });

            migrationBuilder.CreateTable(
                name: "standard_mcqs",
                schema: "assessment",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    code = table.Column<string>(type: "citext", maxLength: 200, nullable: false),
                    language_id = table.Column<int>(type: "integer", nullable: false),
                    level_id = table.Column<int>(type: "integer", nullable: false),
                    topic = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    subject = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    lesson = table.Column<string>(type: "citext", maxLength: 500, nullable: false),
                    name = table.Column<string>(type: "citext", maxLength: 100, nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false, defaultValueSql: "now()"),
                    created_by = table.Column<int>(type: "integer", nullable: true),
                    modified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<int>(type: "integer", nullable: true),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    deleted_by = table.Column<int>(type: "integer", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_standard_mcqs", x => x.id);
                    table.CheckConstraint("ck_standard_mcqs_code_length", "char_length(\"code\") <= 200");
                    table.CheckConstraint("ck_standard_mcqs_lesson_length", "char_length(\"lesson\") <= 500");
                    table.CheckConstraint("ck_standard_mcqs_name_length", "char_length(\"name\") <= 100");
                    table.CheckConstraint("ck_standard_mcqs_subject_length", "char_length(\"subject\") <= 500");
                    table.CheckConstraint("ck_standard_mcqs_topic_length", "char_length(\"topic\") <= 500");
                });

            migrationBuilder.CreateIndex(
                name: "idx_sqq_quiz",
                schema: "assessment",
                table: "spot_quiz_questions",
                column: "spot_quiz_id");

            migrationBuilder.CreateIndex(
                name: "idx_sqr_quiz_token",
                schema: "assessment",
                table: "spot_quiz_responses",
                columns: new[] { "spot_quiz_id", "token" });

            migrationBuilder.CreateIndex(
                name: "idx_sqr_token",
                schema: "assessment",
                table: "spot_quiz_responses",
                column: "token");

            migrationBuilder.CreateIndex(
                name: "spot_quiz_responses_question_token",
                schema: "assessment",
                table: "spot_quiz_responses",
                columns: new[] { "spot_quiz_question_id", "token" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "idx_sq_class_published",
                schema: "assessment",
                table: "spot_quizzes",
                columns: new[] { "class_id", "published_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "quiz_campaigns",
                schema: "assessment");

            migrationBuilder.DropTable(
                name: "quiz_state",
                schema: "assessment");

            migrationBuilder.DropTable(
                name: "spot_quiz_questions",
                schema: "assessment");

            migrationBuilder.DropTable(
                name: "spot_quiz_responses",
                schema: "assessment");

            migrationBuilder.DropTable(
                name: "spot_quiz_submissions",
                schema: "assessment");

            migrationBuilder.DropTable(
                name: "spot_quizzes",
                schema: "assessment");

            migrationBuilder.DropTable(
                name: "standard_mcq_questions",
                schema: "assessment");

            migrationBuilder.DropTable(
                name: "standard_mcqs",
                schema: "assessment");

            migrationBuilder.AlterDatabase()
                .OldAnnotation("Npgsql:PostgresExtension:citext", ",,");
        }
    }
}
