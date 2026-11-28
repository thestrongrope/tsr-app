using System.Text.Json.Nodes;
using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

/// <summary>The Grand/Mega status rules of GET /quiz/info (PHP api/quiz_info.php). "Now" is 2026-12-02 12:00 on the IST wall clock, which PHP compares with the sheet's dates as plain numbers (both labelled +00:00).</summary>
[TestFixture]
internal sealed class QuizInfoBodyTests
{
    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private static readonly TimeProvider Clock = new FixedClock(DateTimeOffset.Parse("2026-12-02T06:30:00+00:00", System.Globalization.CultureInfo.InvariantCulture));
    private static readonly InfoCaller Member = new(900001, false, true);

    private static QuizSettings Settings(string json) => new((JsonObject)JsonNode.Parse(json)!);

    private static string Grand(string registration = "2026-12-01 09:00:00", string start = "2026-12-05 20:00:00", string stop = "2026-12-05 22:00:00", string quizStop = "2026-12-06 00:00:00", string extra = "") =>
        $$"""
        {"mode":"Live","quiz_type":"GRAND","quiz_title":"Grand Quiz","quiz_series":"S1","quiz_date":"5 Dec",
         "quiz_registration":"{{registration}}","quiz_stop":"{{quizStop}}","link_template":"https://forms.invalid/f?usp=pp&token=",
         "episodes":{"1":{"start":"{{start}}","stop":"{{stop}}","form_id":"FORM1"} } {{extra}} }
        """;

    private const string MegaText =
        """
        {"mode":"Live","quiz_type":"MEGA","quiz_title":"Mega Quiz","quiz_series":"M1","quiz_date":"1 to 6 Dec","total_quizzes":"4",
         "quiz_registration":"2026-11-20 09:00:00","quiz_stop":"2026-12-10 00:00:00","link_template":"https://forms.invalid/m",
         "episodes":{"1":{"start":"2026-12-01 20:00:00","stop":"2026-12-01 22:00:00","form_id":"F1"},
                     "2":{"start":"2026-12-02 11:00:00","stop":"2026-12-02 23:00:00","form_id":"F2"},
                     "3":{"start":"2026-12-04 20:00:00","stop":"2026-12-04 22:00:00","form_id":""},
                     "4":{"start":"2026-12-03 20:00:00","stop":"2026-12-03 22:00:00","form_id":"F4"}}}
        """;

    private static void Same<T>(IEnumerable<T> actual, params T[] expected) => Assert.That(actual, Is.EqualTo(expected));

    private static JsonObject Info(string settings, InfoCaller? caller = null) => QuizInfoBody.Build(Settings(settings), Clock, caller);

    [Test]
    public void A_grand_quiz_before_registration_is_upcoming_with_no_message()
    {
        var info = Info(Grand(registration: "2026-12-03 09:00:00"));

        Assert.That(info["status"]!.GetValue<string>(), Is.EqualTo("upcoming"));
        Assert.That(info["message"], Is.Null);
        Assert.That(info["type"]!.GetValue<string>(), Is.EqualTo("grand"));
    }

    [Test]
    public void A_grand_quiz_after_registration_opens_is_registered_and_names_the_date()
    {
        var info = Info(Grand());

        Assert.That(info["status"]!.GetValue<string>(), Is.EqualTo("registered"));
        Assert.That(info["message"]!.GetValue<string>(), Is.EqualTo("You are registered. The quiz will be telecast live from our YouTube channel on 5 Dec"));
    }

    [Test]
    public void A_live_grand_quiz_gives_a_signed_in_member_the_form_without_its_query_and_a_signed_out_caller_none()
    {
        var live = Grand(start: "2026-12-02 11:00:00", stop: "2026-12-02 13:00:00");

        var signedIn = Info(live, Member);
        var signedOut = Info(live);

        Assert.That(signedIn["status"]!.GetValue<string>(), Is.EqualTo("live"));
        Assert.That(signedIn["message"]!.GetValue<string>(), Is.EqualTo("Quiz is now live! Click the link to participate."));
        Assert.That(signedIn["episode"]!["participation"]!["form_id"]!.GetValue<string>(), Is.EqualTo("FORM1"));
        Assert.That(signedIn["episode"]!["participation"]!["form_base_url"]!.GetValue<string>(), Is.EqualTo("https://forms.invalid/f"));
        Assert.That(signedOut["episode"]!["participation"], Is.Null);
        Assert.That(signedOut["episode"]!["form_id"]!.GetValue<string>(), Is.EqualTo("FORM1"));
    }

    [Test]
    public void A_grand_quiz_is_ended_after_its_episode_and_after_the_quiz_stop()
    {
        var afterEpisode = Info(Grand(start: "2026-12-02 08:00:00", stop: "2026-12-02 10:00:00"));
        var afterStop = Info(Grand(start: "2026-12-02 11:00:00", stop: "2026-12-02 13:00:00", quizStop: "2026-12-02 11:30:00"));

        Assert.That(afterEpisode["status"]!.GetValue<string>(), Is.EqualTo("ended"));
        Assert.That(afterStop["status"]!.GetValue<string>(), Is.EqualTo("ended"));
        Assert.That(afterStop["message"]!.GetValue<string>(), Is.EqualTo("The quiz has ended. Winners will be announced on our YouTube channel."));
    }

    [Test]
    public void A_grand_quiz_without_a_quiz_stop_is_ended_as_PHP_compares_a_date_with_null()
    {
        var info = Info(Grand().Replace("\"quiz_stop\":\"2026-12-06 00:00:00\",", string.Empty, StringComparison.Ordinal));

        Assert.That(info["status"]!.GetValue<string>(), Is.EqualTo("ended"));
        Assert.That(info["timing"]!["quiz_stop"], Is.Null);
    }

    [Test]
    public void A_grand_answer_has_PHPs_keys_in_PHPs_order_and_dates_as_ISO_8601()
    {
        var info = Info(Grand(), Member);

        Same(info.Select(p => p.Key), "type", "name", "series", "description", "status", "message", "is_superuser", "timing", "episode", "banner", "colors", "mode", "youtube_url", "admin_url", "auth", "can_take_part");
        Same(info["timing"]!.AsObject().Select(p => p.Key), "registration_start", "quiz_start", "quiz_end", "quiz_stop");
        Assert.That(info["timing"]!["registration_start"]!.GetValue<string>(), Is.EqualTo("2026-12-01T09:00:00+00:00"));
        Same(info["episode"]!.AsObject().Select(p => p.Key), "id", "start", "end", "participation", "form_id");
        Assert.That(info["name"]!.GetValue<string>(), Is.EqualTo("Grand Quiz"));
        Assert.That(info["series"]!.GetValue<string>(), Is.EqualTo("S1"));
        Assert.That(info["description"]!.GetValue<string>(), Is.EqualTo("5 Dec"));
        Assert.That(info["youtube_url"]!.GetValue<string>(), Is.EqualTo("https://www.youtube.com/thestrongrope"));
        Assert.That(info["mode"]!.GetValue<string>(), Is.EqualTo("Live"));
        Same(info["colors"]!.AsObject().Select(p => (p.Key, p.Value!.GetValue<string>())), ("primary", "#ae3242"), ("secondary", "#510d25"), ("background", "#ffffff"), ("text", "#000000"));
    }

    [Test]
    public void A_signed_in_member_is_PHPs_firebase_plus_token_and_a_signed_out_caller_is_none()
    {
        var signedIn = Info(Grand(), Member)["auth"]!;
        var signedOut = Info(Grand())["auth"]!;

        Assert.That((signedIn["method"]!.GetValue<string>(), signedIn["can_register"]!.GetValue<bool>(), signedIn["user_token"]!.GetValue<int>()), Is.EqualTo(("firebase", true, 900001)));
        Assert.That((signedOut["method"]!.GetValue<string>(), signedOut["can_register"]!.GetValue<bool>()), Is.EqualTo(("none", false)));
        Assert.That(signedOut["user_token"], Is.Null);
    }

    [Test]
    public void The_can_take_part_flag_is_the_callers_and_true_when_signed_out()
    {
        Assert.That(Info(Grand(), new InfoCaller(900001, false, false))["can_take_part"]!.GetValue<bool>(), Is.False);
        Assert.That(Info(Grand())["can_take_part"]!.GetValue<bool>(), Is.True);
    }

    [Test]
    public void A_mega_quiz_reports_each_episodes_status_the_current_day_the_live_episode_and_the_next_one()
    {
        var info = Info(MegaText, Member);

        var episodes = info["episodes"]!;
        Assert.That(info["type"]!.GetValue<string>(), Is.EqualTo("mega"));
        Assert.That(info["status"]!.GetValue<string>(), Is.EqualTo("live"));
        Assert.That(info["message"]!.GetValue<string>(), Is.EqualTo("Quiz is ongoing! Check the episodes list for participation links."));
        Same(episodes.AsObject().Select(p => p.Key), "total", "current_day", "current_episode", "next_episode", "list");
        Assert.That((episodes["total"]!.GetValue<int>(), episodes["current_day"]!.GetValue<int>(), episodes["current_episode"]!.GetValue<int>(), episodes["next_episode"]!.GetValue<int>()), Is.EqualTo((4, 2, 2, 4)));
        var list = episodes["list"]!.AsArray();
        Same(list.Select(e => e!["status"]!.GetValue<string>()), "ended", "live", "upcoming", "upcoming");
        Same(list.Select(e => e!["is_accessible"]!.GetValue<bool>()), true, true, false, false);
        Same(list[0]!.AsObject().Select(p => p.Key), "id", "number", "status", "is_accessible", "start", "end", "participation", "form_id");
        Same(info["timing"]!.AsObject().Select(p => p.Key), "registration_start", "quiz_stop");
    }

    [Test]
    public void A_mega_episode_gives_participation_when_ended_or_live_for_a_signed_in_member_with_a_form_only()
    {
        var signedIn = Info(MegaText, Member)["episodes"]!["list"]!.AsArray();
        var signedOut = Info(MegaText)["episodes"]!["list"]!.AsArray();

        Assert.That(signedIn[0]!["participation"]!["form_id"]!.GetValue<string>(), Is.EqualTo("F1"));
        Assert.That(signedIn[0]!["participation"]!["form_base_url"]!.GetValue<string>(), Is.EqualTo("https://forms.invalid/m"));
        Assert.That(signedIn[1]!["participation"]!["form_id"]!.GetValue<string>(), Is.EqualTo("F2"));
        Assert.That(signedIn[2]!["participation"], Is.Null, "upcoming");
        Assert.That(signedOut.Select(e => e!["participation"]), Is.All.Null);
    }

    [Test]
    public void A_mega_quiz_in_its_registration_period_with_no_episode_started_is_registered_and_before_it_upcoming_and_after_its_stop_ended()
    {
        var registered = MegaText.Replace("2026-12-01 20:00:00", "2026-12-07 20:00:00", StringComparison.Ordinal).Replace("2026-12-02 11:00:00", "2026-12-08 11:00:00", StringComparison.Ordinal);
        var upcoming = registered.Replace("2026-11-20 09:00:00", "2026-12-03 09:00:00", StringComparison.Ordinal);
        var ended = MegaText.Replace("2026-12-10 00:00:00", "2026-12-02 11:59:00", StringComparison.Ordinal);

        Assert.That(Info(registered)["status"]!.GetValue<string>(), Is.EqualTo("registered"));
        Assert.That(Info(registered)["message"]!.GetValue<string>(), Does.StartWith("You are registered."));
        Assert.That(Info(upcoming)["status"]!.GetValue<string>(), Is.EqualTo("upcoming"));
        Assert.That(Info(ended)["status"]!.GetValue<string>(), Is.EqualTo("ended"));
    }

    [Test]
    public void A_mega_quiz_between_episodes_has_a_current_day_but_no_current_episode_and_a_missing_total_counts_the_episodes()
    {
        var between = MegaText.Replace("2026-12-02 11:00:00", "2026-12-02 09:00:00", StringComparison.Ordinal).Replace("2026-12-02 23:00:00", "2026-12-02 10:00:00", StringComparison.Ordinal)
            .Replace("\"total_quizzes\":\"4\",", string.Empty, StringComparison.Ordinal);

        var episodes = Info(between)["episodes"]!;

        Assert.That(episodes["current_day"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(episodes["current_episode"], Is.Null);
        Assert.That(episodes["total"]!.GetValue<int>(), Is.EqualTo(4));
    }

    [Test]
    public void Settings_that_are_empty_have_no_mode_or_are_offline_answer_offline_with_PHPs_messages_and_nothing_else()
    {
        var empty = Info("{}");
        var noMode = Info("""{"mode":"0"}""");
        var offline = Info("""{"mode":"Offline"}""");

        Assert.That(empty.ToJsonString(), Is.EqualTo("""{"status":"offline","message":"No quiz is currently configured"}"""));
        Assert.That(noMode.ToJsonString(), Is.EqualTo("""{"status":"offline","message":"Quiz settings not available"}"""));
        Assert.That(offline.ToJsonString(), Is.EqualTo("""{"status":"offline","message":"No quiz is currently active"}"""));
    }

    [Test]
    public void A_quiz_in_UAT_mode_is_hidden_from_everyone_but_a_quiz_admin()
    {
        var uat = Grand().Replace("\"mode\":\"Live\"", "\"mode\":\"UAT\"", StringComparison.Ordinal);

        var hidden = Info(uat, Member);
        var signedOut = Info(uat);
        var admin = Info(uat, new InfoCaller(900002, true, true));

        Assert.That(hidden.ToJsonString(), Is.EqualTo("""{"status":"offline","message":"Quiz is in testing mode"}"""));
        Assert.That(signedOut["status"]!.GetValue<string>(), Is.EqualTo("offline"));
        Assert.That(admin["type"]!.GetValue<string>(), Is.EqualTo("grand"));
        Assert.That(admin["is_superuser"]!.GetValue<bool>(), Is.True);
        Assert.That(admin["admin_url"]!.GetValue<string>(), Is.EqualTo("/score/quiz_admin.php"));
        Assert.That(Info(Grand(), Member)["admin_url"], Is.Null);
    }

    [TestCase(900001, "india", true)]
    [TestCase(900009, "india", false)]
    [TestCase(900001, " Pakistan ", false)]
    [TestCase(900001, null, true)]
    public void A_member_may_take_part_unless_their_token_or_country_is_excluded(int token, string? country, bool expected)
    {
        var settings = Settings("""{"excluded_tokens":"900009;900010","excluded_countries":"pakistan, iran"}""");

        Assert.That(QuizEligibility.CanTakePart(settings, token, country), Is.EqualTo(expected));
    }

    [TestCase("2026-12-05 20:00:00", "2026-12-05T20:00:00+00:00")]
    [TestCase("2026-12-05T20:00:00", "2026-12-05T20:00:00+00:00")]
    [TestCase("2026-12-05 20:00", "2026-12-05T20:00:00+00:00")]
    [TestCase("2026-12-05", "2026-12-05T00:00:00+00:00")]
    [TestCase("2026-12-05T20:00:00+05:30", "2026-12-05T20:00:00+05:30")]
    [TestCase("2026-12-05 20:00:00 +05:30", "2026-12-05T20:00:00+05:30")]
    [TestCase("2026-12-05T20:00:00Z", "2026-12-05T20:00:00+00:00")]
    [TestCase("5 December 2026 8:00 PM", "2026-12-05T20:00:00+00:00")]
    [TestCase("Dec 5, 2026 20:00", "2026-12-05T20:00:00+00:00")]
    public void A_settings_date_is_read_as_UTC_unless_it_carries_an_offset_and_written_as_PHPs_c_format(string text, string expected) =>
        Assert.That(QuizAdmin.Stamp(QuizAdmin.ParseSettingsDate(text)!.Value), Is.EqualTo(expected));

    [TestCase(null)]
    [TestCase("")]
    [TestCase("not a date")]
    public void Text_that_is_not_a_date_is_no_date(string? text) => Assert.That(QuizAdmin.ParseSettingsDate(text), Is.Null);

    [Test]
    public void The_today_override_setting_replaces_the_clock()
    {
        var overridden = Grand(extra: ",\"today_override\":\"2026-12-05 21:00:00\"");

        Assert.That(Info(overridden)["status"]!.GetValue<string>(), Is.EqualTo("live"));
    }

    [Test]
    public void The_banner_is_the_banner_url_setting_or_null()
    {
        Assert.That(Info(Grand(extra: ",\"banner_url\":\"https://img.invalid/b.png\""))["banner"]!.GetValue<string>(), Is.EqualTo("https://img.invalid/b.png"));
        Assert.That(Info(Grand())["banner"], Is.Null);
    }

    [Test]
    public void A_title_that_is_missing_reads_Unknown_Quiz_and_a_quiz_type_that_is_not_grand_is_mega()
    {
        var info = Info(MegaText.Replace("\"quiz_title\":\"Mega Quiz\",", string.Empty, StringComparison.Ordinal).Replace("MEGA", "Weekly", StringComparison.Ordinal));

        Assert.That(info["name"]!.GetValue<string>(), Is.EqualTo("Unknown Quiz"));
        Assert.That(info["type"]!.GetValue<string>(), Is.EqualTo("mega"));
    }
}
