using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Microsoft.Extensions.Options;
using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// What the real Google Sheets client puts on the wire and how it maps failures, against a stub handler and a throwaway key generated here (no request goes to Google). The JWT claims and the signature are checked
/// with the key's public half; the request URLs and bodies are the ones lane-sheets-notes.md lists as unverified against Google.
/// </summary>
[TestFixture]
internal sealed class GoogleSheetsWireTests
{
    private sealed class FixedClock(DateTimeOffset start) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = start;

        public override DateTimeOffset GetUtcNow() => Now;
    }

    /// <summary>Records every request (with its body read at once) and answers from a script.</summary>
    private sealed class Stub(Func<HttpRequestMessage, string?, Task<HttpResponseMessage>> answer) : HttpMessageHandler
    {
        public List<(HttpRequestMessage Request, string? Body)> Seen { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var body = request.Content is null ? null : await request.Content.ReadAsStringAsync(cancellationToken);
            Seen.Add((request, body));
            return await answer(request, body);
        }
    }

    private static HttpResponseMessage Json(HttpStatusCode status, string json) => new(status) { Content = new StringContent(json) };

    private static Task<HttpResponseMessage> Normal(HttpRequestMessage request, string? body) =>
        Task.FromResult(request.Method == HttpMethod.Post
            ? Json(HttpStatusCode.OK, """{"access_token":"t0ken","expires_in":3600}""")
            : Json(HttpStatusCode.OK, """{"values":[["a"]]}"""));

    private static (string Base64, RSA Key) Account(string? tokenUri = null)
    {
        var rsa = RSA.Create(2048);
        var uri = tokenUri is null ? string.Empty : $$""","token_uri":"{{tokenUri}}" """;
        var json = $$"""{"client_email":"sa@example.invalid","private_key":"{{rsa.ExportPkcs8PrivateKeyPem().ReplaceLineEndings("\\n")}}"{{uri}}}""";
        return (Convert.ToBase64String(Encoding.UTF8.GetBytes(json)), rsa);
    }

    private static GoogleSheets Client(Stub stub, string? account, FixedClock clock) =>
        new(new HttpClient(stub), Options.Create(new GoogleSheetsSettings { ServiceAccountB64 = account }), clock);

    private static byte[] Unbase64Url(string text) => Convert.FromBase64String(text.Replace('-', '+').Replace('_', '/').PadRight((text.Length + 3) / 4 * 4, '='));

    private static readonly DateTimeOffset Start = DateTimeOffset.Parse("2026-12-02T06:30:00+00:00", System.Globalization.CultureInfo.InvariantCulture);

    [Test]
    public async Task The_token_request_is_a_jwt_bearer_grant_whose_claims_and_RS256_signature_are_right()
    {
        var (account, key) = Account();
        using var _ = key;
        var stub = new Stub(Normal);
        using var sheets = Client(stub, account, new FixedClock(Start));

        await sheets.ReadAsync("sheet", "A1", CancellationToken.None);

        var (token, body) = stub.Seen[0];
        Assert.That(token.Method, Is.EqualTo(HttpMethod.Post));
        Assert.That(token.RequestUri!.AbsoluteUri, Is.EqualTo("https://oauth2.googleapis.com/token"));
        var form = Uri.UnescapeDataString(body!).Split('&').Select(p => p.Split('=', 2)).ToDictionary(p => p[0], p => p[1].Replace('+', ' '));
        Assert.That(form["grant_type"], Is.EqualTo("urn:ietf:params:oauth:grant-type:jwt-bearer"));
        var parts = form["assertion"].Split('.');
        Assert.That(parts, Has.Length.EqualTo(3));
        Assert.That(Encoding.UTF8.GetString(Unbase64Url(parts[0])), Is.EqualTo("""{"alg":"RS256","typ":"JWT"}"""));
        var claims = JsonNode.Parse(Unbase64Url(parts[1]))!;
        Assert.That(claims["iss"]!.GetValue<string>(), Is.EqualTo("sa@example.invalid"));
        Assert.That(claims["scope"]!.GetValue<string>(), Is.EqualTo("https://www.googleapis.com/auth/spreadsheets"));
        Assert.That(claims["aud"]!.GetValue<string>(), Is.EqualTo("https://oauth2.googleapis.com/token"));
        Assert.That(claims["iat"]!.GetValue<long>(), Is.EqualTo(Start.ToUnixTimeSeconds()));
        Assert.That(claims["exp"]!.GetValue<long>(), Is.EqualTo(Start.ToUnixTimeSeconds() + 3600));
        Assert.That(key.VerifyData(Encoding.ASCII.GetBytes(parts[0] + "." + parts[1]), Unbase64Url(parts[2]), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1), Is.True, "signature");
    }

    [Test]
    public async Task A_token_uri_in_the_key_is_both_the_audience_and_where_the_exchange_goes()
    {
        var (account, key) = Account("https://tokens.example.invalid/exchange");
        using var _ = key;
        var stub = new Stub(Normal);
        using var sheets = Client(stub, account, new FixedClock(Start));

        await sheets.ReadAsync("sheet", "A1", CancellationToken.None);

        Assert.That(stub.Seen[0].Request.RequestUri!.AbsoluteUri, Is.EqualTo("https://tokens.example.invalid/exchange"));
        var assertion = Uri.UnescapeDataString(stub.Seen[0].Body!).Split('&').First(p => p.StartsWith("assertion=", StringComparison.Ordinal))["assertion=".Length..];
        Assert.That(JsonNode.Parse(Unbase64Url(assertion.Split('.')[1]))!["aud"]!.GetValue<string>(), Is.EqualTo("https://tokens.example.invalid/exchange"));
    }

    [Test]
    public async Task A_read_is_a_GET_of_the_escaped_range_with_the_bearer_token()
    {
        var (account, key) = Account();
        using var _ = key;
        var stub = new Stub(Normal);
        using var sheets = Client(stub, account, new FixedClock(Start));

        var rows = await sheets.ReadAsync("1bKkN_R55g", "Form Responses 2!A2:C", CancellationToken.None);

        var read = stub.Seen[1].Request;
        Assert.That(read.Method, Is.EqualTo(HttpMethod.Get));
        Assert.That(read.RequestUri!.AbsoluteUri, Is.EqualTo("https://sheets.googleapis.com/v4/spreadsheets/1bKkN_R55g/values/Form%20Responses%202%21A2%3AC"));
        Assert.That(read.Headers.Authorization!.ToString(), Is.EqualTo("Bearer t0ken"));
        Assert.That(rows.Single().Single(), Is.EqualTo("a"));
    }

    [Test]
    public async Task A_write_is_a_PUT_with_RAW_input_and_a_values_body_that_keeps_numbers_numbers_and_empty_cells_null()
    {
        var (account, key) = Account();
        using var _ = key;
        var stub = new Stub(Normal);
        using var sheets = Client(stub, account, new FixedClock(Start));

        await sheets.WriteAsync("pub", "Winners!A2", [["First", 923101L, null], []], CancellationToken.None);

        var (put, body) = stub.Seen[1];
        Assert.That(put.Method, Is.EqualTo(HttpMethod.Put));
        Assert.That(put.RequestUri!.AbsoluteUri, Is.EqualTo("https://sheets.googleapis.com/v4/spreadsheets/pub/values/Winners%21A2?valueInputOption=RAW"));
        Assert.That(JsonNode.Parse(body!)!.ToJsonString(), Is.EqualTo("""{"range":"Winners!A2","majorDimension":"ROWS","values":[["First",923101,null],[]]}"""));
    }

    [Test]
    public async Task The_token_is_reused_until_a_minute_before_it_expires_then_exchanged_again()
    {
        var (account, key) = Account();
        using var _ = key;
        var stub = new Stub(Normal);
        var clock = new FixedClock(Start);
        using var sheets = Client(stub, account, clock);

        await sheets.ReadAsync("s", "A1", CancellationToken.None);
        clock.Now = Start.AddSeconds(3539);
        await sheets.ReadAsync("s", "A1", CancellationToken.None);
        Assert.That(stub.Seen.Count(s => s.Request.Method == HttpMethod.Post), Is.EqualTo(1));

        clock.Now = Start.AddSeconds(3541);
        await sheets.ReadAsync("s", "A1", CancellationToken.None);
        Assert.That(stub.Seen.Count(s => s.Request.Method == HttpMethod.Post), Is.EqualTo(2));
    }

    [TestCase(HttpStatusCode.Forbidden, "Google Sheets answered 403")]
    [TestCase(HttpStatusCode.NotFound, "Google Sheets answered 404")]
    [TestCase(HttpStatusCode.TooManyRequests, "Google Sheets answered 429")]
    [TestCase(HttpStatusCode.InternalServerError, "Google Sheets answered 500")]
    public async Task A_refused_call_is_a_sheets_exception_that_carries_the_status_and_nothing_of_the_answer(HttpStatusCode status, string message)
    {
        var (account, key) = Account();
        using var _ = key;
        var stub = new Stub((request, _) => Task.FromResult(request.Method == HttpMethod.Post
            ? Json(HttpStatusCode.OK, """{"access_token":"t0ken","expires_in":3600}""")
            : Json(status, """{"error":{"message":"the spreadsheet 1bKkN secret-title is private"}}""")));
        using var sheets = Client(stub, account, new FixedClock(Start));

        var read = await Assert.ThrowsAsync<SheetsException>(() => sheets.ReadAsync("s", "A1", CancellationToken.None));
        var write = await Assert.ThrowsAsync<SheetsException>(() => sheets.WriteAsync("s", "A1", [["x"]], CancellationToken.None));

        Assert.That(read!.Message, Is.EqualTo(message));
        Assert.That(write!.Message, Is.EqualTo(message));
    }

    [Test]
    public async Task A_token_endpoint_that_refuses_or_answers_without_a_token_or_with_garbage_is_a_sheets_exception_that_leaks_no_credential()
    {
        var (account, key) = Account();
        using var _ = key;
        foreach (var answer in new[]
        {
            Json(HttpStatusCode.Unauthorized, """{"error":"invalid_grant","error_description":"sa@example.invalid"}"""),
            Json(HttpStatusCode.OK, """{"expires_in":3600}"""),
            Json(HttpStatusCode.OK, "<html>not json</html>"),
        })
        {
            var stub = new Stub((_, _) => Task.FromResult(answer));
            using var sheets = Client(stub, account, new FixedClock(Start));

            var error = await Assert.ThrowsAsync<SheetsException>(() => sheets.ReadAsync("s", "A1", CancellationToken.None));

            Assert.That(error!.Message, Does.Not.Contain("sa@example.invalid"));
            Assert.That(error.Message, Does.Not.Contain("PRIVATE KEY"));
            Assert.That(stub.Seen, Has.Count.EqualTo(1), "no sheet call without a token");
        }

        await Task.CompletedTask;
    }

    [Test]
    public async Task A_network_failure_and_a_timeout_are_sheets_exceptions_but_a_cancelled_caller_stays_cancelled()
    {
        var (account, key) = Account();
        using var _ = key;
        var failing = new Stub((request, _) => request.Method == HttpMethod.Post ? Normal(request, null) : throw new HttpRequestException("connection refused"));
        using (var sheets = Client(failing, account, new FixedClock(Start)))
        {
            var error = await Assert.ThrowsAsync<SheetsException>(() => sheets.ReadAsync("s", "A1", CancellationToken.None));
            Assert.That(error!.Message, Is.EqualTo("Google Sheets is unreachable"));
        }

        var slow = new Stub((request, _) => request.Method == HttpMethod.Post ? Normal(request, null) : throw new TaskCanceledException("timed out"));
        using (var sheets = Client(slow, account, new FixedClock(Start)))
        {
            var error = await Assert.ThrowsAsync<SheetsException>(() => sheets.ReadAsync("s", "A1", CancellationToken.None));
            Assert.That(error!.Message, Is.EqualTo("Google Sheets did not answer in time"));
        }

        using var cancelled = new CancellationTokenSource();
        await cancelled.CancelAsync();
        var stub = new Stub(Normal);
        using var third = Client(stub, account, new FixedClock(Start));
        await Assert.CatchAsync<OperationCanceledException>(() => third.ReadAsync("s", "A1", cancelled.Token));
        Assert.That(stub.Seen, Is.Empty);
    }

    [Test]
    public async Task A_missing_or_unusable_key_is_a_sheets_exception_that_does_not_echo_the_setting()
    {
        var notJson = Convert.ToBase64String(Encoding.UTF8.GetBytes("hello"));
        var noKey = Convert.ToBase64String(Encoding.UTF8.GetBytes("""{"client_email":"sa@example.invalid"}"""));
        var badPem = Convert.ToBase64String(Encoding.UTF8.GetBytes("""{"client_email":"sa@example.invalid","private_key":"not a key"}"""));
        foreach (var setting in new[] { null, "", "   ", "%%%not base64", notJson, noKey, badPem })
        {
            var stub = new Stub(Normal);
            using var sheets = Client(stub, setting, new FixedClock(Start));

            var error = await Assert.ThrowsAsync<SheetsException>(() => sheets.ReadAsync("s", "A1", CancellationToken.None));

            Assert.That(error!.Message, Does.Not.Contain("not a key"));
            Assert.That(error.Message, Does.Not.Contain("sa@example.invalid"));
            Assert.That(stub.Seen, Is.Empty, "nothing is sent without a usable key");
        }
    }

    [Test]
    public void More_rows_than_the_limit_and_a_values_property_that_is_not_a_list_are_refused_and_non_text_cells_are_read_as_their_text()
    {
        var many = "{\"values\":[" + string.Join(",", Enumerable.Repeat("[\"a\"]", 50_001)) + "]}";

        Assert.Throws<SheetsException>(() => GoogleSheets.ParseValues(Encoding.UTF8.GetBytes(many)));
        Assert.Throws<SheetsException>(() => GoogleSheets.ParseValues("""{"values":"x"}"""u8.ToArray()));
        Assert.Throws<SheetsException>(() => GoogleSheets.ParseValues("not json"u8.ToArray()));
        var rows = GoogleSheets.ParseValues("""{"values":[[1,true,"x"],"oops",[]]}"""u8.ToArray());
        Assert.That(rows[0], Is.EqualTo(new List<string> { "1", "true", "x" }));
        Assert.That(rows[1], Is.Empty);
        Assert.That(JsonSerializer.Serialize(rows[2]), Is.EqualTo("[]"));
    }
}
