using System.Net;
using System.Text.Json.Nodes;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// GET /quiz/info (the Grand/Mega status the app's home banner reads) in <see cref="TestSheetsTests"/>' world: the clock is fixed at 2026-12-02 12:00 IST, the settings sheet is the fake, members 923001 (quiz:admin) and 923004 (nobody).
/// The saved settings are re-read from the sheet when they are 60 seconds old or more; a busy lock, a failing sheet or one that takes over 5 seconds serves the saved copy.
/// </summary>
public sealed partial class TestSheetsTests
{
    private const string Fresh = "2026-12-02T06:30:00+00:00";

    private static JsonObject InfoSettings(string title = "Info Quiz", string mode = "Live", string extra = "") => (JsonObject)JsonNode.Parse(
        """
        {"mode":"__MODE__","quiz_type":"GRAND","quiz_title":"__TITLE__","quiz_series":"S1","quiz_date":"2 Dec","quiz_registration":"2026-12-01 09:00:00","quiz_stop":"2026-12-03 00:00:00",
            "link_template":"https://forms.invalid/f?usp=pp","excluded_tokens":"923004","episodes":{"1":{"start":"2026-12-02 11:00:00","stop":"2026-12-02 13:00:00","form_id":"FORM1"}}__EXTRA__}
        """
            .Replace("__MODE__", mode, StringComparison.Ordinal).Replace("__TITLE__", title, StringComparison.Ordinal).Replace("__EXTRA__", extra, StringComparison.Ordinal))!;

    /// <summary>Saves the settings as if the API wrote them <paramref name="ageSeconds"/> before the fixed clock.</summary>
    private static Task PutSettingsAsync(JsonObject settings, int ageSeconds = 5) => TestDatabase.ExecuteAsync(
        $"insert into assessment.quiz_state (name, document, updated_at) values ('settings', '{settings.ToJsonString().Replace("'", "''", StringComparison.Ordinal)}'::jsonb, timestamptz '{Fresh}' - interval '{ageSeconds} seconds') "
        + "on conflict (name) do update set document = excluded.document, updated_at = excluded.updated_at");

    private static void SetInfoSheet(FakeSheets fake, string title, string mode = "Live")
    {
        fake.Set(SettingsSheet, "Technical!A1:B", ["mode", mode], ["quiz_type", "GRAND"], ["quiz_title", title], ["quiz_series", "S1"], ["quiz_date", "2 Dec"], ["quiz_registration", "2026-12-01 09:00:00"], ["quiz_stop", "2026-12-03 00:00:00"]);
        fake.Set(SettingsSheet, "Functional!A1:D", ["episodes", "start", "stop", "form_id"], ["1", "2026-12-02 11:00:00", "2026-12-02 13:00:00", "FORM1"]);
    }

    private Task<MembershipTestKit.Reply> Info(int caller) => kit.SendAsync(caller, HttpMethod.Get, "/quiz/info");

    private async Task<MembershipTestKit.RawReply> InfoSignedOutAsync() => await kit.SendRawAsync(null, HttpMethod.Get, "/quiz/info");

    [Test]
    public async Task A_signed_out_caller_gets_the_quiz_as_the_whole_body_with_no_caching_and_no_sheet_read_for_a_fresh_copy()
    {
        await PutSettingsAsync(InfoSettings());

        var reply = await InfoSignedOutAsync();

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.CacheControl, Is.EqualTo("no-store"));
        var body = JsonNode.Parse(reply.Body)!;
        Assert.That((body["type"]!.GetValue<string>(), body["status"]!.GetValue<string>(), body["name"]!.GetValue<string>()), Is.EqualTo(("grand", "live", "Info Quiz")));
        Assert.That(body["episode"]!["participation"], Is.Null);
        Assert.That(body["episode"]!["form_id"]!.GetValue<string>(), Is.EqualTo("FORM1"));
        Assert.That((body["auth"]!["method"]!.GetValue<string>(), body["auth"]!["can_register"]!.GetValue<bool>()), Is.EqualTo(("none", false)));
        Assert.That(body["auth"]!.AsObject().ContainsKey("user_token") && body["auth"]!["user_token"] is null, Is.True, "a null is written, not left out");
        Assert.That(body["episode"]!.AsObject().ContainsKey("participation"), Is.True);
        Assert.That(body["can_take_part"]!.GetValue<bool>(), Is.True);
        Assert.That(sheets.Reads, Is.Empty, "a copy under 60 seconds old is not read again");
    }

    [Test]
    public async Task A_signed_in_member_gets_participation_their_token_and_whether_the_draw_lets_them_take_part_and_a_quiz_admin_sees_a_UAT_quiz()
    {
        await PutSettingsAsync(InfoSettings());

        var member = (await Info(McqEditor)).Json!;
        var excluded = (await Info(Nobody)).Json!;
        await PutSettingsAsync(InfoSettings(mode: "UAT"));
        var uatMember = (await Info(McqEditor)).Json!;
        var uatAdmin = (await Info(Admin)).Json!;

        Assert.That(member["episode"]!["participation"]!["form_base_url"]!.GetValue<string>(), Is.EqualTo("https://forms.invalid/f"));
        Assert.That((member["auth"]!["method"]!.GetValue<string>(), member["auth"]!["can_register"]!.GetValue<bool>(), member["auth"]!["user_token"]!.GetValue<int>()), Is.EqualTo(("firebase", true, McqEditor)));
        Assert.That((member["is_superuser"]!.GetValue<bool>(), member["can_take_part"]!.GetValue<bool>()), Is.EqualTo((false, true)));
        Assert.That(excluded["can_take_part"]!.GetValue<bool>(), Is.False, "token 923004 is excluded by the settings");
        Assert.That(uatMember["status"]!.GetValue<string>(), Is.EqualTo("offline"));
        Assert.That((uatAdmin["type"]!.GetValue<string>(), uatAdmin["is_superuser"]!.GetValue<bool>(), uatAdmin["admin_url"]!.GetValue<string>()), Is.EqualTo(("grand", true, "/score/quiz_admin.php")));
    }

    [Test]
    public async Task A_bad_bearer_or_a_bearer_of_no_member_is_401_authentication_failed_and_no_credentials_is_not_refused()
    {
        await PutSettingsAsync(InfoSettings());

        var invalid = await kit.SendWithOutcomeAsync("invalid", "/quiz/info");
        var noEmail = await kit.SendWithOutcomeAsync("noemail", "/quiz/info");
        var stranger = await Info(999999);

        foreach (var (status, body) in new[] { (invalid.Status, invalid.Body), (noEmail.Status, noEmail.Body), (stranger.Status, stranger.Body) })
        {
            Assert.That(status, Is.EqualTo(HttpStatusCode.Unauthorized));
            Assert.That(JsonNode.Parse(body)!["detail"]!.GetValue<string>(), Is.EqualTo("Authentication failed"));
        }

        Assert.That(await CountAsync("identity.users", "token = 999999"), Is.Zero, "a bearer never creates a member here");
    }

    [Test]
    public async Task A_copy_of_60_seconds_or_more_is_read_again_saved_and_announced_when_the_quiz_went_live()
    {
        await SeedDevicesAsync();
        await PutSettingsAsync(InfoSettings(mode: "offline"), ageSeconds: 60);
        SetInfoSheet(sheets, "Fresh Title");

        var reply = await InfoSignedOutAsync();

        Assert.That(JsonNode.Parse(reply.Body)!["name"]!.GetValue<string>(), Is.EqualTo("Fresh Title"));
        Assert.That(sheets.Reads, Is.EqualTo(Of(SettingsSheet + "|Technical!A1:B", SettingsSheet + "|Functional!A1:D")));
        Assert.That((await DocAsync("settings"))!["quiz_title"]!.GetValue<string>(), Is.EqualTo("Fresh Title"));
        Assert.That(await CountAsync("notifications.notifications"), Is.EqualTo(1), "not live to live announces, as the admin refresh does");

        sheets.Reads.Clear();
        await InfoSignedOutAsync();
        Assert.That(sheets.Reads, Is.Empty, "the copy just saved is fresh");
    }

    [Test]
    public async Task A_copy_of_59_seconds_is_not_read_again()
    {
        await PutSettingsAsync(InfoSettings(), ageSeconds: 59);
        SetInfoSheet(sheets, "Other Title");

        var reply = await InfoSignedOutAsync();

        Assert.That(JsonNode.Parse(reply.Body)!["name"]!.GetValue<string>(), Is.EqualTo("Info Quiz"));
        Assert.That(sheets.Reads, Is.Empty);
    }

    [Test]
    public async Task With_no_saved_copy_and_a_sheet_that_cannot_be_read_the_answer_is_offline_and_nothing_is_saved()
    {
        sheets.FailReads.Add(SettingsSheet + "|Technical!A1:B");

        var failed = await InfoSignedOutAsync();

        Assert.That(failed.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(failed.Body, Is.EqualTo("""{"status":"offline","message":"No quiz is currently configured"}"""));
        Assert.That(await CountAsync("assessment.quiz_state", "name = 'settings'"), Is.Zero);
    }

    [Test]
    public async Task With_no_saved_copy_the_sheet_is_read_and_saved_and_a_read_made_for_a_request_writes_no_event()
    {
        SetInfoSheet(sheets, "First Read");

        var read = await InfoSignedOutAsync();

        Assert.That(JsonNode.Parse(read.Body)!["name"]!.GetValue<string>(), Is.EqualTo("First Read"));
        Assert.That(await EventsAsync("assessment.quiz_state_changed"), Is.Zero, "a read made for a request is not an admin action");
    }

    [Test]
    public async Task A_sheet_that_fails_serves_the_saved_copy_logs_it_and_leaves_the_copy_to_be_tried_again()
    {
        await PutSettingsAsync(InfoSettings(), ageSeconds: 600);
        sheets.FailReads.Add(SettingsSheet + "|Functional!A1:D");

        var reply = await InfoSignedOutAsync();

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(JsonNode.Parse(reply.Body)!["name"]!.GetValue<string>(), Is.EqualTo("Info Quiz"));
        Assert.That(logs.Lines, Has.Some.Contains("Quiz settings sheet read failed"));
        Assert.That(await CountAsync("assessment.quiz_state", "name = 'settings' and updated_at < timestamptz '" + Fresh + "' - interval '599 seconds'"), Is.EqualTo(1));
    }

    [Test]
    public async Task After_a_failed_read_the_sheet_is_not_tried_again_for_a_minute_by_requests_but_the_admin_refresh_always_tries()
    {
        await PutSettingsAsync(InfoSettings(), ageSeconds: 600);
        sheets.FailReads.Add(SettingsSheet + "|Technical!A1:B");

        await InfoSignedOutAsync();
        var second = await InfoSignedOutAsync();

        Assert.That(JsonNode.Parse(second.Body)!["name"]!.GetValue<string>(), Is.EqualTo("Info Quiz"));
        Assert.That(sheets.Reads, Is.EqualTo(Of(SettingsSheet + "|Technical!A1:B")), "one failed attempt, not one per request");

        var admin = await Post(Admin, "/admin/quiz/settings/refresh");
        Assert.That(admin.Status, Is.EqualTo(HttpStatusCode.BadGateway));
        Assert.That(sheets.Reads, Has.Count.EqualTo(2), "the admin route always tries");
    }

    [Test]
    public async Task A_refresh_that_holds_the_lock_leaves_the_request_the_saved_copy_without_waiting_or_reading()
    {
        await PutSettingsAsync(InfoSettings(), ageSeconds: 600);
        SetInfoSheet(sheets, "Admin Title");
        var release = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        sheets.OnRead = _ => release.Task;
        var admin = Post(Admin, "/admin/quiz/settings/refresh");
        await sheets.ReadStarted.Task.WaitAsync(TimeSpan.FromSeconds(30));
        var reply = await InfoSignedOutAsync().WaitAsync(TimeSpan.FromSeconds(20));
        var readsWhileBusy = sheets.Reads.ToList();
        release.SetResult();
        await admin;

        Assert.That(JsonNode.Parse(reply.Body)!["name"]!.GetValue<string>(), Is.EqualTo("Info Quiz"));
        Assert.That(readsWhileBusy, Is.EqualTo(Of(SettingsSheet + "|Technical!A1:B")), "only the admin refresh had read; the request read nothing");
    }

    [Test]
    public async Task A_sheet_that_takes_more_than_5_seconds_serves_the_saved_copy()
    {
        await PutSettingsAsync(InfoSettings(), ageSeconds: 600);
        SetInfoSheet(sheets, "Slow Title");
        sheets.OnRead = _ => new TaskCompletionSource().Task;
        var started = System.Diagnostics.Stopwatch.StartNew();

        var reply = await InfoSignedOutAsync().WaitAsync(TimeSpan.FromSeconds(30));

        Assert.That(JsonNode.Parse(reply.Body)!["name"]!.GetValue<string>(), Is.EqualTo("Info Quiz"));
        Assert.That(started.Elapsed, Is.GreaterThan(TimeSpan.FromSeconds(4)).And.LessThan(TimeSpan.FromSeconds(15)));
    }

    [Test]
    public async Task The_61st_request_in_a_minute_from_one_address_is_429_with_a_detail()
    {
        await PutSettingsAsync(InfoSettings());
        for (var i = 0; i < 60; i++)
        {
            Assert.That((await InfoSignedOutAsync()).Status, Is.EqualTo(HttpStatusCode.OK), "request " + i);
        }

        var refused = await InfoSignedOutAsync();

        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.TooManyRequests));
        Assert.That(JsonNode.Parse(refused.Body)!["detail"]!.GetValue<string>(), Is.EqualTo("Too many requests. Please try again later."));
    }
}
