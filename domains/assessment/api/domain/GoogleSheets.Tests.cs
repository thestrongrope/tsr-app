using System.Net;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class GoogleSheetsTests
{
    private sealed class Handler : HttpMessageHandler
    {
        public List<HttpRequestMessage> Requests { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(request);
            var body = request.Method == HttpMethod.Post
                ? """{"access_token":"t0ken","expires_in":3600}"""
                : """{"values":[["a","b"],["c"]]}""";
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(body) });
        }
    }

    private static string Account()
    {
        using var rsa = RSA.Create(2048);
        var json = $$"""{"client_email":"sa@example.invalid","private_key":"{{rsa.ExportPkcs8PrivateKeyPem().ReplaceLineEndings("\\n")}}"}""";
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(json));
    }

    private static GoogleSheets Sheets(Handler handler, string? account) =>
        new(new HttpClient(handler), Options.Create(new GoogleSheetsSettings { ServiceAccountB64 = account }), TimeProvider.System);

    [Test]
    public async Task A_read_exchanges_a_signed_jwt_once_and_returns_the_rows()
    {
        var handler = new Handler();
        using var sheets = Sheets(handler, Account());

        var first = await sheets.ReadAsync("sheet", "English-Abuzar!A2:M", CancellationToken.None);
        await sheets.ReadAsync("sheet", "English-Abuzar!A2:M", CancellationToken.None);

        Assert.That(first.Select(r => r.Count), Is.EqualTo(new List<int> { 2, 1 }));
        Assert.That(handler.Requests.Count(r => r.Method == HttpMethod.Post), Is.EqualTo(1));
        Assert.That(handler.Requests[1].Headers.Authorization!.Parameter, Is.EqualTo("t0ken"));
    }

    [Test]
    public async Task Without_the_setting_a_read_fails_with_a_sheets_exception()
    {
        using var sheets = Sheets(new Handler(), null);

        await Assert.ThrowsAsync<SheetsException>(() => sheets.ReadAsync("sheet", "A1", CancellationToken.None));
    }

    [Test]
    public void A_range_with_no_values_is_empty()
    {
        Assert.That(GoogleSheets.ParseValues("""{"range":"A1"}"""u8.ToArray()), Is.Empty);
    }
}
