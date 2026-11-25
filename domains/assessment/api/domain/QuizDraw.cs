using System.Security.Cryptography;
using System.Text.Json.Nodes;

namespace Tsr.Assessment.Api.Domain;

/// <summary>The one source of randomness of the winners draw: a seam so a test can fix it. <c>Next(n)</c> is a number from 0 to n - 1.</summary>
internal interface IQuizRandom
{
    int Next(int maxExclusive);
}

/// <summary>PHP random_int: a cryptographically secure draw.</summary>
internal sealed class CryptoQuizRandom : IQuizRandom
{
    public int Next(int maxExclusive) => RandomNumberGenerator.GetInt32(maxExclusive);
}

/// <summary>One prize of one episode in a draw report (Mega draws: no episode, prize 0).</summary>
internal sealed record DrawCell(int? Episode, int Prize, int Drawn, int Missing);

/// <summary>PHP drawReport (models/quizadmin.php:1766): outcome complete, incomplete or blocked, with a one sentence message that names no member.</summary>
internal sealed record DrawReport(string Outcome, string Message, int Drawn, int Missing, bool Changed, string? Blocked, IReadOnlyList<DrawCell> Cells);

/// <summary>A winner set a draw replaced, kept in the replaced-winners record.</summary>
internal sealed record ReplacedWinners(string Kind, JsonNode Episode, JsonNode Winners);

/// <summary>The outcome of a draw: the report, the winners document to save (the original when nothing was drawn) and what it replaced.</summary>
internal sealed record DrawResult(DrawReport Report, JsonObject Winners, IReadOnlyList<ReplacedWinners> Replaced);

/// <summary>Who is known about a scoreboard member (the name and city stored with a winner).</summary>
internal sealed record ParticipantInfo(string? Name, string? City);

/// <summary>
/// PHP's winners draws (models/quizadmin.php:1752-2105), pure: state in, state out, the random source injected. Within a cycle nobody wins twice (daily and Grand winners are excluded from every later draw;
/// the overall Mega winner is not excluded from the TSR student draw). Nothing is replaced or stamped unless a winner was drawn.
/// </summary>
internal static class QuizDraw
{
    public static DrawReport Report(IReadOnlyList<DrawCell> cells, string? blocked)
    {
        var drawn = cells.Sum(c => c.Drawn);
        var missing = cells.Sum(c => c.Missing);
        if (blocked is not null && drawn == 0)
        {
            return new DrawReport("blocked", "Nothing was drawn: " + blocked, drawn, missing, false, blocked, cells);
        }

        if (missing > 0)
        {
            var suffix = blocked is not null ? " (" + blocked + ")." : " because too few eligible people were left.";
            return new DrawReport("incomplete", $"Drew {drawn} of {drawn + missing} winners; {missing} could not be drawn{suffix}", drawn, missing, false, blocked, cells);
        }

        return new DrawReport("complete", drawn > 0 ? $"Drew {drawn} winners." : "Nothing needed drawing.", drawn, missing, false, blocked, cells);
    }

    /// <summary>The daily draw (every started episode without winners; a reset redraws the current one) or the Grand draw (every started episode; a reset redraws them all).</summary>
    public static DrawResult Episodes(
        IReadOnlyList<int> counts, Feasibility feasibility, JsonObject winners, long quizDay, IReadOnlyDictionary<int, ParticipantInfo> info, bool reset, bool grand, IQuizRandom random)
    {
        if (quizDay < 1)
        {
            return Unchanged(Report([], "no episode has started yet"), winners);
        }

        var days = (int)Math.Min(quizDay, feasibility.TotalQuizzes);
        var resetEpisodes = !reset ? [] : grand ? Enumerable.Range(1, days).ToList() : [days];
        foreach (var episode in resetEpisodes)
        {
            var block = QuizEligibility.EpisodeBlock(feasibility, episode);
            if (block is not null)
            {
                return Unchanged(Report(Undrawn(episode, counts), block), winners);
            }
        }

        var original = winners;
        var working = (JsonObject)winners.DeepClone();
        var cells = new List<DrawCell>();
        string? blocked = null;
        for (var episode = 1; episode <= days; episode++)
        {
            if (resetEpisodes.Contains(episode))
            {
                working.Remove(episode.ToString(System.Globalization.CultureInfo.InvariantCulture));
            }
            else if (working.ContainsKey(episode.ToString(System.Globalization.CultureInfo.InvariantCulture)))
            {
                continue;
            }

            var block = QuizEligibility.EpisodeBlock(feasibility, episode);
            if (block is not null)
            {
                blocked ??= block;
                cells.AddRange(Undrawn(episode, counts));
                continue;
            }

            cells.AddRange(DrawEpisode(episode, counts, feasibility.ByDay[episode].Candidates, working, info, random));
        }

        var report = Report(cells, blocked);
        return report.Drawn == 0 ? Unchanged(report, original) : new DrawResult(report with { Changed = true }, working, ReplacedOf(original, resetEpisodes, grand ? "grand" : "daily"));
    }

    /// <summary>One Mega draw ("mega" or "mega_student"): the winner already drawn stays unless this is a reset.</summary>
    public static DrawResult Mega(string key, bool reset, Pool pool, JsonObject winners, IReadOnlyDictionary<int, ParticipantInfo> info, IQuizRandom random)
    {
        var undrawn = new DrawCell(null, 0, 0, 1);
        if (!pool.Feasible)
        {
            return Unchanged(Report([undrawn], pool.Reason), winners);
        }

        if (winners[key] is not null && !reset)
        {
            return Unchanged(Report([new DrawCell(null, 0, 0, 0)], null), winners);
        }

        var token = CalcWinner(pool.Candidates, WinningTokens(winners), random);
        if (token is null)
        {
            return Unchanged(Report([undrawn], null), winners);
        }

        var working = (JsonObject)winners.DeepClone();
        var replaced = reset && winners[key] is JsonObject old && old.Count > 0
            ? new List<ReplacedWinners> { new(key, JsonValue.Create("MEGA"), new JsonArray(old.DeepClone())) }
            : [];
        var person = info.GetValueOrDefault(token.Value) ?? new ParticipantInfo("(unknown)", string.Empty);
        working[key] = new JsonObject
        {
            ["episode"] = "MEGA",
            ["prize"] = "MEGA",
            ["token"] = token.Value,
            ["name"] = person.Name,
            ["city"] = person.City,
        };
        return new DrawResult(Report([new DrawCell(null, 0, 1, 0)], null) with { Changed = true }, working, replaced);
    }

    /// <summary>PHP calcWinner: one pick from the candidates who have not won in this cycle; null when none is left.</summary>
    public static int? CalcWinner(IReadOnlyList<int> candidates, ISet<int> winningTokens, IQuizRandom random)
    {
        var eligible = candidates.Where(c => !winningTokens.Contains(c)).ToList();
        return eligible.Count == 0 ? null : eligible[random.Next(eligible.Count)];
    }

    /// <summary>PHP winningTokensOf: tokens that already won a daily or Grand prize (the Mega entries are not lists).</summary>
    public static HashSet<int> WinningTokens(JsonObject winners)
    {
        var tokens = new HashSet<int>();
        foreach (var (key, entries) in winners)
        {
            if (key is "mega" or "mega_student" || entries is not JsonArray list)
            {
                continue;
            }

            foreach (var winner in list.OfType<JsonObject>())
            {
                if (winner["token"] is JsonValue value && value.TryGetValue<int>(out var token) && token != 0)
                {
                    tokens.Add(token);
                }
            }
        }

        return tokens;
    }

    /// <summary>PHP episodesWithWinners: the numeric keys with at least one winner.</summary>
    public static int EpisodesWithWinners(JsonObject winners) =>
        winners.Count(e => int.TryParse(e.Key, System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out _) && e.Value is JsonArray { Count: > 0 });

    private static DrawResult Unchanged(DrawReport report, JsonObject winners) => new(report, winners, []);

    private static List<DrawCell> Undrawn(int episode, IReadOnlyList<int> counts) =>
        counts.Select((count, index) => new DrawCell(episode, index + 1, 0, count)).ToList();

    private static List<DrawCell> DrawEpisode(
        int episode, IReadOnlyList<int> counts, IReadOnlyList<int> candidates, JsonObject winners, IReadOnlyDictionary<int, ParticipantInfo> info, IQuizRandom random)
    {
        var cells = new List<DrawCell>();
        var winning = WinningTokens(winners);
        var key = episode.ToString(System.Globalization.CultureInfo.InvariantCulture);
        for (var prize = 0; prize < counts.Count; prize++)
        {
            var drawn = 0;
            var missing = 0;
            for (var j = 0; j < counts[prize]; j++)
            {
                var token = CalcWinner(candidates, winning, random);
                if (token is null)
                {
                    missing++;
                    continue;
                }

                var person = info.GetValueOrDefault(token.Value) ?? new ParticipantInfo("(unknown)", string.Empty);
                var list = winners[key] as JsonArray ?? [];
                winners[key] = list;
                list.Add((JsonNode)new JsonObject { ["episode"] = episode, ["prize"] = prize + 1, ["token"] = token.Value, ["name"] = person.Name, ["city"] = person.City });
                winning.Add(token.Value);
                drawn++;
            }

            cells.Add(new DrawCell(episode, prize + 1, drawn, missing));
        }

        return cells;
    }

    private static List<ReplacedWinners> ReplacedOf(JsonObject original, IReadOnlyList<int> resetEpisodes, string kind) =>
        resetEpisodes
            .Select(e => (Episode: e, Old: original[e.ToString(System.Globalization.CultureInfo.InvariantCulture)] as JsonArray))
            .Where(e => e.Old is { Count: > 0 })
            .Select(e => new ReplacedWinners(kind, JsonValue.Create(e.Episode)!, e.Old!.DeepClone()))
            .ToList();
}
