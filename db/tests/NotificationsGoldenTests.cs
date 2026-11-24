using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// Characterisation of the notifications domain (issue 103): every answer, every stored row, every event and every push or notifier request is recorded on the code as it was, in
/// db/tests/golden/notifications, so the conversion off Entity Framework can be compared byte for byte. Nothing here asserts a value written by hand: a golden file is the expectation.
/// The push service and the notifier are recording stubs: no test reaches Google, FCM or a messaging service.
/// </summary>
public sealed class NotificationsGoldenTests
{
    public static IEnumerable<string> RouteScenarios => NotificationsGoldenScenarios.Routes.Keys;

    public static IEnumerable<string> PushScenarios => NotificationsGoldenScenarios.Pushes.Keys;

    // TC-NTF-R1-01 (and R3-01, R4-01 for the writes): the answers of the routes and their refusals, with the rows and events after the writes.
    [TestCaseSource(nameof(RouteScenarios))]
    public async Task Every_notifications_route_answers_as_recorded(string scenario)
    {
        await using var run = await NotificationsRun.StartAsync(scenario);

        await NotificationsGoldenScenarios.Routes[scenario](run);

        GoldenScenario.Check(scenario, run.Transcript, NotificationsGolden.Set);
    }

    // TC-NTF-R5-01 (routes): every push request the three push routes send, with the answer, the rows and the events.
    [TestCaseSource(nameof(PushScenarios))]
    public async Task Every_push_is_sent_as_recorded(string scenario)
    {
        await using var run = await NotificationsRun.StartAsync(scenario);

        await NotificationsGoldenScenarios.Pushes[scenario](run);

        GoldenScenario.Check(scenario, run.Transcript, NotificationsGolden.Set);
    }

    // TC-NTF-R23-01: without push settings the three routes that push while the caller waits refuse before sending or storing anything, and the sending worker takes nothing.
    [Test]
    public async Task Without_push_settings_the_push_routes_refuse_as_recorded()
    {
        const string scenario = "push-unconfigured";
        await using var run = await NotificationsRun.StartAsync(scenario, pushConfigured: false);

        await run.AsAsync(NotificationsSeed.Admin, HttpMethod.Post, "/notifications/send", """{"title":"T","body":"B","target":{"type":"CLASS_LEVEL","value":[2]}}""");
        await run.AsAsync(NotificationsSeed.Sender, HttpMethod.Post, "/classes/98501/notifications", """{"title":"T","body":"B"}""");
        await run.AsAsync(NotificationsSeed.Admin, HttpMethod.Post, "/notifications/cleanup-invalid-tokens");
        await run.RowsAsync("nothing sent, nothing stored");
        await run.Run.ExecuteAsync("insert into platform.outbound_messages (channel, recipient, payload, dedupe_key, created_at) values ('push', 'dev-s1-ok', '{\"title\":\"T\",\"body\":\"B\"}', 'k-unconfigured', timestamptz '2025-12-31 00:00:00+00')");
        run.Run.Note("drain: " + await run.TickDrainAsync());
        await run.RowsAsync("the queued push left alone");

        GoldenScenario.Check(scenario, run.Transcript, NotificationsGolden.Set);
    }

    // The stubs are what the clients use: a request to a name that never resolves is answered by the recording handler, in every scenario's start; this shows it for both clients and for the unconfigured one.
    [Test]
    public async Task The_push_and_notifier_clients_are_on_the_recording_handlers()
    {
        await using var run = await NotificationsRun.StartAsync("recording-stubs");
        var clients = run.Run.Services.GetRequiredService<IHttpClientFactory>();

        foreach (var name in new[] { FcmPushSender.HttpClientName, nameof(INotifier) })
        {
            using var client = clients.CreateClient(name);
            using var response = await client.GetAsync(new Uri("https://stub-proof.invalid/again"));
            Assert.That(response.Headers.Contains(RecordingStub.Header), Is.True, name);
        }

        Assert.That(run.DrainOutsideCalls(), Is.EqualTo((string[])["fcm: unexpected GET https://stub-proof.invalid/again", "notifier: GET /again"]));

        // The typed notifier client (what a route resolves) is the one on the recording handler: its answer is the stub's.
        await using var scope = run.Run.Services.CreateAsyncScope();
        var answer = await scope.ServiceProvider.GetRequiredService<INotifier>().StatusAsync(CancellationToken.None);
        Assert.That(answer.Body, Is.EqualTo("""{"ok":true,"stub":"notifier"}"""));
        Assert.That(run.DrainOutsideCalls().Count(l => l.StartsWith("notifier: GET ", StringComparison.Ordinal)), Is.EqualTo(1));
    }
}
