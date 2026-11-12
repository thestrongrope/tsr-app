using System.Globalization;
using System.Net;
using System.Text.Json.Nodes;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Assessment.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// The quiz competition half of <see cref="TestSheetsTests"/>. The world: a Mega quiz of 2 episodes, two prizes a day (counts 1,1), at least 50 percent to pass, the overall Mega open to anyone with one passing episode.
/// Members 923101 to 923110 (names "Sheet Name N", city mumbai, country india; 923106 is from Pakistan, an excluded country; 923105 is an excluded token). Students (an active class, not removed): 923108 only
/// (923107 is in a closed class, 923109 was removed from an active one). Episode 1 answers: 101 passes (and answers twice), 102, 103 fails, 107 (exactly 50), 108, 105 (excluded token), 106 (excluded country), 999999 (no member).
/// Episode 2: 101, 104, 109 pass, 110 fails, 105 (excluded). With the first-pick random source the draws are fixed: day 1 gives 101 and 102, day 2 gives 104 and 109, the Mega winner is 107, the TSR student winner 108.
/// </summary>
public sealed partial class TestSheetsTests
{
    private const string Responses = "resp-sheet";
    private const string Public = "pub-sheet";

    private static readonly int[] QuizMembers = [923101, 923102, 923103, 923104, 923105, 923106, 923107, 923108, 923109, 923110];

    private static JsonObject MegaSettings(string type = "MEGA", string mode = "live") => new()
    {
        ["mode"] = mode,
        ["total_quizzes"] = "2",
        ["quiz_type"] = type,
        ["response_range"] = "A2:C",
        ["response_token_column"] = "1",
        ["response_score_column"] = "2",
        ["responses_sheet_id"] = Responses,
        ["scores_sheet_id"] = Public,
        ["scores_range"] = "Scoreboard!A2",
        ["updatedon_range"] = "Scoreboard!A1",
        ["winners_range"] = "Winners!A2",
        ["mega_winner_range"] = "Mega!A2",
        ["mega_student_winner_range"] = "MegaStudent!A2",
        ["daily_winner_counts"] = "1,1",
        ["winner_labels"] = "First,Second",
        ["min_score_percent"] = "50",
        ["mega_winner_minimum_count"] = "1",
        ["excluded_countries"] = "Pakistan",
        ["excluded_tokens"] = "923105",
        ["quiz_title"] = "Test Quiz",
        ["quiz_series"] = "S1",
        ["quiz_registration"] = "1 Dec",
        ["episodes"] = new JsonObject
        {
            ["1"] = new JsonObject { ["start"] = "10 Dec", ["stop"] = "11 Dec" },
            ["2"] = new JsonObject { ["start"] = "12 Dec", ["stop"] = "13 Dec" },
        },
    };

    private async Task SeedQuizWorldAsync(JsonObject? settings = null, bool answers = true)
    {
        foreach (var token in QuizMembers)
        {
            await MembershipTestKit.AddMemberAsync(token, "Sheet Name " + token, "1");
        }

        await TestDatabase.ExecuteAsync(
            "update membership.member_profiles set city = 'mumbai', country = 'india', mobile = '+910000' || (select token from identity.users u where u.id = user_id) where user_id in (select id from identity.users where token between 923101 and 923110); "
            + "update membership.member_profiles set country = 'Pakistan' where user_id = (select id from identity.users where token = 923106); "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, city) values "
            + "(98301, 'SH-1', 1, 'shlnk1', 'Sh One', 3, 923001, 1, 'Offline', 'A', 923001, 'Shville'), (98302, 'SH-2', 1, 'shlnk2', 'Sh Closed', 3, 923001, 1, 'Offline', 'I', 923001, 'Shville'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin, status, removed_at) values "
            + "(98301, 923108, current_date, 0, 'A', null), (98302, 923107, current_date, 0, 'A', null), (98301, 923109, current_date, 0, 'I', '2026-01-01')");
        await PutDocAsync("settings", settings ?? MegaSettings());
        if (answers)
        {
            sheets.Set(Responses, "Form Responses 1!A2:C", Row(923101, "9 / 10"), Row(923101, "0 / 10"), Row(923102, "8 / 10"), Row(923103, "3 / 10"), Row(923107, "5 / 10"), Row(923108, "10 / 10"), Row(923105, "9 / 10"), Row(923106, "9 / 10"), Row(999999, "9 / 10"));
            sheets.Set(Responses, "Form Responses 2!A2:C", Row(923101, "9 / 10"), Row(923104, "7 / 10"), Row(923109, "6 / 10"), Row(923110, "2 / 10"), Row(923105, "9 / 10"));
        }
    }

    private static string[] Row(int token, string score) => ["12/2/2026 10:00:00", token.ToString(CultureInfo.InvariantCulture), score];

    private async Task<MembershipTestKit.Reply> DownloadAsync() => await Post(Admin, "/admin/quiz/download");

    private async Task DrawAllAsync()
    {
        Assert.That((await DownloadAsync()).Status, Is.EqualTo(HttpStatusCode.OK));
        foreach (var kind in Of("daily", "mega", "mega_student"))
        {
            var reply = await Post(Admin, "/admin/quiz/winners/generate", $$"""{"kind":"{{kind}}"}""");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), kind + " " + reply.Body);
        }
    }

    private static int[] Tokens(JsonNode? winners) => [.. winners!.AsArray().Select(w => w!["token"]!.GetValue<int>())];

    // ---------------------------------------------------------------- refresh

    private static void SetSettingsSheet(FakeSheets fake, string mode)
    {
        fake.Set(SettingsSheet, "Technical!A1:B", ["mode", mode], ["total_quizzes", "2"], ["quiz_type", "MEGA"], ["quiz_title", "Test Quiz"], ["quiz_series", "S1"], ["quiz_registration", "1 Dec"], ["excluded", "a", "b"]);
        fake.Set(SettingsSheet, "Functional!A1:D", ["episodes", "start", "stop"], ["1", "10 Dec", "11 Dec"], ["2", "12 Dec", "13 Dec"], ["quiz_stop", "20 Dec"]);
    }

    [Test]
    public async Task A_refresh_stores_the_settings_with_PHPs_table_shapes_and_writes_one_event_and_no_announcement_for_a_first_load()
    {
        SetSettingsSheet(sheets, "live");

        var reply = await Post(Admin, "/admin/quiz/settings/refresh");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["outcome"]!.GetValue<string>(), Is.EqualTo("complete"));
        Assert.That(reply.Json["settings"]!["title"]!.GetValue<string>(), Is.EqualTo("Test Quiz"));
        Assert.That(reply.Json["settings"]!["episodes"]!.AsArray().Count, Is.EqualTo(2));
        var settings = (await DocAsync("settings"))!;
        Assert.That(settings["mode"]!.GetValue<string>(), Is.EqualTo("live"));
        Assert.That(settings["excluded"]!.AsArray().Select(c => c!.GetValue<string>()), Is.EqualTo(Of("a", "b")));
        Assert.That(settings["episodes"]!["2"]!["stop"]!.GetValue<string>(), Is.EqualTo("13 Dec"));
        Assert.That(settings["quiz_stop"]!.GetValue<string>(), Is.EqualTo("20 Dec"));
        Assert.That(sheets.Reads, Is.EqualTo(Of(SettingsSheet + "|Technical!A1:B", SettingsSheet + "|Functional!A1:D")));
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(1));
        Assert.That((await OnlyEventPayloadAsync("assessment.quiz_state_changed"))["action"]!.GetValue<string>(), Is.EqualTo("settings_refresh"));
        Assert.That(await CountAsync("notifications.notifications"), Is.Zero, "a document that never held a mode announces nothing");
    }

    [Test]
    public async Task A_refresh_that_cannot_read_either_tab_changes_nothing_and_writes_no_event()
    {
        SetSettingsSheet(sheets, "live");
        sheets.FailReads.Add(SettingsSheet + "|Functional!A1:D");
        await PutDocAsync("settings", new JsonObject { ["mode"] = "offline", ["total_quizzes"] = "7" });

        var reply = await Post(Admin, "/admin/quiz/settings/refresh");

        Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.BadGateway, "The settings sheet could not be read. The settings are unchanged.")));
        Assert.That((await DocAsync("settings"))!["total_quizzes"]!.GetValue<string>(), Is.EqualTo("7"));
        Assert.That(await AllEventsAsync(), Is.Zero);
    }

    [Test]
    public async Task A_refresh_with_no_settings_sheet_configured_creates_an_empty_document_and_changes_nothing_else()
    {
        using var bare = new MembershipTestKit(services => services.AddSingleton<ISheets>(sheets));

        var reply = await bare.SendAsync(Admin, HttpMethod.Post, "/admin/quiz/settings/refresh", "{}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.BadGateway));
        Assert.That((await DocAsync("settings"))!.AsObject(), Is.Empty);
        Assert.That(sheets.Reads, Is.Empty);
        Assert.That(await AllEventsAsync(), Is.Zero);
    }

    private static async Task SeedDevicesAsync()
    {
        foreach (var token in Of(923101, 923102))
        {
            if (await CountAsync("identity.users", $"token = {token}") == 0)
            {
                await MembershipTestKit.AddMemberAsync(token, "Sheet Name " + token, "1");
            }
        }

        await TestDatabase.ExecuteAsync(
            "insert into notifications.user_devices (token, device_id) values (923101, 'device-a'), (923101, 'device-b'), (923102, 'device-c')");
    }

    [Test]
    public async Task Going_from_not_live_to_live_announces_once_one_inbox_row_fan_out_rows_and_one_queued_push_per_device_and_a_repeat_adds_nothing()
    {
        await SeedDevicesAsync();
        await PutDocAsync("settings", new JsonObject { ["mode"] = "offline" });
        SetSettingsSheet(sheets, "live");

        var first = await Post(Admin, "/admin/quiz/settings/refresh");

        Assert.That(first.Status, Is.EqualTo(HttpStatusCode.OK), first.Body);
        Assert.That(await CountAsync("notifications.notifications"), Is.EqualTo(1));
        var note = (await TestDatabase.RowAsync("select title, body, action_link, device_count from notifications.notifications"))!;
        Assert.That((note["title"], note["body"], note["action_link"], note["device_count"]), Is.EqualTo(("Test Quiz", "Mega Quiz: registration opens 1 Dec, starts 10 Dec.", "/home/quiz", "3")));
        Assert.That(await CountAsync("notifications.user_notifications"), Is.EqualTo(2), "one inbox row per member with a device");
        Assert.That(await CountAsync("platform.outbound_messages", "channel = 'push' and status = 'queued'"), Is.EqualTo(3), "one push per device");
        Assert.That(await CountAsync("platform.outbound_messages", "dedupe_key like 'quiz-announce:S1:Test Quiz:10 Dec:%'"), Is.EqualTo(3));
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(1));

        await PutDocAsync("settings", new JsonObject { ["mode"] = "offline" });
        var again = await Post(Admin, "/admin/quiz/settings/refresh");

        Assert.That(again.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await CountAsync("notifications.notifications"), Is.EqualTo(1), "the inbox copy is found again");
        Assert.That(await CountAsync("platform.outbound_messages"), Is.EqualTo(3), "the dedupe keys refuse a second push");
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(2), "still one event per change");

        var stillLive = await Post(Admin, "/admin/quiz/settings/refresh");
        Assert.That(stillLive.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await CountAsync("platform.outbound_messages"), Is.EqualTo(3), "live to live announces nothing");
    }

    [Test]
    public async Task A_failing_announcement_never_fails_the_refresh_and_leaves_no_partial_rows()
    {
        await SeedDevicesAsync();
        await PutDocAsync("settings", new JsonObject { ["mode"] = "offline" });
        SetSettingsSheet(sheets, "live");
        await TestDatabase.ExecuteAsync(
            "create function public.sh_fail() returns trigger language plpgsql as $$ begin raise exception 'sheets test: refused'; end $$; "
            + "create trigger sh_fail before insert on platform.outbound_messages for each row execute function public.sh_fail()");
        try
        {
            var reply = await Post(Admin, "/admin/quiz/settings/refresh");

            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
            Assert.That((await DocAsync("settings"))!["mode"]!.GetValue<string>(), Is.EqualTo("live"), "the settings were saved");
            Assert.That(await CountAsync("notifications.notifications"), Is.Zero, "the savepoint rolled the announcement back");
            Assert.That(await CountAsync("platform.outbound_messages"), Is.Zero);
            Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(1));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("drop trigger sh_fail on platform.outbound_messages; drop function public.sh_fail()");
        }
    }

    // ---------------------------------------------------------------- download and the overview

    [Test]
    public async Task A_download_stores_the_participants_the_day_the_stamps_and_a_scoreboard_sorted_by_token_and_writes_one_event()
    {
        await SeedQuizWorldAsync();

        var reply = await DownloadAsync();

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["quiz_day"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(reply.Json["message"]!.GetValue<string>(), Is.EqualTo("Downloaded the submissions. Quiz day 2."));
        Assert.That(reply.Json["submissions"]!.AsArray().Select(s => s!["submissions"]!.GetValue<int>()), Is.EqualTo(Of(9, 5)));
        Assert.That(sheets.Reads, Is.EqualTo(Of(Responses + "|Form Responses 1!A2:C", Responses + "|Form Responses 2!A2:C")));
        var participants = (await DocAsync("participants"))!;
        Assert.That(participants["1"]!.AsArray().Count, Is.EqualTo(9));
        Assert.That(participants["1"]![0]!["token"]!.GetValue<string>(), Is.EqualTo("923101"));
        Assert.That(participants["2"]![4]!["score"]!.GetValue<string>(), Is.EqualTo("9 / 10"));
        Assert.That((await DocAsync("quiz_day"))!.GetValue<int>(), Is.EqualTo(2));
        var stamps = (await DocAsync("timestamps"))!;
        Assert.That(stamps["scoreboard_downloaded_by"]!.GetValue<string>(), Is.EqualTo("Sheet Admin (923001)"));
        Assert.That(stamps["last_run"]!.GetValue<string>(), Is.EqualTo("2026-12-02T12:00:00+05:30"), "the wall clock is IST");
        Assert.That(stamps["scoreboard_generated_at"]!.GetValue<string>(), Is.EqualTo("2026-12-02T12:00:00+05:30"));
        Assert.That(stamps["download_summary"]!["completed_days"]!.GetValue<int>(), Is.EqualTo(2));
        var board = (await DocAsync("scoreboard"))!.AsArray();
        Assert.That(board.Select(r => r![1]!.GetValue<int>()), Is.EqualTo(Of(923101, 923102, 923103, 923104, 923105, 923107, 923108, 923109, 923110)), "no unknown member, no excluded country; the excluded token stays");
        Assert.That(board[0]!.AsArray().Select(c => c!.ToJsonString()), Is.EqualTo(Of("1", "923101", "\"Sheet Name 923101\"", "\"Mumbai, India\"", "\"9 / 10\"", "\"9 / 10\"")));
        Assert.That(board[2]![5]!.GetValue<string>(), Is.Empty, "923103 answered one episode only");
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_download_that_cannot_read_an_episode_names_it_and_changes_nothing()
    {
        await SeedQuizWorldAsync();
        sheets.FailReads.Add(Responses + "|Form Responses 2!A2:C");
        await PutDocAsync("quiz_day", JsonValue.Create(1)!);

        var reply = await DownloadAsync();

        Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.BadGateway, "Episode 2 could not be read from the sheet. Nothing was changed.")));
        Assert.That(await DocAsync("participants"), Is.Null);
        Assert.That(await DocAsync("scoreboard"), Is.Null);
        Assert.That(await DocAsync("timestamps"), Is.Null);
        Assert.That((await DocAsync("quiz_day"))!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(await AllEventsAsync(), Is.Zero);
    }

    [Test]
    public async Task Quiz_day_zero_saves_only_the_participants_the_day_and_the_timestamps()
    {
        await SeedQuizWorldAsync(answers: false);

        var reply = await DownloadAsync();

        Assert.That(reply.Json!["quiz_day"]!.GetValue<int>(), Is.Zero);
        Assert.That(reply.Json["message"]!.GetValue<string>(), Is.EqualTo("Downloaded the submissions. No episode has started yet."));
        Assert.That(await DocAsync("participants"), Is.Not.Null);
        Assert.That((await DocAsync("quiz_day"))!.GetValue<int>(), Is.Zero);
        var stamps = (await DocAsync("timestamps"))!;
        Assert.That(stamps["last_run"], Is.Not.Null);
        Assert.That(stamps["last_validated"], Is.Null);
        Assert.That(stamps["scoreboard_generated_at"], Is.Null);
        Assert.That(await DocAsync("scoreboard"), Is.Null);
    }

    [Test]
    public async Task A_Mega_quiz_honours_today_override_for_its_stamps_and_a_Grand_quiz_does_not()
    {
        var mega = MegaSettings();
        mega["today_override"] = "2026-12-05";
        await SeedQuizWorldAsync(mega);
        await DownloadAsync();
        Assert.That((await DocAsync("timestamps"))!["last_run"]!.GetValue<string>(), Is.EqualTo("2026-12-05T00:00:00+00:00"));

        var grand = MegaSettings("Grand");
        grand["today_override"] = "2026-12-05";
        await PutDocAsync("settings", grand);
        await TestDatabase.ExecuteAsync("delete from assessment.quiz_state where name <> 'settings'");
        await DownloadAsync();
        Assert.That((await DocAsync("timestamps"))!["last_run"]!.GetValue<string>(), Is.EqualTo("2026-12-02T12:00:00+05:30"));
    }

    [Test]
    public async Task The_overview_shows_the_eligibility_funnel_and_gates_and_never_a_sheet_id_a_token_list_or_the_replaced_record()
    {
        await SeedQuizWorldAsync();
        await DownloadAsync();
        await PutDocAsync("winners_replaced", new JsonArray(new JsonObject { ["kind"] = "daily", ["winners"] = new JsonArray(new JsonObject { ["token"] = 923199 }) }));

        var plain = await kit.SendAsync(Admin, HttpMethod.Get, "/admin/quiz");
        var noReset = await kit.SendAsync(AdminNoReset, HttpMethod.Get, "/admin/quiz");

        Assert.That(plain.Status, Is.EqualTo(HttpStatusCode.OK), plain.Body);
        var eligibility = plain.Json!["eligibility"]!.AsArray();
        Assert.That(eligibility.Select(e => (e!["submitted"]!.GetValue<int>(), e["after_dedup"]!.GetValue<int>(), e["members"]!.GetValue<int>(), e["country_allowed"]!.GetValue<int>(), e["not_excluded"]!.GetValue<int>(), e["passing"]!.GetValue<int>())),
            Is.EqualTo(Of((9, 8, 7, 6, 5, 4), (5, 5, 5, 5, 4, 3))));
        Assert.That(eligibility.Select(e => e!["needed"]!.GetValue<int>()), Is.EqualTo(Of(2, 2)));
        Assert.That(plain.Json["quiz_day"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(plain.Json["gates"]!["generate"]!["allowed"]!.GetValue<bool>(), Is.True);
        Assert.That(plain.Json["can_reset"]!.GetValue<bool>(), Is.True);
        Assert.That(noReset.Json!["can_reset"]!.GetValue<bool>(), Is.False);
        foreach (var text in Of(Responses, Public, "923199", "winners_replaced", "excluded_tokens", "excluded_countries", "Pakistan", "sheet_id"))
        {
            Assert.That(plain.Body, Does.Not.Contain(text), text);
        }
    }

    // ---------------------------------------------------------------- draws

    [Test]
    public async Task The_daily_draw_gives_nobody_two_prizes_saves_winners_and_stamps_and_a_second_run_draws_nothing()
    {
        await SeedQuizWorldAsync();
        await DownloadAsync();

        var reply = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"daily"}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That((reply.Json!["outcome"]!.GetValue<string>(), reply.Json["drawn"]!.GetValue<int>(), reply.Json["missing"]!.GetValue<int>(), reply.Json["changed"]!.GetValue<bool>()), Is.EqualTo(("complete", 4, 0, true)));
        var winners = (await DocAsync("winners"))!;
        Assert.That(Tokens(winners["1"]), Is.EqualTo(Of(923101, 923102)));
        Assert.That(Tokens(winners["2"]), Is.EqualTo(Of(923104, 923109)));
        Assert.That(Tokens(winners["1"]).Concat(Tokens(winners["2"])).Distinct().Count(), Is.EqualTo(4), "nobody wins twice");
        Assert.That(winners["1"]![0]!["name"]!.GetValue<string>(), Is.EqualTo("Sheet Name 923101"));
        var stamps = (await DocAsync("timestamps"))!;
        Assert.That(stamps["winners_generated_by"]!.GetValue<string>(), Is.EqualTo("Sheet Admin (923001)"));
        Assert.That(stamps["min_score_percent_used"]!.GetValue<int>(), Is.EqualTo(50));
        Assert.That(await DocAsync("winners_replaced"), Is.Null, "a first draw replaces nothing");
        var events = await EventsAsync("assessment.quiz_state_changed");

        var again = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"daily"}""");

        Assert.That(again.Json!["changed"]!.GetValue<bool>(), Is.False);
        Assert.That(again.Json["message"]!.GetValue<string>(), Is.EqualTo("Nothing needed drawing."));
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(events), "a draw that changed nothing writes no event");
    }

    [Test]
    public async Task The_Mega_winner_needs_every_episode_drawn_and_the_TSR_student_pool_is_enrolled_students_only()
    {
        await SeedQuizWorldAsync();
        await DownloadAsync();

        var early = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"mega"}""");
        Assert.That(early.Status, Is.EqualTo(HttpStatusCode.Conflict), early.Body);
        Assert.That(early.Detail, Does.Contain("needs winners for every episode first"));
        Assert.That(await DocAsync("winners"), Is.Null);

        await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"daily"}""");
        var mega = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"mega"}""");
        var student = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"mega_student"}""");

        Assert.That(mega.Status, Is.EqualTo(HttpStatusCode.OK), mega.Body);
        Assert.That(student.Status, Is.EqualTo(HttpStatusCode.OK), student.Body);
        var winners = (await DocAsync("winners"))!;
        Assert.That(winners["mega"]!["token"]!.GetValue<int>(), Is.EqualTo(923107), "someone who won no daily prize");
        Assert.That(winners["mega"]!["episode"]!.GetValue<string>(), Is.EqualTo("MEGA"));
        Assert.That(winners["mega_student"]!["token"]!.GetValue<int>(), Is.EqualTo(923108), "923107 is in a closed class and 923109 was removed: only 923108 is a student");
    }

    [Test]
    public async Task A_regenerate_archives_the_replaced_winners_first_and_redraws_and_an_empty_redraw_changes_nothing()
    {
        await SeedQuizWorldAsync();
        await DrawAllAsync();
        var before = (await DocAsync("winners"))!.ToJsonString();

        var reply = await Post(Admin, "/admin/quiz/winners/regenerate", """{"kind":"daily"}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var record = (await DocAsync("winners_replaced"))!.AsArray();
        Assert.That(record.Count, Is.EqualTo(1), "a daily reset redraws the current episode only");
        Assert.That((record[0]!["kind"]!.GetValue<string>(), record[0]!["episode"]!.GetValue<int>(), record[0]!["by"]!.GetValue<string>()), Is.EqualTo(("daily", 2, "Sheet Admin (923001)")));
        Assert.That(Tokens(record[0]!["winners"]), Is.EqualTo(Of(923104, 923109)));
        var stamps = (await DocAsync("timestamps"))!;
        Assert.That(stamps["winners_reset_at"], Is.Not.Null);

        await TestDatabase.ExecuteAsync("delete from assessment.quiz_state where name = 'participants'");
        await PutDocAsync("participants", new JsonObject { ["1"] = new JsonArray(), ["2"] = new JsonArray() });
        var after = (await DocAsync("winners"))!.ToJsonString();
        var blocked = await Post(Admin, "/admin/quiz/winners/regenerate", """{"kind":"daily"}""");

        Assert.That(blocked.Status, Is.EqualTo(HttpStatusCode.Conflict), blocked.Body);
        Assert.That((await DocAsync("winners"))!.ToJsonString(), Is.EqualTo(after), "a blocked draw changes nothing");
        Assert.That((await DocAsync("winners_replaced"))!.AsArray().Count, Is.EqualTo(1), "and archives nothing");
        Assert.That(before, Is.Not.Empty);
    }

    [Test]
    public async Task A_Grand_quiz_refuses_the_daily_draw_and_a_Mega_quiz_refuses_the_grand_one_with_404()
    {
        await SeedQuizWorldAsync(MegaSettings("Grand"));
        await DownloadAsync();
        var daily = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"daily"}""");
        var mega = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"mega"}""");
        var grand = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"grand"}""");

        Assert.That((daily.Status, daily.Detail), Is.EqualTo((HttpStatusCode.NotFound, "This quiz has no daily draw.")));
        Assert.That(mega.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(grand.Status, Is.EqualTo(HttpStatusCode.OK), grand.Body);

        await PutDocAsync("settings", MegaSettings());
        var wrong = await Post(Admin, "/admin/quiz/winners/generate", """{"kind":"grand"}""");
        Assert.That((wrong.Status, wrong.Detail), Is.EqualTo((HttpStatusCode.NotFound, "This quiz has no grand draw.")));
    }

    // ---------------------------------------------------------------- publish

    [Test]
    public async Task Publish_writes_the_scoreboard_the_updated_on_line_the_winners_and_the_Mega_rows_and_saves_stamps_and_events()
    {
        await SeedQuizWorldAsync();
        await DrawAllAsync();
        var events = await EventsAsync("assessment.quiz_state_changed");

        var board = await Post(Admin, "/admin/quiz/publish", """{"what":"scoreboard"}""");
        var daily = await Post(Admin, "/admin/quiz/publish", """{"what":"winners"}""");
        var mega = await Post(Admin, "/admin/quiz/publish", """{"what":"mega"}""");
        var student = await Post(Admin, "/admin/quiz/publish", """{"what":"mega_student"}""");

        Assert.That(board.Json!["message"]!.GetValue<string>(), Is.EqualTo("Published 9 rows."));
        Assert.That(daily.Json!["rows"]!.GetValue<int>(), Is.EqualTo(4));
        Assert.That(mega.Json!["message"]!.GetValue<string>(), Is.EqualTo("Published 1 row."));
        Assert.That(student.Json!["rows"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(sheets.Writes.Select(w => w.Key), Is.EqualTo(Of(Public + "|Scoreboard!A2", Public + "|Scoreboard!A1", Public + "|Winners!A2", Public + "|Mega!A2", Public + "|MegaStudent!A2")));
        Assert.That(sheets.Writes[0].Rows.Count, Is.EqualTo(9));
        Assert.That(sheets.Writes[0].Rows[0].Select(c => c?.ToString()), Is.EqualTo(Of("1", "923101", "Sheet Name 923101", "Mumbai, India", "9 / 10", "9 / 10")));
        Assert.That(sheets.Writes[1].Rows[0][0], Is.EqualTo("Last updated on 02-December-2026 12:00 PM IST"));
        Assert.That(sheets.Writes[2].Rows[0], Is.EqualTo(Of<object?>(1L, "First", 923101L, "Sheet Name 923101", "Mumbai, India")));
        Assert.That(sheets.Writes[2].Rows[3][1], Is.EqualTo("Second"));
        Assert.That(sheets.Writes[3].Rows[0], Is.EqualTo(Of<object?>("MEGA", "MEGA", 923107L, "Sheet Name 923107", "Mumbai, India")));
        var stamps = (await DocAsync("timestamps"))!;
        foreach (var prefix in Of("scoreboard_updated", "winners_updated", "mega_winner_updated", "mega_student_winner_updated"))
        {
            Assert.That(stamps[prefix + "_by"]!.GetValue<string>(), Is.EqualTo("Sheet Admin (923001)"), prefix);
        }

        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(events + 4), "one event per publish");
    }

    [Test]
    public async Task A_publish_that_fails_on_the_second_scoreboard_write_says_so_and_saves_no_stamp_and_no_event()
    {
        await SeedQuizWorldAsync();
        await DownloadAsync();
        var events = await EventsAsync("assessment.quiz_state_changed");
        sheets.FailWrites.Add(Public + "|Scoreboard!A1");

        var partly = await Post(Admin, "/admin/quiz/publish", """{"what":"scoreboard"}""");

        Assert.That((partly.Status, partly.Detail), Is.EqualTo((HttpStatusCode.BadGateway, "The scoreboard was published but its \"last updated\" line was not. Publish again to finish.")));
        Assert.That(sheets.Writes.Select(w => w.Key), Is.EqualTo(Of(Public + "|Scoreboard!A2")));
        Assert.That((await DocAsync("timestamps"))!["scoreboard_updated_at"], Is.Null);
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(events));

        sheets.FailWrites.Clear();
        sheets.FailWrites.Add(Public + "|Scoreboard!A2");
        var whole = await Post(Admin, "/admin/quiz/publish", """{"what":"scoreboard"}""");
        Assert.That((whole.Status, whole.Detail), Is.EqualTo((HttpStatusCode.BadGateway, "The sheet could not be reached. Nothing was changed or published.")));
    }

    [Test]
    public async Task Publish_refuses_a_Grand_quiz_and_a_winner_that_was_not_drawn_and_a_student_range_that_is_not_set_publishes_nothing()
    {
        await SeedQuizWorldAsync(MegaSettings("Grand"));
        var grand = await Post(Admin, "/admin/quiz/publish", """{"what":"winners"}""");
        Assert.That((grand.Status, grand.Detail), Is.EqualTo((HttpStatusCode.NotFound, "This quiz has nothing to publish from here.")));

        var settings = MegaSettings();
        settings["mega_student_winner_range"] = " ";
        await PutDocAsync("settings", settings);
        var none = await Post(Admin, "/admin/quiz/publish", """{"what":"mega"}""");
        Assert.That((none.Status, none.Detail), Is.EqualTo((HttpStatusCode.Conflict, "No overall Mega winner has been drawn yet, so there is nothing to publish.")));
        var noStudent = await Post(Admin, "/admin/quiz/publish", """{"what":"mega_student"}""");
        Assert.That((noStudent.Json!["rows"]!.GetValue<int>(), noStudent.Json["changed"]!.GetValue<bool>()), Is.EqualTo((0, false)));
        Assert.That(sheets.Writes, Is.Empty);
        Assert.That(await AllEventsAsync(), Is.Zero);

        await PutDocAsync("settings", MegaSettings());
        var noStudentWinner = await Post(Admin, "/admin/quiz/publish", """{"what":"mega_student"}""");
        Assert.That(noStudentWinner.Detail, Is.EqualTo("No TSR student Mega winner has been drawn yet, so there is nothing to publish."));
    }

    // ---------------------------------------------------------------- reset

    [Test]
    public async Task A_reset_archives_every_winner_as_delete_all_clears_the_five_cycle_documents_and_keeps_the_settings_and_the_record()
    {
        await SeedQuizWorldAsync();
        await DrawAllAsync();
        await Post(Admin, "/admin/quiz/winners/regenerate", """{"kind":"daily"}""");
        var recorded = (await DocAsync("winners_replaced"))!.AsArray().Count;
        var events = await EventsAsync("assessment.quiz_state_changed");

        var reply = await Post(Admin, "/admin/quiz/reset");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        foreach (var name in Of("scoreboard", "quiz_day", "timestamps", "winners", "participants"))
        {
            Assert.That(await DocAsync(name), Is.Null, name);
        }

        Assert.That(await DocAsync("settings"), Is.Not.Null);
        var record = (await DocAsync("winners_replaced"))!.AsArray();
        Assert.That(record.Count, Is.EqualTo(recorded + 4), "episodes 1 and 2, mega and mega_student");
        var deleted = record.Skip(recorded).Select(r => r!).ToList();
        Assert.That(deleted.All(r => r["kind"]!.GetValue<string>() == "delete_all"));
        Assert.That(deleted.Select(r => r["episode"]!.ToJsonString()), Is.EqualTo(Of("1", "2", "\"mega\"", "\"mega_student\"")));
        Assert.That(Tokens(deleted[2]["winners"]), Is.EqualTo(Of(923107)), "a Mega winner is archived as a one-element list");
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(events + 1));
    }

    [Test]
    public async Task A_reset_without_quiz_reset_or_without_quiz_admin_deletes_nothing_and_writes_no_event()
    {
        await SeedQuizWorldAsync();
        await DrawAllAsync();
        var events = await AllEventsAsync();

        var noReset = await Post(AdminNoReset, "/admin/quiz/reset");
        var neither = await Post(McqEditor, "/admin/quiz/reset");
        await Grant(Nobody, "quiz:reset:all");
        var resetOnly = await Post(Nobody, "/admin/quiz/reset");

        Assert.That((noReset.Status, noReset.Detail), Is.EqualTo((HttpStatusCode.Forbidden, "Deleting all quiz data needs the quiz reset permission.")));
        Assert.That((neither.Status, neither.Detail), Is.EqualTo((HttpStatusCode.Forbidden, "You do not have permission to do that")));
        Assert.That(resetOnly.Detail, Is.EqualTo("You do not have permission to do that"), "quiz:reset alone is not quiz:admin");
        Assert.That(await DocAsync("winners"), Is.Not.Null);
        Assert.That(await AllEventsAsync(), Is.EqualTo(events));
    }

    // ---------------------------------------------------------------- locks

    [Test]
    public async Task While_another_session_holds_the_quiz_admin_lock_every_action_is_409_and_changes_nothing()
    {
        await SeedQuizWorldAsync();
        await DrawAllAsync();
        SetSettingsSheet(sheets, "live");
        var events = await AllEventsAsync();
        var reads = sheets.Reads.Count;
        var docs = await CountAsync("assessment.quiz_state");

        await using (await HoldLockAsync(5002))
        {
            foreach (var (path, body) in new[]
            {
                ("/admin/quiz/settings/refresh", "{}"), ("/admin/quiz/download", "{}"), ("/admin/quiz/winners/generate", """{"kind":"daily"}"""),
                ("/admin/quiz/winners/regenerate", """{"kind":"daily"}"""), ("/admin/quiz/publish", """{"what":"winners"}"""), ("/admin/quiz/reset", "{}"),
            })
            {
                var reply = await Post(Admin, path, body);
                Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.Conflict, Busy)), path);
            }

            Assert.That((await kit.SendAsync(Admin, HttpMethod.Get, "/admin/quiz")).Status, Is.EqualTo(HttpStatusCode.OK), "reads take no lock");
        }

        Assert.That(await AllEventsAsync(), Is.EqualTo(events));
        Assert.That(sheets.Reads, Has.Count.EqualTo(reads), "no sheet was read");
        Assert.That(sheets.Writes, Is.Empty);
        Assert.That(await CountAsync("assessment.quiz_state"), Is.EqualTo(docs));
    }

    [Test]
    public async Task Two_simultaneous_downloads_one_runs_and_the_other_gets_409()
    {
        await SeedQuizWorldAsync();
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        sheets.OnRead = _ => release.Task;

        var first = DownloadAsync();
        await sheets.ReadStarted.Task.WaitAsync(TimeSpan.FromSeconds(30));
        var second = await DownloadAsync();
        release.SetResult();
        var firstReply = await first;

        Assert.That((second.Status, second.Detail), Is.EqualTo((HttpStatusCode.Conflict, Busy)));
        Assert.That(firstReply.Status, Is.EqualTo(HttpStatusCode.OK), firstReply.Body);
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.EqualTo(1));
    }

    // ---------------------------------------------------------------- privacy

    [Test]
    public async Task Member_data_from_the_sheets_is_in_the_state_documents_and_responses_only_never_in_an_event_a_queued_message_or_a_log_line()
    {
        await SeedQuizWorldAsync();
        await SeedDevicesAsync();
        await PutDocAsync("settings", new JsonObject { ["mode"] = "offline" });
        SetSettingsSheet(sheets, "live");
        await Post(Admin, "/admin/quiz/settings/refresh");
        await PutDocAsync("settings", MegaSettings());
        await DrawAllAsync();
        await Post(Admin, "/admin/quiz/publish", """{"what":"winners"}""");
        sheets.FailWrites.Add(Public + "|Mega!A2");
        await Post(Admin, "/admin/quiz/publish", """{"what":"mega"}""");
        sheets.FailReads.Add(Responses + "|Form Responses 2!A2:C");
        await DownloadAsync();
        await Post(Admin, "/admin/quiz/reset");

        var haystacks = new List<string>(logs.Lines);
        haystacks.AddRange((await AllTextAsync("select payload::text as t from platform.outbox")));
        haystacks.AddRange((await AllTextAsync("select payload::text as t from platform.outbound_messages")));
        haystacks.AddRange((await AllTextAsync("select title || ' ' || body as t from notifications.notifications")));
        Assert.That(haystacks, Is.Not.Empty);
        foreach (var token in QuizMembers)
        {
            foreach (var secret in Of(token.ToString(CultureInfo.InvariantCulture), "Sheet Name " + token, "+910000" + token))
            {
                Assert.That(haystacks.Where(h => h.Contains(secret, StringComparison.Ordinal)), Is.Empty, secret);
            }
        }
    }

    private static async Task<List<string>> AllTextAsync(string sql)
    {
        var rows = new List<string>();
        await using var connection = new Npgsql.NpgsqlConnection(TestDatabase.OwnerConnection);
        await connection.OpenAsync();
        await using var command = new Npgsql.NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            rows.Add(reader.GetString(0));
        }

        return rows;
    }
}
