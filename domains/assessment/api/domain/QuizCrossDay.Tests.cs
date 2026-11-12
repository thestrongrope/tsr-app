using System.Diagnostics;
using System.Globalization;
using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// Finding 8: the winners feasibility check (PHP's Hall check over every subset of started days) must not cost 2^n. The verdict and the reason text stay PHP's.
/// The reference below is the subset search as it was (models/quizadmin.php:1443-1491).
/// </summary>
[TestFixture]
internal sealed class QuizCrossDayTests
{
    private static QuizSettings Settings(int total, string counts) =>
        QuizSettings.FromSheets(
            [["total_quizzes", total.ToString(CultureInfo.InvariantCulture)], ["daily_winner_counts", counts], ["min_score_percent", "50"], ["mode", "live"], ["quiz_type", "MEGA"]],
            []);

    private static (IReadOnlyDictionary<int, List<Submission>> Days, IReadOnlyDictionary<int, Member> Users) Data(List<int[]> candidatesPerDay)
    {
        var days = new Dictionary<int, List<Submission>>();
        var users = new Dictionary<int, Member>();
        for (var i = 0; i < candidatesPerDay.Count; i++)
        {
            days[i + 1] = candidatesPerDay[i].Select(t => new Submission(t.ToString(CultureInfo.InvariantCulture), "9 / 10")).ToList();
            foreach (var token in candidatesPerDay[i])
            {
                users[token] = new Member("member " + token, "mumbai", "india");
            }
        }

        return (days, users);
    }

    /// <summary>The subset search of PHP, over the started days, as (feasible, reason).</summary>
    private static (bool Feasible, string Reason) Reference(Feasibility f)
    {
        var started = Enumerable.Range(1, f.TotalQuizzes).Where(d => f.ByDay[d].Funnel.Submissions > 0).ToList();
        for (var mask = 1; mask < 1 << started.Count; mask++)
        {
            var subset = started.Where((_, i) => (mask & (1 << i)) != 0).ToList();
            var union = subset.SelectMany(d => f.ByDay[d].Candidates).ToHashSet();
            var demand = subset.Sum(d => f.ByDay[d].Needed);
            if (union.Count < demand)
            {
                return (false, $"Days {string.Join(", ", subset)} collectively need {demand} winners but only {union.Count} unique candidates exist across these days at min_score_percent={f.MinScorePercent}."
                    + " Within-cycle uniqueness will prevent winner generation from completing. To relax, update min_score_percent in the Technical sheet and re-run.");
            }
        }

        return (true, string.Empty);
    }

    [Test]
    public void Twenty_started_episodes_that_can_all_be_drawn_are_checked_in_well_under_a_second()
    {
        var pools = Enumerable.Range(0, 20).Select(d => new[] { 1000 + d, 1000 + ((d + 1) % 20), 2000 + d }).ToList();
        var (days, users) = Data(pools);
        var watch = Stopwatch.StartNew();

        var f = QuizEligibility.Compute(days, users, Settings(20, "1"));

        watch.Stop();
        Assert.That(f.CrossDayFeasible, Is.True);
        Assert.That(watch.Elapsed, Is.LessThan(TimeSpan.FromSeconds(2)));
    }

    [Test]
    public void The_most_episodes_a_quiz_may_have_are_checked_and_a_shortage_names_days_that_cannot_all_be_served()
    {
        var shared = new[] { 1, 2, 3 };
        var (days, users) = Data(Enumerable.Range(0, QuizSettings.MaxEpisodes).Select(_ => shared).ToList());
        var watch = Stopwatch.StartNew();

        var f = QuizEligibility.Compute(days, users, Settings(QuizSettings.MaxEpisodes, "1"));

        watch.Stop();
        Assert.That(f.CrossDayFeasible, Is.False);
        Assert.That(f.CrossDayReason, Does.StartWith("Days "));
        Assert.That(f.CrossDayReason, Does.Contain("collectively need 4 winners but only 3 unique candidates exist"));
        Assert.That(watch.Elapsed, Is.LessThan(TimeSpan.FromSeconds(2)));
    }

    [Test]
    public void More_than_twenty_started_episodes_with_enough_candidates_are_feasible()
    {
        var (days, users) = Data(Enumerable.Range(0, 25).Select(d => new[] { 500 + d }).ToList());

        var f = QuizEligibility.Compute(days, users, Settings(25, "1"));

        Assert.That(f.CrossDayFeasible, Is.True);
        Assert.That(f.CrossDayReason, Is.Empty);
    }

    [Test]
    public void Verdict_and_reason_equal_the_subset_search_on_many_random_quizzes()
    {
        var random = new Random(20261112);
        for (var round = 0; round < 400; round++)
        {
            var total = random.Next(1, 9);
            var pool = random.Next(1, 9);
            var pools = Enumerable.Range(0, total).Select(_ => Enumerable.Range(0, random.Next(0, pool + 1)).Select(_ => 100 + random.Next(pool)).Distinct().ToArray()).ToList();
            var counts = string.Join(",", Enumerable.Range(0, random.Next(1, 4)).Select(_ => random.Next(0, 3)));
            var (days, users) = Data(pools);

            var f = QuizEligibility.Compute(days, users, Settings(total, counts));

            var expected = Reference(f);
            Assert.That((f.CrossDayFeasible, f.CrossDayReason), Is.EqualTo(expected), $"round {round}: pools {string.Join(" | ", pools.Select(p => string.Join(",", p)))} counts {counts}");
        }
    }
}
