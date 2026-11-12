using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using NUnit.Framework;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// The real FCM client against a STUB HttpMessageHandler (nothing leaves the process) and a throwaway RSA key made in the test: the token exchange request, the send request, the error mapping end to end,
/// the access token cache, and that no secret reaches a log line. What this cannot prove is listed in docs/specs/initial-build/test-notify-notes.md (Google's real wording and acceptance).
/// </summary>
public sealed class FcmPushSenderRequestTests
{
    private const string Device = "stub-device-token-1";
    private const string AccessToken = "stub-access-token-1";

    private sealed class StubHandler(Func<HttpRequestMessage, string, HttpResponseMessage> answer) : HttpMessageHandler
    {
        public List<(HttpRequestMessage Request, string Body)> Calls { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var body = request.Content is null ? string.Empty : await request.Content.ReadAsStringAsync(cancellationToken);
            Calls.Add((request, body));
            return answer(request, body);
        }
    }

    private sealed class StubClients(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new(handler, disposeHandler: false);
    }

    private sealed class ManualClock(DateTimeOffset start) : TimeProvider
    {
        private DateTimeOffset now = start;

        public override DateTimeOffset GetUtcNow() => now;

        public void Advance(TimeSpan by) => now += by;
    }

    private sealed class CapturingLog : ILogger<FcmPushSender>
    {
        public List<string> Lines { get; } = [];

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Add(formatter(state, exception) + exception);
    }

    private static readonly DateTimeOffset Start = new(2030, 1, 1, 12, 0, 0, TimeSpan.Zero);

    private RSA key = null!;
    private ManualClock clock = null!;
    private CapturingLog log = null!;
    private FcmPushSender? sender;

    [SetUp]
    public void Prepare()
    {
        key = RSA.Create(2048);
        clock = new ManualClock(Start);
        log = new CapturingLog();
        sender = null;
    }

    [TearDown]
    public void Release()
    {
        sender?.Dispose();
        key.Dispose();
    }

    private string Setting(string project = "proj-x") =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new { project_id = project, client_email = "sender@proj-x.invalid", private_key = key.ExportPkcs8PrivateKeyPem() })));

    private FcmPushSender Build(StubHandler handler, string? setting = null)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> { [FcmPushSender.SettingName] = setting ?? Setting() }).Build();
        sender = new FcmPushSender(configuration, new StubClients(handler), log, clock);
        return sender;
    }

    private static HttpResponseMessage Json(HttpStatusCode status, string body) =>
        new(status) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    private static HttpResponseMessage Exchange(HttpRequestMessage request, string body) =>
        request.RequestUri!.Host == "oauth2.googleapis.com" ? Json(HttpStatusCode.OK, $$"""{"access_token":"{{AccessToken}}","expires_in":3600}""") : Json(HttpStatusCode.OK, "{}");

    private static readonly PushMessage Message = new("Stub title", "Stub body", new Dictionary<string, string> { ["type"] = "t", ["click_action"] = "FLUTTER_NOTIFICATION_CLICK" });

    [Test]
    public async Task The_token_exchange_posts_a_JWT_signed_with_the_key_to_Googles_fixed_endpoint_and_the_send_carries_the_bearer_and_the_message()
    {
        var handler = new StubHandler(Exchange);
        var result = await Build(handler).SendAsync(Message, Device, CancellationToken.None);

        Assert.That(result, Is.EqualTo(PushResult.Sent));
        Assert.That(handler.Calls, Has.Count.EqualTo(2));
        var (tokenRequest, tokenBody) = handler.Calls[0];
        Assert.That((tokenRequest.Method, tokenRequest.RequestUri!.ToString()), Is.EqualTo((HttpMethod.Post, "https://oauth2.googleapis.com/token")));
        var form = tokenBody.Split('&').Select(p => p.Split('=', 2)).ToDictionary(p => p[0], p => Uri.UnescapeDataString(p[1]));
        Assert.That(form["grant_type"], Is.EqualTo("urn:ietf:params:oauth:grant-type:jwt-bearer"));
        var parts = form["assertion"].Split('.');
        Assert.That(parts, Has.Length.EqualTo(3));
        Assert.That(Encoding.UTF8.GetString(Convert.FromBase64String(Pad(parts[0]))), Is.EqualTo("""{"alg":"RS256","typ":"JWT"}"""));
        Assert.That(key.VerifyData(Encoding.ASCII.GetBytes(parts[0] + "." + parts[1]), Convert.FromBase64String(Pad(parts[2])), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1), Is.True, "signed with the service account key");
        var claims = JsonElement.Parse(Encoding.UTF8.GetString(Convert.FromBase64String(Pad(parts[1]))));
        Assert.That(claims.GetProperty("iss").GetString(), Is.EqualTo("sender@proj-x.invalid"));
        Assert.That(claims.GetProperty("scope").GetString(), Is.EqualTo("https://www.googleapis.com/auth/firebase.messaging"));
        Assert.That(claims.GetProperty("aud").GetString(), Is.EqualTo("https://oauth2.googleapis.com/token"));
        Assert.That(claims.GetProperty("exp").GetInt64() - claims.GetProperty("iat").GetInt64(), Is.EqualTo(3600));

        var (send, sendBody) = handler.Calls[1];
        Assert.That(send.RequestUri!.ToString(), Is.EqualTo("https://fcm.googleapis.com/v1/projects/proj-x/messages:send"));
        Assert.That(send.Headers.Authorization!.ToString(), Is.EqualTo("Bearer " + AccessToken));
        var message = JsonElement.Parse(sendBody).GetProperty("message");
        Assert.That(message.GetProperty("token").GetString(), Is.EqualTo(Device));
        Assert.That(message.GetProperty("notification").GetProperty("title").GetString(), Is.EqualTo("Stub title"));
        Assert.That(message.GetProperty("notification").GetProperty("body").GetString(), Is.EqualTo("Stub body"));
        Assert.That(message.GetProperty("data").GetProperty("click_action").GetString(), Is.EqualTo("FLUTTER_NOTIFICATION_CLICK"));
        Assert.That(message.GetProperty("android").GetProperty("priority").GetString(), Is.EqualTo("HIGH"));
        Assert.That(message.GetProperty("android").GetProperty("notification").GetProperty("channel_id").GetString(), Is.EqualTo("high_importance_channel"));
        Assert.That(message.GetProperty("apns").GetProperty("payload").GetProperty("aps").GetProperty("badge").GetInt32(), Is.EqualTo(1));
    }

    private static string Pad(string base64Url)
    {
        var text = base64Url.Replace('-', '+').Replace('_', '/');
        return text + new string('=', (4 - (text.Length % 4)) % 4);
    }

    [Test]
    public async Task The_access_token_is_cached_until_five_minutes_before_it_expires()
    {
        var handler = new StubHandler(Exchange);
        var fcm = Build(handler);
        await fcm.SendAsync(Message, Device, CancellationToken.None);
        await fcm.SendAsync(Message, Device, CancellationToken.None);
        Assert.That(handler.Calls.Count(c => c.Request.RequestUri!.Host == "oauth2.googleapis.com"), Is.EqualTo(1));

        clock.Advance(TimeSpan.FromSeconds(3400));
        await fcm.SendAsync(Message, Device, CancellationToken.None);
        Assert.That(handler.Calls.Count(c => c.Request.RequestUri!.Host == "oauth2.googleapis.com"), Is.EqualTo(2), "3400 s is past 3600 - 300");
    }

    [Test]
    public async Task A_401_forgets_the_access_token_so_the_next_send_asks_again()
    {
        var handler = new StubHandler((request, body) => request.RequestUri!.Host == "oauth2.googleapis.com" ? Exchange(request, body) : Json(HttpStatusCode.Unauthorized, """{"error":{"status":"UNAUTHENTICATED"}}"""));
        var fcm = Build(handler);
        Assert.That(await fcm.SendAsync(Message, Device, CancellationToken.None), Is.EqualTo(PushResult.Unavailable));
        await fcm.SendAsync(Message, Device, CancellationToken.None);
        Assert.That(handler.Calls.Count(c => c.Request.RequestUri!.Host == "oauth2.googleapis.com"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_refused_token_exchange_fails_the_send_and_is_not_asked_again_for_a_minute()
    {
        var handler = new StubHandler((_, _) => Json(HttpStatusCode.BadRequest, """{"error":"invalid_grant"}"""));
        var fcm = Build(handler);
        Assert.That(await fcm.SendAsync(Message, Device, CancellationToken.None), Is.EqualTo(PushResult.Unavailable));
        Assert.That(await fcm.SendAsync(Message, Device, CancellationToken.None), Is.EqualTo(PushResult.Unavailable));
        Assert.That(handler.Calls, Has.Count.EqualTo(1), "one exchange, no send");
        clock.Advance(TimeSpan.FromSeconds(61));
        await fcm.SendAsync(Message, Device, CancellationToken.None);
        Assert.That(handler.Calls, Has.Count.EqualTo(2));
    }

    [Test]
    public async Task A_dead_token_is_dead_a_bad_payload_is_a_failure_and_a_network_error_is_unavailable()
    {
        var reply = Json(HttpStatusCode.NotFound, """{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}""");
        var handler = new StubHandler((request, body) => request.RequestUri!.Host == "oauth2.googleapis.com" ? Exchange(request, body) : reply);
        var fcm = Build(handler);
        Assert.That(await fcm.SendAsync(Message, Device, CancellationToken.None), Is.EqualTo(PushResult.TokenInvalid));

        reply = Json(HttpStatusCode.BadRequest, """{"error":{"status":"INVALID_ARGUMENT","message":"Invalid value at message.data"}}""");
        Assert.That(await fcm.SendAsync(Message, Device, CancellationToken.None), Is.EqualTo(PushResult.Failed));

        var broken = new StubHandler((request, body) => request.RequestUri!.Host == "oauth2.googleapis.com" ? Exchange(request, body) : throw new HttpRequestException("stub network down"));
        Assert.That(await Build(broken).SendAsync(Message, Device, CancellationToken.None), Is.EqualTo(PushResult.Unavailable));
    }

    [Test]
    public async Task Without_a_usable_setting_the_sender_is_not_configured_and_makes_no_request()
    {
        var handler = new StubHandler(Exchange);
        Assert.That(Build(handler, "   ").IsConfigured, Is.False);
        sender!.Dispose();
        Assert.That(Build(handler, Convert.ToBase64String(Encoding.UTF8.GetBytes("""{"project_id":"p","client_email":"e","private_key":"not a key"}"""))).IsConfigured, Is.False);
        Assert.That(await sender.SendAsync(Message, Device, CancellationToken.None), Is.EqualTo(PushResult.Failed));
        sender.Dispose();
        Assert.That(Build(handler, "%%% not base64").IsConfigured, Is.False);
        Assert.That(handler.Calls, Is.Empty);
    }

    [Test]
    public async Task No_log_line_holds_the_device_token_the_access_token_or_the_private_key()
    {
        var handler = new StubHandler((request, body) => request.RequestUri!.Host == "oauth2.googleapis.com" ? Exchange(request, body) : Json(HttpStatusCode.Forbidden, "{\"error\":{\"status\":\"PERMISSION_DENIED\",\"message\":\"" + Device + " " + AccessToken + "\"}}"));
        var fcm = Build(handler, Setting());
        await fcm.SendAsync(Message, Device, CancellationToken.None);
        var broken = new StubHandler((request, body) => request.RequestUri!.Host == "oauth2.googleapis.com" ? Exchange(request, body) : throw new HttpRequestException(Device));
        await Build(broken).SendAsync(Message, Device, CancellationToken.None);
        Assert.That(log.Lines, Is.Not.Empty);
        var text = string.Join('\n', log.Lines);
        Assert.That(text, Does.Not.Contain(Device).And.Not.Contain(AccessToken).And.Not.Contain("PRIVATE KEY").And.Not.Contain("Stub body"));
    }
}
