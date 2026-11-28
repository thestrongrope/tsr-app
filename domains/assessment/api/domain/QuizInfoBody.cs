using System.Globalization;
using System.Text.Json.Nodes;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>Who is asking: a signed-in member (token, whether they hold quiz:admin, whether the draw's rules let them take part). Signed out is null.</summary>
internal sealed record InfoCaller(int Token, bool IsSuperuser, bool CanTakePart);

/// <summary>
/// The body of GET /quiz/info (PHP api/quiz_info.php getQuizInfo, buildGrandQuizResponse, buildMegaQuizResponse, buildParticipationData), pure: the settings document, the clock and the caller in, the answer out.
/// PHP compares the wall clock (get_current_time adds the IST offset and keeps the UTC label) with the sheet's dates as plain numbers, so "now" is the IST wall time labelled +00:00 (<see cref="QuizAdmin.WallLabelledUtc"/>),
/// the sheet's dates are read as +00:00 unless they carry an offset, and every date is written as PHP's format('c'). A date PHP compares with null (no registration start, no quiz stop) behaves as PHP's comparison does.
/// Deviation: dates or episodes that cannot be read answer offline "Quiz settings not available" (PHP: a 500).
/// </summary>
internal static class QuizInfoBody
{
    private const string EndedMessage = "The quiz has ended. Winners will be announced on our YouTube channel.";
    private const string NotAvailable = "Quiz settings not available";

    private sealed record Episode(int Number, DateTimeOffset Start, DateTimeOffset Stop, string? FormId);

    private sealed record Timeline(DateTimeOffset? RegistrationStart, DateTimeOffset? QuizStop, IReadOnlyList<Episode> Episodes);

    public static JsonObject Build(QuizSettings settings, TimeProvider clock, InfoCaller? caller)
    {
        if (settings.Values.Count == 0)
        {
            return Offline("No quiz is currently configured");
        }

        var mode = settings.Str("mode");
        if (!Filled(mode))
        {
            return Offline(NotAvailable);
        }

        if (QuizEligibility.AsciiLower(mode!) == "offline")
        {
            return Offline("No quiz is currently active");
        }

        var isSuperuser = caller?.IsSuperuser ?? false;
        if (mode == "UAT" && !isSuperuser)
        {
            return Offline("Quiz is in testing mode");
        }

        var timeline = ReadTimeline(settings);
        if (timeline is null)
        {
            return Offline(NotAvailable);
        }

        var today = QuizAdmin.OverrideDate(settings) ?? QuizAdmin.WallLabelledUtc(clock);
        var answer = QuizEligibility.AsciiLower(settings.Str("quiz_type") ?? string.Empty) == "grand"
            ? Grand(settings, today, timeline, caller)
            : Mega(settings, today, timeline, caller);
        answer["can_take_part"] = caller?.CanTakePart ?? true;
        return answer;
    }

    private static JsonObject Offline(string message) => new() { ["status"] = "offline", ["message"] = message };

    /// <summary>PHP empty() on a setting: absent, "" and "0" are empty.</summary>
    private static bool Filled(string? text) => !string.IsNullOrEmpty(text) && text != "0";

    private static Timeline? ReadTimeline(QuizSettings settings)
    {
        var registration = OptionalDate(settings, "quiz_registration");
        var stop = OptionalDate(settings, "quiz_stop");
        if (registration is null || stop is null || settings.Values["episodes"] is not JsonObject { Count: > 0 } table)
        {
            return null;
        }

        var episodes = new List<Episode>();
        foreach (var (key, node) in table)
        {
            var start = QuizAdmin.ParseSettingsDate(QuizOverview.Text(node?["start"]));
            var end = QuizAdmin.ParseSettingsDate(QuizOverview.Text(node?["stop"]));
            if (start is null || end is null)
            {
                return null;
            }

            episodes.Add(new Episode((int)Math.Clamp(PhpValue.IntOfText(key), int.MinValue, int.MaxValue), start.Value, end.Value, QuizOverview.Text(node?["form_id"])));
        }

        return new Timeline(registration.Value.Date, stop.Value.Date, episodes);
    }

    /// <summary>A date setting that is empty is "no date" (a hit with a null date); one that is filled and unreadable is a failure (a miss).</summary>
    private static (bool Ok, DateTimeOffset? Date)? OptionalDate(QuizSettings settings, string key)
    {
        var text = settings.Str(key);
        if (!Filled(text))
        {
            return (true, null);
        }

        var date = QuizAdmin.ParseSettingsDate(text);
        return date is null ? null : (true, date);
    }

    /// <summary>PHP's <c>$today &gt;= $bound</c>, which is true when the bound is null.</summary>
    private static bool Reached(DateTimeOffset today, DateTimeOffset? bound) => bound is null || today >= bound;

    private static JsonObject Grand(QuizSettings settings, DateTimeOffset today, Timeline timeline, InfoCaller? caller)
    {
        var episode = timeline.Episodes[0];
        var status = "upcoming";
        string? message = null;
        JsonNode? participation = null;
        if (Reached(today, timeline.QuizStop) || today >= episode.Stop)
        {
            (status, message) = ("ended", EndedMessage);
        }
        else if (today >= episode.Start)
        {
            (status, message) = ("live", "Quiz is now live! Click the link to participate.");
            participation = caller is null ? null : Participation(episode.FormId, settings);
        }
        else if (Reached(today, timeline.RegistrationStart))
        {
            (status, message) = ("registered", Registered(settings));
        }

        var timing = new JsonObject
        {
            ["registration_start"] = Stamp(timeline.RegistrationStart),
            ["quiz_start"] = QuizAdmin.Stamp(episode.Start),
            ["quiz_end"] = QuizAdmin.Stamp(episode.Stop),
            ["quiz_stop"] = Stamp(timeline.QuizStop),
        };
        var episodeBody = new JsonObject
        {
            ["id"] = 1,
            ["start"] = QuizAdmin.Stamp(episode.Start),
            ["end"] = QuizAdmin.Stamp(episode.Stop),
            ["participation"] = participation,
            ["form_id"] = episode.FormId,
        };
        return Assemble(settings, "grand", status, message, caller, timing, "episode", episodeBody);
    }

    private static JsonObject Mega(QuizSettings settings, DateTimeOffset today, Timeline timeline, InfoCaller? caller)
    {
        var list = new JsonArray();
        var currentDay = 0;
        int? currentEpisode = null;
        int? nextEpisode = null;
        var nextStart = default(DateTimeOffset);
        DateTimeOffset? previousStart = null;
        foreach (var episode in timeline.Episodes)
        {
            previousStart ??= episode.Start;
            if (today >= episode.Start && episode.Start >= previousStart && timeline.QuizStop is { } stop && episode.Start <= stop)
            {
                currentDay = episode.Number;
            }

            previousStart = episode.Start;
            var status = "upcoming";
            JsonNode? participation = null;
            if (today >= episode.Stop)
            {
                status = "ended";
                participation = caller is null ? null : Participation(episode.FormId, settings);
            }
            else if (today >= episode.Start)
            {
                status = "live";
                currentEpisode = episode.Number;
                participation = caller is null ? null : Participation(episode.FormId, settings);
            }
            else if (nextEpisode is null || episode.Start < nextStart)
            {
                (nextEpisode, nextStart) = (episode.Number, episode.Start);
            }

            list.Add((JsonNode)new JsonObject
            {
                ["id"] = episode.Number,
                ["number"] = episode.Number,
                ["status"] = status,
                ["is_accessible"] = status != "upcoming",
                ["start"] = QuizAdmin.Stamp(episode.Start),
                ["end"] = QuizAdmin.Stamp(episode.Stop),
                ["participation"] = participation,
                ["form_id"] = episode.FormId,
            });
        }

        var started = Reached(today, timeline.RegistrationStart) && timeline.QuizStop is { } quizStop && today <= quizStop;
        var (overall, message) = MegaStatus(settings, today, timeline, currentDay, started);
        var timing = new JsonObject { ["registration_start"] = Stamp(timeline.RegistrationStart), ["quiz_stop"] = Stamp(timeline.QuizStop) };
        var total = settings.Str("total_quizzes") is null ? timeline.Episodes.Count : (int)Math.Clamp(settings.Int("total_quizzes"), int.MinValue, int.MaxValue);
        var episodes = new JsonObject { ["total"] = total, ["current_day"] = currentDay, ["current_episode"] = currentEpisode, ["next_episode"] = nextEpisode, ["list"] = list };
        return Assemble(settings, "mega", overall, message, caller, timing, "episodes", episodes);
    }

    private static (string Status, string? Message) MegaStatus(QuizSettings settings, DateTimeOffset today, Timeline timeline, int currentDay, bool started)
    {
        if (Reached(today, timeline.QuizStop))
        {
            return ("ended", EndedMessage);
        }

        if (currentDay > 0)
        {
            return ("live", "Quiz is ongoing! Check the episodes list for participation links.");
        }

        return started ? ("registered", Registered(settings)) : ("upcoming", null);
    }

    private static string Registered(QuizSettings settings) =>
        "You are registered. The quiz will be telecast live from our YouTube channel on " + settings.Str("quiz_date");

    private static string? Stamp(DateTimeOffset? date) => date is null ? null : QuizAdmin.Stamp(date.Value);

    /// <summary>PHP buildParticipationData: null without a form; else the form and the template's address without its query.</summary>
    private static JsonObject? Participation(string? formId, QuizSettings settings)
    {
        if (!Filled(formId))
        {
            return null;
        }

        var template = settings.Str("link_template");
        var query = template?.IndexOf('?', StringComparison.Ordinal) ?? -1;
        var baseUrl = !Filled(template) ? null : query >= 0 ? template![..query] : template;
        return new JsonObject { ["form_id"] = formId, ["form_base_url"] = baseUrl };
    }

    private static JsonObject Assemble(QuizSettings settings, string type, string status, string? message, InfoCaller? caller, JsonObject timing, string middleKey, JsonObject middle)
    {
        var isSuperuser = caller?.IsSuperuser ?? false;
        return new JsonObject
        {
            ["type"] = type,
            ["name"] = settings.Str("quiz_title") ?? "Unknown Quiz",
            ["series"] = settings.Str("quiz_series"),
            ["description"] = settings.Str("quiz_date"),
            ["status"] = status,
            ["message"] = message,
            ["is_superuser"] = isSuperuser,
            ["timing"] = timing,
            [middleKey] = middle,
            ["banner"] = Filled(settings.Str("banner_url")) ? settings.Str("banner_url") : null,
            ["colors"] = new JsonObject
            {
                ["primary"] = settings.Str("color_heading") ?? "#ae3242",
                ["secondary"] = settings.Str("color_sub_heading") ?? "#510d25",
                ["background"] = settings.Str("color_background") ?? "#ffffff",
                ["text"] = settings.Str("color_text") ?? "#000000",
            },
            ["mode"] = settings.Str("mode"),
            ["youtube_url"] = "https://www.youtube.com/thestrongrope",
            ["admin_url"] = isSuperuser ? "/score/quiz_admin.php" : null,
            ["auth"] = new JsonObject
            {
                ["method"] = caller is null ? "none" : "firebase",
                ["can_register"] = caller is not null,
                ["user_token"] = caller?.Token,
            },
        };
    }
}
