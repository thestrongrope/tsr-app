using System.Net;
using System.Text;
using Tsr.Shared.Site;

namespace Tsr.Host.Site.Tests;

/// <summary>Answers GET requests from canned JSON per path; any other path is a 404.</summary>
internal sealed class FakeApi(IReadOnlyDictionary<string, (HttpStatusCode Status, string Json)> answers)
    : HttpMessageHandler
{
    public const string HealthJson = """{"status":"ok"}""";

    public const string ArticlesJson = """
        {"articles":[{"slug":"synthetic-published-article","title":"Synthetic published article",
        "body":"First paragraph.\n\nSecond, with <b>tags</b> and <script>alert(1)</script>.",
        "publishedAt":"2026-01-15T09:00:00+00:00"}]}
        """;

    public static SiteApi With(params (string Path, HttpStatusCode Status, string Json)[] answers)
    {
        var map = answers.ToDictionary(a => a.Path, a => (a.Status, a.Json));
#pragma warning disable CA2000 // The HttpClient owns the handler and lives as long as the test.
        var http = new HttpClient(new FakeApi(map)) { BaseAddress = new Uri("http://fake.test"), Timeout = TimeSpan.FromSeconds(5) };
#pragma warning restore CA2000
        return new SiteApi(http);
    }

    public static SiteApi Healthy() => With(
        ("/health", HttpStatusCode.OK, HealthJson),
        ("/articles", HttpStatusCode.OK, ArticlesJson));

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var path = request.RequestUri!.AbsolutePath;
        var (status, json) = answers.TryGetValue(path, out var answer) ? answer : (HttpStatusCode.NotFound, """{"detail":"no"}""");
        return Task.FromResult(new HttpResponseMessage(status)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json"),
        });
    }
}
