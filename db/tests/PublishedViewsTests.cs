using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>The views each domain publishes (domains/CLAUDE.md rule 2): all nine exist and the API's limited role can read them.</summary>
public sealed class PublishedViewsTests
{
    public static readonly string[] Views =
    [
        "identity.v_users", "membership.v_members", "membership.v_registrations", "membership.v_guardian_links",
        "classes.v_classes", "classes.v_enrolments", "classes.v_class_schedules", "classes.v_class_levels", "classes.v_teachers", "assessment.v_quiz_results", "assessment.v_quizzes", "assessment.v_standard_mcqs", "assessment.v_class_mcq_copies", "content.v_quran", "platform.v_genders",
    ];

    [TestCaseSource(nameof(Views))]
    public async Task The_api_role_can_read_a_published_view(string view)
    {
        var rows = await TestDatabase.ScalarAsync<long>("select count(*) from " + view, TestDatabase.AppConnection);

        Assert.That(rows, Is.GreaterThanOrEqualTo(0));
    }

    [Test]
    public async Task The_quiz_results_view_counts_the_members_responses_and_dates_the_first()
    {
        await TestDatabase.ExecuteAsync("""
            delete from assessment.spot_quiz_responses where spot_quiz_id = 9801;
            delete from assessment.spot_quiz_questions where spot_quiz_id = 9801;
            delete from assessment.spot_quizzes where id = 9801;
            insert into assessment.spot_quizzes (id, code, language_id, level_id, name, class_id, restrict_to_class, published_at, published_by, created_by, created_at)
            values (9801, 'VIEWQ9801', 1, 3, 'View quiz', 9801, 1, now(), 900301, 900301, now());
            insert into assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer)
            values (989801, 9801, false, 'q1', 'a', 'b', 1), (989802, 9801, false, 'q2', 'a', 'b', 1), (989803, 9801, false, 'q3', 'a', 'b', 1);
            insert into assessment.spot_quiz_responses (id, spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct, created_at)
            values (989801, 9801, 989801, 900311, 'a', 'a', 1, timestamptz '2025-09-07 10:00:00+00'),
                   (989802, 9801, 989802, 900311, 'b', 'a', 0, timestamptz '2025-09-07 10:05:00+00');
            """);

        var row = await TestDatabase.RowAsync(
            "select answered::text as answered, correct::text as correct, max_marks::text as max_marks, to_char(answered_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI') as answered_at " +
            "from assessment.v_quiz_results where quiz_id = 9801 and token = 900311");

        Assert.That(row, Is.Not.Null);
        Assert.That(row!["answered"], Is.EqualTo("2"), "two responses, though the quiz has three questions");
        Assert.That(row["correct"], Is.EqualTo("1"));
        Assert.That(row["max_marks"], Is.EqualTo("3"));
        Assert.That(row["answered_at"], Is.EqualTo("2025-09-07 10:00"), "the first response");
    }

    [TestCaseSource(nameof(Views))]
    public async Task The_api_role_cannot_write_through_a_published_view(string view)
    {
        foreach (var privilege in new[] { "insert", "update", "delete", "truncate", "references", "trigger" })
        {
            var held = await TestDatabase.ScalarAsync<bool>(
                $"select has_table_privilege(current_user, '{view}', '{privilege}')", TestDatabase.AppConnection);
            Assert.That(held, Is.False, privilege + " on " + view);
        }
    }
}
