using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>The views each domain publishes (domains/CLAUDE.md rule 2): all nine exist and the API's limited role can read them.</summary>
public sealed class PublishedViewsTests
{
    public static readonly string[] Views =
    [
        "identity.v_users", "membership.v_members", "membership.v_registrations", "membership.v_guardian_links",
        "classes.v_classes", "classes.v_enrolments", "assessment.v_quiz_results", "content.v_quran", "platform.v_genders",
    ];

    [TestCaseSource(nameof(Views))]
    public async Task The_api_role_can_read_a_published_view(string view)
    {
        var rows = await TestDatabase.ScalarAsync<long>("select count(*) from " + view, TestDatabase.AppConnection);

        Assert.That(rows, Is.GreaterThanOrEqualTo(0));
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
