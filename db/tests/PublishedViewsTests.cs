using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>The views each domain publishes (domains/CLAUDE.md rule 2): all nine exist and the API's limited role can read them.</summary>
public sealed class PublishedViewsTests
{
    public static readonly string[] Views =
    [
        "identity.v_users", "membership.v_members", "membership.v_registrations", "membership.v_guardian_links",
        "classes.v_classes", "classes.v_enrolments", "classes.v_class_schedules", "classes.v_class_levels", "classes.v_teachers", "classes.v_guides","assessment.v_quiz_results", "assessment.v_quizzes", "assessment.v_standard_mcqs", "assessment.v_class_mcq_copies", "content.v_quran", "content.v_published_articles", "platform.v_genders",
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

    [Test]
    public async Task The_guide_re_check_counts_only_a_non_blank_language_one_guide_of_a_level_with_a_page()
    {
        await TestDatabase.ExecuteAsync("""
            delete from classes.guides where level_id in (2, 3, 4, 6);
            insert into classes.class_levels (id, code, name, sort_order) values (2, 'AZ', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3), (4, 'AM', 'AMMAR', 4), (6, 'NP', 'NOPAGE', 6)
                on conflict (id) do update set name = excluded.name;
            insert into classes.guides (level_id, language_id, guide, created_by)
            values (2, 1, 'A real guide', 1), (3, 1, '   ', 1), (4, 2, 'Only another language', 1), (6, 1, 'No public page', 1);
            """);
        var facts = new Tsr.Search.Api.Domain.SearchFacts(new Tsr.Shared.Api.DbSettings(TestDatabase.AppConnection));

        var levels = await facts.GuideLevelsAsync([2, 3, 4, 6, 99], CancellationToken.None);

        Assert.That(levels, Is.EqualTo(new Dictionary<long, string> { [2] = "ABUZAR" }));
    }

    [Test]
    public async Task The_published_articles_view_holds_each_article_with_its_markdown_body_and_no_html()
    {
        await TestDatabase.ExecuteAsync("""
            delete from content.published_articles where slug in ('view-article-a', 'view-article-b');
            insert into content.published_articles
                (slug, slug_decoded, legacy_id, title, excerpt, body_markdown, body_html, published_at, published_date_text, modified_at, modified_date_text, author, language, reading_minutes, categories, tags)
            values
                ('view-article-a', 'view-article-a', 7, 'View A', 'Excerpt A', '# Body A', '<h1>Body A</h1>', timestamptz '2026-01-02 00:00:00+00', '2026-01-02', null, null, 'Author A', 'en', 3, array['cat-one'], array['tag-one', 'tag-two']),
                ('view-article-b', 'view-article-b', null, 'View B', null, 'Body B', '<p>Body B</p>', timestamptz '2026-01-01 00:00:00+00', '2026-01-01', timestamptz '2026-01-03 00:00:00+00', '2026-01-03', 'Author B', 'en', 1, array[]::text[], array[]::text[]);
            """);

        var row = await TestDatabase.RowAsync(
            "select slug, title, excerpt, body_markdown, published_date_text, modified_date_text, author, language, reading_minutes::text as reading_minutes, legacy_id::text as legacy_id, " +
            "array_to_string(categories, ',') as categories, array_to_string(tags, ',') as tags from content.v_published_articles where slug = 'view-article-a'");
        var columns = await TestDatabase.ScalarAsync<string>(
            "select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns where table_schema = 'content' and table_name = 'v_published_articles'",
            TestDatabase.AppConnection);

        Assert.That(row, Is.Not.Null);
        Assert.That(row!["title"], Is.EqualTo("View A"));
        Assert.That(row["excerpt"], Is.EqualTo("Excerpt A"));
        Assert.That(row["body_markdown"], Is.EqualTo("# Body A"));
        Assert.That(row["author"], Is.EqualTo("Author A"));
        Assert.That(row["reading_minutes"], Is.EqualTo("3"));
        Assert.That(row["legacy_id"], Is.EqualTo("7"));
        Assert.That(row["categories"], Is.EqualTo("cat-one"));
        Assert.That(row["tags"], Is.EqualTo("tag-one,tag-two"));
        Assert.That(columns, Does.Not.Contain("body_html"));
        Assert.That(columns, Does.Contain("published_at"));
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
