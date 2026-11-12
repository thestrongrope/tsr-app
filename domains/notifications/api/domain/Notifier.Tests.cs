using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using NUnit.Framework;
using Tsr.Notifications.Api.Features.WhatsappLinkQr;
using Tsr.Notifications.Api.Features.WhatsappReminderRun;
using Tsr.Notifications.Api.Features.WhatsappRuns;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Domain;

[TestFixture]
internal sealed class NotifierTests
{
    private sealed class Handler(HttpStatusCode status, string body) : HttpMessageHandler
    {
        public string? Url { get; private set; }

        public string? Sent { get; private set; }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Url = request.Method + " " + request.RequestUri;
            Sent = request.Content is null ? null : await request.Content.ReadAsStringAsync(cancellationToken);
            return new HttpResponseMessage(status) { Content = new StringContent(body) };
        }
    }

    private static Notifier With(Handler handler, string? url = "http://notifier:3000") =>
        new(new HttpClient(handler), Options.Create(new NotifierSettings { Url = url }));

    private static JsonElement Json(string text) => JsonElement.Parse(text);

    [TestCase("http://notifier:3000", true)]
    [TestCase(null, true)]
    [TestCase("", true)]
    [TestCase("notifier:3000", false)]
    [TestCase("ftp://notifier", false)]
    [TestCase("http://notifier:3000/?x=1", false)]
    [TestCase("http://user:pw@notifier:3000", false)]
    public void The_notifier_setting_is_absent_or_an_http_url_without_query_or_user_info(string? url, bool valid) =>
        Assert.That(NotifierSettings.IsValid(url), Is.EqualTo(valid));

    [Test]
    public async Task An_id_is_an_integer_in_the_path_so_it_cannot_steer_the_request()
    {
        var handler = new Handler(HttpStatusCode.OK, "{}");

        await With(handler).RunAsync(NotifierAccess.IdOf("12/../../send"), CancellationToken.None);

        Assert.That(handler.Url, Is.EqualTo("GET http://notifier:3000/runs/12"));
        Assert.That(NotifierAccess.IdOf("../send"), Is.Zero);
    }

    [Test]
    public async Task Only_digits_reach_the_query()
    {
        var handler = new Handler(HttpStatusCode.OK, "[]");

        await With(handler).RecentRunsAsync("5", "7&x=1", CancellationToken.None);

        Assert.That(handler.Url, Is.EqualTo("GET http://notifier:3000/recent-runs?limit=5"));
        Assert.That(WhatsappRunsSlice.Digits("12a"), Is.Null);
        Assert.That(WhatsappRunsSlice.Digits(new string('9', 19)), Is.Null);
    }

    [Test]
    public async Task Without_the_setting_every_call_is_unreachable_and_nothing_is_sent()
    {
        var handler = new Handler(HttpStatusCode.OK, "{}");

        var answer = await With(handler, null).StatusAsync(CancellationToken.None);

        Assert.That(answer, Is.EqualTo(NotifierAnswer.Unreachable));
        Assert.That(handler.Url, Is.Null);
    }

    [Test]
    public async Task A_run_is_sent_with_dry_run_and_the_token_of_the_caller()
    {
        var handler = new Handler(HttpStatusCode.Accepted, "{}");

        await With(handler).RunWeeklyAsync(3, true, 900001, CancellationToken.None);

        Assert.That(handler.Sent, Is.EqualTo("""{"reminder_id":3,"dry_run":true,"triggered_by":900001}"""));
    }

    [TestCase("""{}""", true)]
    [TestCase("""{"dryRun":false}""", false)]
    [TestCase("""{"dryRun":true}""", true)]
    [TestCase("""{"dryRun":null}""", true)]
    [TestCase("""{"dryRun":"false"}""", true)]
    [TestCase("""{"dryRun":0}""", true)]
    [TestCase("""{"dryRun":[false]}""", true)]
    public void A_run_is_a_dry_run_unless_dryRun_is_exactly_false(string body, bool dry) =>
        Assert.That(WhatsappReminderRunSlice.IsDryRun(JsonBody.Parse(Encoding.UTF8.GetBytes(body)).Value!), Is.EqualTo(dry));

    [Test]
    public void A_notifier_refusal_keeps_its_status_and_error_text()
    {
        var (_, refusal) = NotifierAsk.Interpret(new NotifierAnswer(400, """{"error":"gender must be one of gents, ladies"}"""));

        Assert.That(refusal, Is.Not.Null);
        Assert.That(NotifierAsk.Interpret(new NotifierAnswer(200, "[]")).Refusal, Is.Null);
    }

    [Test]
    public void A_qr_code_is_passed_on_only_while_it_is_fresh()
    {
        Assert.That(WhatsappLinkQrSlice.Interpret(new NotifierAnswer(200, """{"qr":"abc","generated_seconds_ago":10}"""))!.Qr, Is.EqualTo("abc"));
        var old = WhatsappLinkQrSlice.Interpret(new NotifierAnswer(200, """{"qr":"abc","generated_seconds_ago":61}"""))!;
        Assert.That(old.Qr, Is.Null);
        Assert.That(old.Stale, Is.True);
        Assert.That(WhatsappLinkQrSlice.Interpret(new NotifierAnswer(200, """{"qr":"abc"}"""))!.Qr, Is.Null);
        Assert.That(WhatsappLinkQrSlice.Interpret(new NotifierAnswer(200, """{"qr":"abc","generated_seconds_ago":-1}"""))!.Stale, Is.True);
        Assert.That(WhatsappLinkQrSlice.Interpret(new NotifierAnswer(404, "{}"))!.Stale, Is.False);
        Assert.That(WhatsappLinkQrSlice.Interpret(new NotifierAnswer(502, "{}")), Is.Null);
        Assert.That(WhatsappLinkQrSlice.Interpret(new NotifierAnswer(200, """{"qr":""}""")), Is.Null);
    }

    [Test]
    public void A_reminder_row_is_cast_as_PHP_does()
    {
        var reminder = NotifierRows.Reminder(Json("""{"id":"4","name":"Weekly","type":"weekly","gender":"gents","city":"","levels":"1,2","lang":"english","leeway_days":3,"timezone":"Asia/Kolkata","weekday":null,"send_time":"09:00:00","schedule_on":1,"enabled":"0","updated_at":"2026-11-12 10:00:00"}"""));

        Assert.That((reminder.Id, reminder.City, reminder.Weekday, reminder.ScheduleOn, reminder.Enabled, reminder.UpdatedAt),
            Is.EqualTo((4L, (string?)null, (long?)null, true, false, "2026-11-12T10:00:00Z")));
        Assert.That(NotifierRows.Utc(Json("\"0000-00-00 00:00:00\"")), Is.Null);
    }

    [TestCase("\0", true)]
    [TestCase("ok", false)]
    public void A_NUL_byte_in_text_to_forward_is_refused(string text, bool refused) =>
        Assert.That(NotifierAccess.TextProblem("message", text, 10) is not null, Is.EqualTo(refused));
}
