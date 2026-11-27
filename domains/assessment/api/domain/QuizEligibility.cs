using System.Text.Json.Nodes;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>A row of the participation sheet: the token as typed and the score text ("X / Y").</summary>
internal sealed record Submission(string Token, string Score);

/// <summary>The member data the scoreboard shows (the member's profile).</summary>
internal sealed record Member(string Name, string City, string Country);

internal sealed record Funnel(int Submissions, int AfterDedup, int InUsersDb, int AfterCountry, int AfterExcluded, int Passing);

internal sealed record DayResult(Funnel Funnel, IReadOnlyList<int> Candidates, int Needed, bool Feasible, string Reason);

internal sealed record Pool(IReadOnlyList<int> Candidates, int MinimumCount, bool Feasible, string Reason);

/// <summary>PHP feasibility() (models/quizadmin.php:1147): per-day eligibility funnels, the Mega pools, the cross-day check and the scoreboard inputs.</summary>
internal sealed record Feasibility(
    int MinScorePercent,
    int TotalQuizzes,
    IReadOnlyDictionary<int, DayResult> ByDay,
    Pool Mega,
    Pool MegaStudent,
    bool CrossDayFeasible,
    string CrossDayReason,
    SortedDictionary<int, SortedDictionary<int, string>> EligibleScores,
    IReadOnlyDictionary<int, Member> Users);

/// <summary>
/// PHP's eligibility rules (feasibilityFromData, scorePassesThreshold, buildScoreboard, normalizeCityAndCountry; models/quizadmin.php:1089-1750), pure: no database, no clock.
/// Funnel per episode: submissions, first one per token, member exists, country allowed, token not excluded, score passes. The scoreboard lists members that pass the first three (not the exclusion or the score).
/// </summary>
internal static class QuizEligibility
{
    private const string WhitespaceForTrim = " \t\n\r\0\v";

    /// <summary>PHP scorePassesThreshold: "X / Y" with (X / Y) * 100 at least the minimum; an empty, malformed or zero-maximum score fails.</summary>
    public static bool ScorePasses(string score, int minPercent)
    {
        var text = score.Trim(' ', '\t', '\n', '\r', '\0', '\v');
        var at = text.IndexOf(" / ", StringComparison.Ordinal);
        if (at < 0)
        {
            return false;
        }

        var earned = PhpValue.IntOfText(text[..at]);
        var max = PhpValue.IntOfText(text[(at + 3)..]);
        return max != 0 && (double)earned / max * 100 >= minPercent;
    }

    /// <summary>PHP canTakePart (models/quizadmin.php:1286): false for an excluded token or an excluded country (compared trimmed and lower case).</summary>
    public static bool CanTakePart(QuizSettings settings, int token, string? country) =>
        !ExcludedTokens(settings).Contains(token) && !ExcludedCountries(settings).Contains(AsciiLower((country ?? string.Empty).Trim(WhitespaceForTrim.ToCharArray())));

    public static IReadOnlyList<int> WinnerCounts(QuizSettings settings) =>
        (settings.Str("daily_winner_counts") ?? string.Empty).Split(',').Select(c => (int)Math.Clamp(PhpValue.IntOfText(c), int.MinValue, int.MaxValue)).ToList();

    public static Feasibility Compute(IReadOnlyDictionary<int, List<Submission>> days, IReadOnlyDictionary<int, Member> users, QuizSettings settings)
    {
        var minPercent = settings.Str("min_score_percent") is null ? 100 : (int)Math.Clamp(settings.Int("min_score_percent"), int.MinValue, int.MaxValue);
        var total = settings.TotalQuizzes;
        var needed = WinnerCounts(settings).Sum();
        var excludedCountries = ExcludedCountries(settings);
        var excludedTokens = ExcludedTokens(settings);
        var byDay = new Dictionary<int, DayResult>();
        var eligible = new SortedDictionary<int, SortedDictionary<int, string>>();
        var known = new Dictionary<int, Member>();
        var passDays = new List<(int Token, int Count)>();

        for (var day = 1; day <= total; day++)
        {
            var submissions = days.TryGetValue(day, out var list) ? list : [];
            byDay[day] = DayOf(submissions, users, minPercent, needed, day, excludedCountries, excludedTokens, eligible, known, passDays);
        }

        var megaMinimum = settings.Str("mega_winner_minimum_count") is null ? total : (int)Math.Clamp(settings.Int("mega_winner_minimum_count"), int.MinValue, int.MaxValue);
        var megaCandidates = passDays.Where(p => p.Count >= megaMinimum).Select(p => p.Token).ToList();
        var mega = new Pool(
            megaCandidates,
            megaMinimum,
            megaCandidates.Count > 0,
            megaCandidates.Count > 0 ? string.Empty : $"No participants qualified for the mega prize (need {megaMinimum} episodes with passing score at min_score_percent={minPercent}).");
        var (crossFeasible, crossReason) = CrossDay(byDay, total, minPercent);
        return new Feasibility(
            minPercent, total, byDay, mega, new Pool([], megaMinimum, false, string.Empty), crossFeasible, crossReason, eligible, known);
    }

    /// <summary>PHP feasibility()'s student step: the Mega pool restricted to enrolled TSR students (an active class, not removed).</summary>
    public static Feasibility WithStudents(Feasibility f, IReadOnlySet<int> students)
    {
        var candidates = f.Mega.Candidates.Where(students.Contains).ToList();
        var reason = candidates.Count > 0
            ? string.Empty
            : $"No TSR students qualified for the mega prize (need {f.Mega.MinimumCount} episodes with passing score at min_score_percent={f.MinScorePercent}%).";
        return f with { MegaStudent = new Pool(candidates, f.Mega.MinimumCount, candidates.Count > 0, reason) };
    }

    public static Feasibility WithoutStudents(Feasibility f) =>
        f with { MegaStudent = new Pool([], f.Mega.MinimumCount, false, "Could not load the TSR student list (see server logs).") };

    /// <summary>PHP episodeBlock: why episode <paramref name="i"/> cannot be drawn, or null.</summary>
    public static string? EpisodeBlock(Feasibility f, int i)
    {
        if (!f.CrossDayFeasible)
        {
            return f.CrossDayReason;
        }

        if (!f.ByDay.TryGetValue(i, out var day))
        {
            return $"No feasibility data for day {i}";
        }

        return day.Feasible ? null : day.Reason;
    }

    /// <summary>PHP buildScoreboard: [counter, token, Name, "City, Country", score per episode] for each member that passed dedup, membership and country, in token order.</summary>
    public static JsonArray BuildScoreboard(Feasibility f)
    {
        var rows = new JsonArray();
        var counter = 1;
        foreach (var (token, scores) in f.EligibleScores)
        {
            if (!f.Users.TryGetValue(token, out var member))
            {
                continue;
            }

            var row = new JsonArray(counter, token, member.Name.UpperWords(), JsonValue.Create(NormalizeCityAndCountry(member.City.UpperWords(), member.Country.UpperWords())));
            for (var day = 1; day <= f.TotalQuizzes; day++)
            {
                row.Add((JsonNode?)JsonValue.Create(scores.TryGetValue(day, out var score) ? score : string.Empty));
            }

            rows.Add((JsonNode)row);
            counter++;
        }

        return rows;
    }

    /// <summary>PHP normalizeCityAndCountry: both trimmed; null when either is empty or "0" (PHP returns an unset variable); each mapped through the tables, then "City, Country" (or one name when equal).</summary>
    public static string? NormalizeCityAndCountry(string? city, string? country)
    {
        var c1 = (city ?? string.Empty).Trim(WhitespaceForTrim.ToCharArray());
        var c2 = (country ?? string.Empty).Trim(WhitespaceForTrim.ToCharArray());
        if (c1 is "" or "0" || c2 is "" or "0")
        {
            return null;
        }

        if (CityNames.Cities.TryGetValue(AsciiLower(c1), out var cityMap) && cityMap.Split(", ") is { Length: > 1 } cityParts)
        {
            (c1, c2) = (cityParts[0], cityParts[1]);
        }

        if (CityNames.Countries.TryGetValue(AsciiLower(c2), out var countryMap))
        {
            var countryParts = countryMap.Split(", ");
            (c1, c2) = countryParts.Length > 1 ? (countryParts[0], countryParts[1]) : (c1, countryParts[0]);
        }

        return c1 == c2 ? c1 : c1 + ", " + c2;
    }

    /// <summary>PHP strtolower since 8.2: ASCII letters only.</summary>
    internal static string AsciiLower(string text) => string.Create(text.Length, text, (span, source) =>
    {
        for (var i = 0; i < source.Length; i++)
        {
            span[i] = source[i] is >= 'A' and <= 'Z' ? (char)(source[i] + 32) : source[i];
        }
    });

    private static DayResult DayOf(
        List<Submission> submissions,
        IReadOnlyDictionary<int, Member> users,
        int minPercent,
        int needed,
        int day,
        HashSet<string> excludedCountries,
        HashSet<int> excludedTokens,
        SortedDictionary<int, SortedDictionary<int, string>> eligible,
        Dictionary<int, Member> known,
        List<(int Token, int Count)> passDays)
    {
        var seen = new HashSet<int>();
        var afterDedup = submissions.Where(s => seen.Add(TokenOf(s))).ToList();
        var inUsers = afterDedup.Where(s => users.ContainsKey(TokenOf(s))).ToList();
        var afterCountry = new List<Submission>();
        foreach (var s in inUsers)
        {
            var token = TokenOf(s);
            var member = users[token];
            if (excludedCountries.Contains(AsciiLower(member.Country.Trim(WhitespaceForTrim.ToCharArray()))))
            {
                continue;
            }

            afterCountry.Add(s);
            if (!eligible.TryGetValue(token, out var scores))
            {
                eligible[token] = scores = [];
            }

            scores[day] = s.Score;
            known.TryAdd(token, member);
        }

        var afterExcluded = afterCountry.Where(s => !excludedTokens.Contains(TokenOf(s))).ToList();
        var candidates = new List<int>();
        foreach (var s in afterExcluded.Where(s => ScorePasses(s.Score, minPercent)))
        {
            candidates.Add(TokenOf(s));
            CountPass(passDays, TokenOf(s));
        }

        var feasible = candidates.Count >= needed;
        var funnel = new Funnel(submissions.Count, afterDedup.Count, inUsers.Count, afterCountry.Count, afterExcluded.Count, candidates.Count);
        return new DayResult(funnel, candidates, needed, feasible, feasible ? string.Empty : ShortfallReason(submissions.Count, candidates.Count, needed, day, minPercent));
    }

    private static string ShortfallReason(int submissions, int candidates, int needed, int day, int minPercent) =>
        submissions == 0
            ? $"Day {day}: 0 submissions — quiz hasn't started"
            : $"Day {day} has {candidates} {(candidates == 1 ? "candidate" : "candidates")} at min_score_percent={minPercent}; need {needed} {(needed == 1 ? "winner" : "winners")}."
              + " To relax the threshold, update min_score_percent in the Technical sheet and re-run.";

    private static void CountPass(List<(int Token, int Count)> passDays, int token)
    {
        var at = passDays.FindIndex(p => p.Token == token);
        if (at < 0)
        {
            passDays.Add((token, 1));
            return;
        }

        passDays[at] = (token, passDays[at].Count + 1);
    }

    /// <summary>Largest number of started episodes for which the failing subset is named by PHP's own subset search (2^12 subsets); above it the set is the one the matching found.</summary>
    private const int NamedBySubsetSearch = 12;

    /// <summary>
    /// PHP's Hall check: for every non-empty subset of the started episodes (those with submissions) the union of their candidates must cover the winners they need, or the draw cannot finish with one prize per person.
    /// Decided by a matching (each episode needs <c>Needed</c> distinct candidates, a candidate serves one episode), which gives PHP's verdict without trying 2^n subsets. Only a failure is named:
    /// with up to <see cref="NamedBySubsetSearch"/> started episodes by PHP's own search (its first failing subset in mask order, so the text is PHP's), above that by the episodes the matching could not serve.
    /// </summary>
    private static (bool Feasible, string Reason) CrossDay(Dictionary<int, DayResult> byDay, int total, int minPercent)
    {
        var started = Enumerable.Range(1, total).Where(d => byDay[d].Funnel.Submissions > 0).ToList();
        var violators = HallViolators(started, byDay);
        if (violators is null)
        {
            return (true, string.Empty);
        }

        var subset = started.Count <= NamedBySubsetSearch ? FirstFailingSubset(started, byDay) ?? violators : violators;
        var union = subset.SelectMany(d => byDay[d].Candidates).ToHashSet();
        var demand = subset.Sum(d => (long)byDay[d].Needed);
        return (false, $"Days {string.Join(", ", subset)} collectively need {demand} winners but only {union.Count} unique candidates exist across these days at min_score_percent={minPercent}."
            + " Within-cycle uniqueness will prevent winner generation from completing. To relax, update min_score_percent in the Technical sheet and re-run.");
    }

    /// <summary>PHP's loop: the first subset (in mask order) whose candidates do not cover its demand.</summary>
    private static List<int>? FirstFailingSubset(List<int> started, Dictionary<int, DayResult> byDay)
    {
        for (var mask = 1; mask < 1 << started.Count; mask++)
        {
            var subset = started.Where((_, i) => (mask & (1 << i)) != 0).ToList();
            var union = subset.SelectMany(d => byDay[d].Candidates).ToHashSet();
            if (union.Count < subset.Sum(d => (long)byDay[d].Needed))
            {
                return subset;
            }
        }

        return null;
    }

    /// <summary>Null when every started episode can get its winners from distinct candidates; else episodes that together need more than their candidates can give (a Hall violator).</summary>
    private static List<int>? HallViolators(List<int> started, Dictionary<int, DayResult> byDay)
    {
        var owner = new Dictionary<int, int>();
        foreach (var day in started)
        {
            var need = Math.Max(0, byDay[day].Needed);
            if (need > byDay[day].Candidates.Count)
            {
                return [day];
            }

            for (var unit = 0; unit < need; unit++)
            {
                var visitedDays = new HashSet<int>();
                if (!Assign(day, byDay, owner, new HashSet<int>(), visitedDays))
                {
                    return [.. visitedDays.Order()];
                }
            }
        }

        return null;
    }

    /// <summary>One augmenting path: give <paramref name="day"/> one more candidate, moving other episodes to their other candidates where needed. Depth is at most the number of episodes.</summary>
    private static bool Assign(int day, Dictionary<int, DayResult> byDay, Dictionary<int, int> owner, HashSet<int> visitedTokens, HashSet<int> visitedDays)
    {
        visitedDays.Add(day);
        foreach (var token in byDay[day].Candidates)
        {
            if (!visitedTokens.Add(token))
            {
                continue;
            }

            if (!owner.TryGetValue(token, out var holder) || Assign(holder, byDay, owner, visitedTokens, visitedDays))
            {
                owner[token] = day;
                return true;
            }
        }

        return false;
    }

    private static int TokenOf(Submission s) => (int)Math.Clamp(PhpValue.IntOfText(s.Token), int.MinValue, int.MaxValue);

    /// <summary>PHP excludedCountries: lower-cased, split on ";" when there is one, else ","; empty entries dropped.</summary>
    internal static HashSet<string> ExcludedCountries(QuizSettings settings)
    {
        var source = settings.Str("excluded_countries") ?? string.Empty;
        var separator = source.Contains(';', StringComparison.Ordinal) ? ';' : ',';
        return source.Split(separator).Select(c => AsciiLower(c.Trim(WhitespaceForTrim.ToCharArray()))).Where(c => c is not ("" or "0")).ToHashSet(StringComparer.Ordinal);
    }

    /// <summary>PHP excludedTokens: whole numbers separated by ";", zero and blanks dropped.</summary>
    internal static HashSet<int> ExcludedTokens(QuizSettings settings) =>
        (settings.Str("excluded_tokens") ?? string.Empty).Split(';')
            .Select(t => (int)Math.Clamp(PhpValue.IntOfText(t.Trim(WhitespaceForTrim.ToCharArray())), int.MinValue, int.MaxValue))
            .Where(t => t != 0)
            .ToHashSet();

    /// <summary>PHP ucwords: the first letter of each word upper case (words end at space, tab, CR, LF, form feed, vertical tab); the rest is left as it is.</summary>
    internal static string UpperWords(this string text)
    {
        var chars = text.ToCharArray();
        var atStart = true;
        for (var i = 0; i < chars.Length; i++)
        {
            if (atStart && chars[i] is >= 'a' and <= 'z')
            {
                chars[i] = (char)(chars[i] - 32);
            }

            atStart = chars[i] is ' ' or '\t' or '\r' or '\n' or '\f' or '\v';
        }

        return new string(chars);
    }
}
