using System.Net;
using System.Text.Json.Nodes;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// What GET /admin/quiz shows and the refresh answers with, as PHP's app route sends it (api_quiz_state, api_quiz_settings, QuizAdminModel::overview and its views, models/quizadmin.php:~520-780, routes/quiz_admin.php:~110-190).
/// Nothing in it names a sheet or lists tokens: the settings are a whitelist and the eligibility rows are counts. The replaced-winners record is never part of it. Values are cast as PHP's api_cast does:
/// a nullable text that is empty is null, a required one is empty text, a required number is 0.
/// </summary>
internal static class QuizOverview
{
    private static readonly string[] ActivityKeys =
    [
        "scoreboard_published:scoreboard_updated", "winners_generated:winners_generated", "winners_reset:winners_reset", "winners_published:winners_updated",
        "mega_generated:mega_winner_generated", "mega_reset:mega_winner_reset", "mega_published:mega_winner_updated",
        "mega_student_generated:mega_student_winner_generated", "mega_student_reset:mega_student_winner_reset", "mega_student_published:mega_student_winner_updated",
    ];

    public static JsonObject Build(QuizSettings settings, JsonObject winners, JsonObject timestamps, long quizDay, Feasibility? feasibility, bool canReset)
    {
        var total = settings.TotalQuizzes;
        return new JsonObject
        {
            ["settings"] = Settings(settings),
            ["quiz_day"] = quizDay,
            ["download"] = Download(timestamps),
            ["eligibility"] = Eligibility(feasibility, total),
            ["gates"] = Gates(feasibility, quizDay, total, winners),
            ["winners"] = Winners(winners, settings),
            ["activity"] = Activity(timestamps),
            ["can_reset"] = canReset,
        };
    }

    /// <summary>The settings the app may see (api_quiz_settings over settingsView): no sheet ids, no token lists, no form ids.</summary>
    public static JsonObject Settings(QuizSettings settings)
    {
        var episodes = new JsonArray();
        if (settings.Values["episodes"] is JsonObject table)
        {
            foreach (var (number, entry) in table)
            {
                episodes.Add(new JsonObject
                {
                    ["episode"] = (int)Math.Clamp(Tsr.Shared.Api.PhpValue.IntOfText(number), int.MinValue, int.MaxValue),
                    ["start"] = NullIfEmpty(Text(entry?["start"])),
                    ["stop"] = NullIfEmpty(Text(entry?["stop"])),
                });
            }
        }

        return new JsonObject
        {
            ["loaded"] = settings.Loaded,
            ["kind"] = settings.IsMega ? "mega" : "grand",
            ["series"] = NullIfEmpty(settings.Str("quiz_series")),
            ["title"] = NullIfEmpty(settings.Str("quiz_title")),
            ["mode"] = NullIfEmpty(settings.Str("mode")),
            ["registration"] = NullIfEmpty(settings.Str("quiz_registration")),
            ["stop"] = NullIfEmpty(settings.Str("quiz_stop")),
            ["mega_minimum"] = settings.Str("mega_winner_minimum_count") is null ? null : settings.Int("mega_winner_minimum_count"),
            ["episodes"] = episodes,
            ["winner_counts"] = new JsonArray(QuizEligibility.WinnerCounts(settings).Select(c => (JsonNode?)JsonValue.Create(c)).ToArray()),
            ["winner_labels"] = new JsonArray(Labels(settings).Select(l => (JsonNode?)JsonValue.Create(l)).ToArray()),
            ["colors"] = new JsonObject
            {
                ["heading"] = NullIfEmpty(settings.Str("color_heading")),
                ["sub_heading"] = NullIfEmpty(settings.Str("color_sub_heading")),
                ["odd"] = NullIfEmpty(settings.Str("color_odd")),
                ["even"] = NullIfEmpty(settings.Str("color_even")),
                ["background"] = NullIfEmpty(settings.Str("color_background")),
                ["text"] = NullIfEmpty(settings.Str("color_text")),
                ["heading_text"] = NullIfEmpty(settings.Str("color_heading_text")),
            },
        };
    }

    public static IReadOnlyList<string> Labels(QuizSettings settings) =>
        (settings.Str("winner_labels") ?? string.Empty).Split(',').Select(l => l.Trim()).ToList();

    /// <summary>The submissions per episode of the last download (PHP submissionsPerEpisode).</summary>
    public static JsonArray SubmissionsPerEpisode(JsonObject timestamps)
    {
        var rows = new JsonArray();
        if (timestamps["download_summary"]?["by_day"] is JsonObject byDay)
        {
            foreach (var (episode, day) in byDay)
            {
                rows.Add(new JsonObject
                {
                    ["episode"] = (int)Math.Clamp(Tsr.Shared.Api.PhpValue.IntOfText(episode), int.MinValue, int.MaxValue),
                    ["submissions"] = (int)Math.Clamp(Tsr.Shared.Api.PhpValue.IntOfText(Text(day?["submissions"]) ?? string.Empty), int.MinValue, int.MaxValue),
                });
            }
        }

        return rows;
    }

    /// <summary>PHP stamp: {at, by} for a timestamp prefix, or null when it never happened; "Name (4242)" is shown as "Name" (the token is not for the app).</summary>
    public static JsonNode? Stamp(JsonObject timestamps, string prefix)
    {
        var at = Text(timestamps[prefix + "_at"]);
        if (string.IsNullOrEmpty(at) || at == "0")
        {
            return null;
        }

        return new JsonObject { ["at"] = at.Replace(' ', 'T'), ["by"] = NullIfEmpty(WithoutToken(Text(timestamps[prefix + "_by"]))) };
    }

    private static JsonObject? Download(JsonObject timestamps)
    {
        if (Stamp(timestamps, "scoreboard_downloaded") is not JsonObject stamp)
        {
            return null;
        }

        stamp["submissions"] = SubmissionsPerEpisode(timestamps);
        return stamp;
    }

    private static JsonArray Eligibility(Feasibility? f, int total)
    {
        var rows = new JsonArray();
        if (f is null)
        {
            return rows;
        }

        for (var episode = 1; episode <= total; episode++)
        {
            if (!f.ByDay.TryGetValue(episode, out var day))
            {
                continue;
            }

            var status = day.Funnel.Submissions == 0 ? "not_started" : day.Feasible ? "ok" : "blocked";
            rows.Add(new JsonObject
            {
                ["episode"] = episode,
                ["submitted"] = day.Funnel.Submissions,
                ["after_dedup"] = day.Funnel.AfterDedup,
                ["members"] = day.Funnel.InUsersDb,
                ["country_allowed"] = day.Funnel.AfterCountry,
                ["not_excluded"] = day.Funnel.AfterExcluded,
                ["passing"] = day.Funnel.Passing,
                ["needed"] = day.Needed,
                ["status"] = status,
                ["reason"] = status == "blocked" ? NullIfEmpty(day.Reason) : null,
            });
        }

        return rows;
    }

    private static JsonObject Gates(Feasibility? f, long quizDay, int total, JsonObject winners)
    {
        const string NeedScoreboard = "Download the scoreboard first.";
        var generate = Gate(true, null);
        if (f is null)
        {
            generate = Gate(false, NeedScoreboard);
        }
        else if (quizDay < 1)
        {
            generate = Gate(false, "No episode has started yet.");
        }
        else
        {
            var block = Enumerable.Range(1, (int)Math.Min(quizDay, total)).Select(e => QuizEligibility.EpisodeBlock(f, e)).FirstOrDefault(b => b is not null);
            generate = block is null ? generate : Gate(false, block);
        }

        var offered = total > 0 && QuizDraw.EpisodesWithWinners(winners) >= total;
        var mega = !offered
            ? MegaGate(false, false, "The overall Mega winner needs winners for every episode first.")
            : f is null ? MegaGate(true, false, NeedScoreboard)
            : !f.Mega.Feasible ? MegaGate(true, false, f.Mega.Reason)
            : MegaGate(true, true, null);
        var student = f is null ? Gate(false, NeedScoreboard) : !f.MegaStudent.Feasible ? Gate(false, f.MegaStudent.Reason) : Gate(true, null);
        return new JsonObject { ["generate"] = generate, ["mega"] = mega, ["mega_student"] = student };
    }

    private static JsonObject Gate(bool allowed, string? reason) => new() { ["allowed"] = allowed, ["reason"] = NullIfEmpty(reason) };

    private static JsonObject MegaGate(bool offered, bool allowed, string? reason) => new() { ["offered"] = offered, ["allowed"] = allowed, ["reason"] = NullIfEmpty(reason) };

    private static JsonObject Winners(JsonObject winners, QuizSettings settings)
    {
        var labels = Labels(settings);
        var episodes = new List<(int Episode, JsonObject Entry)>();
        foreach (var (key, entries) in winners)
        {
            if (!int.TryParse(key, System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out var episode) || entries is not JsonArray { Count: > 0 } list)
            {
                continue;
            }

            episodes.Add((episode, new JsonObject { ["episode"] = episode, ["winners"] = WinnerList(list, labels) }));
        }

        return new JsonObject
        {
            ["episodes"] = new JsonArray(episodes.OrderBy(e => e.Episode).Select(e => (JsonNode?)e.Entry).ToArray()),
            ["mega"] = MegaEntry(winners["mega"]),
            ["mega_student"] = MegaEntry(winners["mega_student"]),
        };
    }

    private static JsonArray WinnerList(JsonArray list, IReadOnlyList<string> labels)
    {
        var rank = new Dictionary<int, int>();
        var rows = new JsonArray();
        foreach (var winner in list.OfType<JsonObject>())
        {
            var prize = (int)Math.Clamp(Tsr.Shared.Api.PhpValue.IntOfText(Text(winner["prize"]) ?? string.Empty), int.MinValue, int.MaxValue);
            rank[prize] = rank.GetValueOrDefault(prize) + 1;
            var label = prize >= 1 && prize <= labels.Count ? labels[prize - 1] : "Prize " + prize;
            rows.Add(WinnerView(winner, prize, label, rank[prize]));
        }

        return rows;
    }

    private static JsonObject? MegaEntry(JsonNode? entry) =>
        entry is JsonObject { Count: > 0 } winner
            ? new JsonObject { ["episode"] = null, ["winners"] = new JsonArray(WinnerView(winner, 0, "MEGA", 1)) }
            : null;

    private static JsonObject WinnerView(JsonObject winner, int prize, string label, int rank)
    {
        var name = Text(winner["name"]) ?? string.Empty;
        return new JsonObject
        {
            ["prize"] = prize,
            ["label"] = label,
            ["rank"] = rank,
            ["token"] = (int)Math.Clamp(Tsr.Shared.Api.PhpValue.IntOfText(Text(winner["token"]) ?? string.Empty), int.MinValue, int.MaxValue),
            ["name"] = WebUtility.HtmlDecode(name),
            ["city"] = WebUtility.HtmlDecode(Text(winner["city"]) ?? string.Empty),
            ["known"] = name != string.Empty && name != "(unknown)",
        };
    }

    private static JsonObject Activity(JsonObject timestamps)
    {
        var activity = new JsonObject();
        foreach (var pair in ActivityKeys)
        {
            var parts = pair.Split(':');
            activity[parts[0]] = Stamp(timestamps, parts[1]);
        }

        return activity;
    }

    /// <summary>PHP actorName: the " (1234)" at the end of a stamp's actor is dropped.</summary>
    private static string? WithoutToken(string? label)
    {
        if (string.IsNullOrEmpty(label))
        {
            return null;
        }

        var open = label.LastIndexOf(" (", StringComparison.Ordinal);
        if (open >= 0 && label.EndsWith(')') && label[(open + 2)..^1].All(char.IsAsciiDigit) && label.Length - open > 3)
        {
            return label[..open];
        }

        return label;
    }

    private static string? NullIfEmpty(string? text) => string.IsNullOrEmpty(text) ? null : text;

    /// <summary>A JSON value as PHP would print it: text as it is, a number as digits; null for null, a list or an object.</summary>
    internal static string? Text(JsonNode? node) => node is JsonValue value
        ? value.TryGetValue<string>(out var text) ? text : value.ToJsonString()
        : null;
}
