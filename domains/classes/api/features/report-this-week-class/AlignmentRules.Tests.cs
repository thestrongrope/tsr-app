using NUnit.Framework;

namespace Tsr.Classes.Api.Features.ReportThisWeekClass;

[TestFixture]
internal sealed class AlignmentRulesTests
{
    private static DateOnly D(string text) => DateOnly.ParseExact(text, "yyyy-MM-dd");

    private static readonly AlignmentRules.Week[] Weeks = [new(D("2025-11-02"), D("2025-11-08")), new(D("2025-11-09"), D("2025-11-15")), new(D("2025-11-16"), D("2025-11-22"))];

    private static AlignmentRules.Session S(string day, bool held, params (string Subject, string Topic)[] topics) =>
        new(D(day), held, topics.ToDictionary(t => t.Subject, t => t.Topic));

    [Test]
    public void A_week_is_taught_when_a_session_was_held_no_class_when_only_forms_of_nothing_held_and_no_form_otherwise_newest_week_first()
    {
        var items = AlignmentRules.Build([S("2025-11-10", true), S("2025-11-17", false)], Weeks);
        Assert.That(items.Select(i => i.Status).ToArray(), Is.EqualTo((string[])["no class", "taught", "no form"]));
        Assert.That(items[0].From, Is.EqualTo("2025-11-16"));
        Assert.That(items[0].To, Is.EqualTo("2025-11-22"));
        Assert.That(items[2].From, Is.EqualTo("2025-11-02"));
    }

    [Test]
    public void A_held_session_beats_a_session_not_held_in_the_same_week_whichever_comes_first()
    {
        Assert.That(AlignmentRules.Build([S("2025-11-10", false), S("2025-11-11", true)], Weeks)[1].Status, Is.EqualTo("taught"));
        Assert.That(AlignmentRules.Build([S("2025-11-10", true), S("2025-11-11", false)], Weeks)[1].Status, Is.EqualTo("taught"));
    }

    [Test]
    public void Topics_of_held_sessions_are_joined_with_a_semicolon_in_order_and_the_days_at_the_edges_belong_to_their_week()
    {
        var items = AlignmentRules.Build(
            [S("2025-11-09", true, ("arabic", "Alif")), S("2025-11-15", true, ("arabic", "Ba"), ("aqaed", "Tawhid")), S("2025-11-16", true, ("arabic", "Ta"))], Weeks);
        Assert.That(items[1].Subjects["arabic"], Is.EqualTo("Alif; Ba"));
        Assert.That(items[1].Subjects["aqaed"], Is.EqualTo("Tawhid"));
        Assert.That(items[0].Subjects["arabic"], Is.EqualTo("Ta"));
        Assert.That(items[2].Subjects, Is.Empty);
    }

    [Test]
    public void Sessions_outside_every_week_and_sessions_not_held_add_no_topics()
    {
        var items = AlignmentRules.Build([S("2025-10-01", true, ("arabic", "Old")), S("2025-11-10", false, ("arabic", "Never"))], Weeks);
        Assert.That(items.All(i => i.Subjects.Count == 0), Is.True);
        Assert.That(items[1].Status, Is.EqualTo("no class"));
    }
}
