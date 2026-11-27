using System.Text.Json.Nodes;
using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

/// <summary>Unit tests of the quiz competition rules that branch: settings from the sheets, eligibility, the scoreboard, the draw (random source fixed) and the announcement.</summary>
[TestFixture]
internal sealed class QuizCompetitionTests
{
    private sealed class FirstPick : IQuizRandom
    {
        public int Next(int maxExclusive) => 0;
    }

    private static QuizSettings Settings(string total = "2", string counts = "1,1", string extra = "") =>
        QuizSettings.FromSheets(
            [["total_quizzes", total], ["daily_winner_counts", counts], ["min_score_percent", "50"], ["mode", "live"], ["quiz_type", "MEGA"], .. Extra(extra)],
            []);

    private static List<IReadOnlyList<string>> Extra(string extra) =>
        extra.Length == 0 ? [] : extra.Split(';').Select(pair => (IReadOnlyList<string>)pair.Split('=')).ToList();

    private static Dictionary<int, Member> Users(params int[] tokens) =>
        tokens.ToDictionary(t => t, t => new Member("member " + t, "mumbai", "india"));

    private static Dictionary<int, List<Submission>> Days(List<Submission> one, List<Submission> two) =>
        new() { [1] = one, [2] = two };

    [Test]
    public void Technical_rows_are_key_value_or_key_and_list_and_functional_tables_nest_under_the_first_header()
    {
        var settings = QuizSettings.FromSheets(
            [["total_quizzes", "2"], ["excluded", "a", "b", "c"]],
            [["episodes", "start", "stop"], ["1", "10 Nov", "11 Nov"], ["2", "12 Nov", "13 Nov"], ["quiz_title", "Grand"]]);

        Assert.That(settings.TotalQuizzes, Is.EqualTo(2));
        Assert.That(settings.Values["excluded"], Is.InstanceOf<JsonArray>());
        Assert.That(settings.Values["episodes"]!["2"]!["start"]!.GetValue<string>(), Is.EqualTo("12 Nov"));
        Assert.That(settings.Str("quiz_title"), Is.EqualTo("Grand"));
    }

    [TestCase("8 / 10", 80, true)]
    [TestCase("7 / 10", 80, false)]
    [TestCase("", 50, false)]
    [TestCase("5/10", 50, false)]
    [TestCase("1 / 0", 0, false)]
    public void A_score_passes_when_its_percentage_reaches_the_minimum(string score, int minimum, bool expected) =>
        Assert.That(QuizEligibility.ScorePasses(score, minimum), Is.EqualTo(expected));

    [Test]
    public void The_funnel_keeps_the_first_submission_per_token_members_allowed_countries_and_passing_scores()
    {
        var settings = Settings(extra: "excluded_countries=Pakistan;excluded_tokens=4");
        var users = Users(1, 2, 3, 4);
        users[3] = new Member("x", "y", "Pakistan");
        var day = new List<Submission> { new("1", "9 / 10"), new("1", "0 / 10"), new("2", "4 / 10"), new("3", "9 / 10"), new("4", "9 / 10"), new("99", "9 / 10") };

        var result = QuizEligibility.Compute(Days(day, []), users, settings).ByDay[1];

        Assert.That(result.Funnel, Is.EqualTo(new Funnel(6, 5, 4, 3, 2, 1)));
        Assert.That(result.Candidates, Is.EqualTo(new List<int> { 1 }));
        Assert.That(result.Feasible, Is.False);
        Assert.That(result.Reason, Does.StartWith("Day 1 has 1 candidate at min_score_percent=50; need 2 winners."));
    }

    [Test]
    public void The_cross_day_check_fails_when_two_days_share_their_only_candidate()
    {
        var settings = Settings(counts: "1");
        var same = new List<Submission> { new("1", "9 / 10") };

        var f = QuizEligibility.Compute(Days(same, same), Users(1), settings);

        Assert.That(f.ByDay[1].Feasible, Is.True);
        Assert.That(f.CrossDayFeasible, Is.False);
        Assert.That(f.CrossDayReason, Does.StartWith("Days 1, 2 collectively need 2 winners but only 1 unique candidates exist"));
    }

    [Test]
    public void The_scoreboard_lists_members_in_token_order_with_their_city_normalised()
    {
        var settings = Settings(counts: "0");
        var users = Users(7, 3);
        var f = QuizEligibility.Compute(Days([new("7", "1 / 2"), new("3", "2 / 2")], [new("3", "1 / 2")]), users, settings);

        var rows = QuizEligibility.BuildScoreboard(f);

        Assert.That(rows.Select(r => r![1]!.GetValue<int>()), Is.EqualTo(new List<int> { 3, 7 }));
        Assert.That(rows[0]!.AsArray().Select(c => c!.ToJsonString()), Is.EqualTo(new List<string> { "1", "3", "\"Member 3\"", "\"Mumbai, India\"", "\"2 / 2\"", "\"1 / 2\"" }));
    }

    [TestCase("Bangalore", "India", "Bengaluru, India")]
    [TestCase("Dubai", "Uae", "Dubai, UAE")]
    [TestCase("Pune", "Pune", "Pune, India")]
    public void A_city_and_country_are_mapped_to_one_display_form(string city, string country, string expected) =>
        Assert.That(QuizEligibility.NormalizeCityAndCountry(city, country), Is.EqualTo(expected));

    [Test]
    public void A_missing_city_gives_no_display_form() =>
        Assert.That(QuizEligibility.NormalizeCityAndCountry(string.Empty, "India"), Is.Null);

    [Test]
    public void A_draw_never_picks_the_same_member_twice_and_reports_the_shortfall()
    {
        var settings = Settings(total: "1", counts: "1,1");
        var f = QuizEligibility.Compute(new Dictionary<int, List<Submission>> { [1] = [new("1", "9 / 10"), new("2", "9 / 10")] }, Users(1, 2), settings);

        var result = QuizDraw.Episodes([1, 2], f, [], 1, new Dictionary<int, ParticipantInfo>(), reset: false, grand: false, new FirstPick());

        Assert.That(result.Report.Outcome, Is.EqualTo("incomplete"));
        Assert.That((result.Report.Drawn, result.Report.Missing), Is.EqualTo((2, 1)));
        Assert.That(QuizDraw.WinningTokens(result.Winners), Is.EquivalentTo(new List<int> { 1, 2 }));
        Assert.That(result.Report.Changed, Is.True);
    }

    [Test]
    public void A_regenerate_archives_the_replaced_winners_and_a_blocked_one_changes_nothing()
    {
        var settings = Settings(total: "1", counts: "1");
        var f = QuizEligibility.Compute(new Dictionary<int, List<Submission>> { [1] = [new("1", "9 / 10"), new("2", "9 / 10")] }, Users(1, 2), settings);
        var winners = new JsonObject { ["1"] = new JsonArray(new JsonObject { ["episode"] = 1, ["prize"] = 1, ["token"] = 2 }) };

        var again = QuizDraw.Episodes([1], f, winners, 1, new Dictionary<int, ParticipantInfo>(), reset: true, grand: false, new FirstPick());
        var none = QuizDraw.Episodes([1], f, winners, 0, new Dictionary<int, ParticipantInfo>(), reset: true, grand: false, new FirstPick());

        Assert.That(again.Replaced.Single().Kind, Is.EqualTo("daily"));
        Assert.That(again.Winners["1"]![0]!["token"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(none.Report.Outcome, Is.EqualTo("blocked"));
        Assert.That(none.Winners, Is.SameAs(winners));
    }

    [Test]
    public void Only_the_switch_from_not_live_to_live_announces()
    {
        var live = QuizSettings.FromSheets(
            [["mode", "live"], ["quiz_title", "T"], ["quiz_type", "MEGA"], ["quiz_registration", "1 Nov"], ["quiz_series", "S"]],
            [["episodes", "start", "stop"], ["1", "5 Nov", "6 Nov"]]);

        var fromUat = QuizSettingsRefresh.AnnouncementFor(new JsonObject { ["mode"] = "UAT" }, live);

        Assert.That(fromUat!.Body, Is.EqualTo("Mega Quiz: registration opens 1 Nov, starts 5 Nov."));
        Assert.That(fromUat.DedupeKey, Is.EqualTo("quiz-announce:S:T:5 Nov"));
        Assert.That(QuizSettingsRefresh.AnnouncementFor(new JsonObject { ["mode"] = "live" }, live), Is.Null);
        Assert.That(QuizSettingsRefresh.AnnouncementFor(null, live), Is.Null);
        Assert.That(QuizSettingsRefresh.AnnouncementFor(new JsonObject(), live), Is.Null);
    }
}
