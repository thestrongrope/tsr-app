using System.Net;
using System.Text;
using Tsr.Shared.Site;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// Answers GET requests from canned JSON, looked up by path and query first and by path alone second; any other address is a 404.
/// The canned Library holds two published articles and no draft: the API never sends one (domains/content, LIB-R12).
/// </summary>
internal sealed class FakeApi(IReadOnlyDictionary<string, (HttpStatusCode Status, string Json)> answers)
    : HttpMessageHandler
{
    public const string HealthJson = """{"status":"ok"}""";

    public const string ListPath = "/api/v1/articles";

    public const string CategoriesPath = "/api/v1/taxonomies/categories";

    public const string ArticlePath = "/api/v1/articles/synthetic-published-article";

    public const string OtherArticlePath = "/api/v1/articles/another-synthetic-article";

    public const string ListJson = """
        {"success":true,"data":[
        {"id":1,"slug":"synthetic-published-article","title":"Synthetic &amp; published article","excerpt":"A synthetic excerpt.",
         "categories":["core-terms"],"tags":["Sample Tag"],"language":"en","readingTime":1},
        {"id":2,"slug":"another-synthetic-article","title":"Another synthetic article","categories":[],"tags":[],"language":"en","readingTime":1}],
        "meta":{"version":"1.0"},"pagination":{"total":2,"limit":100,"offset":0,"hasMore":false}}
        """;

    public const string CategoriesJson = """
        {"success":true,"data":[
        {"slug":"foundations","title":"Foundations","order":1,"articleCount":0},
        {"slug":"core-terms","title":"Core Terms","order":4,"parent":"foundations","articleCount":1},
        {"slug":"empty-child","title":"Empty Child","order":5,"parent":"foundations","articleCount":0}],
        "meta":{"version":"1.0"}}
        """;

    public const string ArticleJson = """
        {"success":true,"data":{"id":1,"slug":"synthetic-published-article","title":"Synthetic &amp; published article",
        "excerpt":"A synthetic excerpt.","categories":["core-terms"],"tags":["Sample Tag"],"language":"en","readingTime":3,
        "content":"<p>First paragraph.</p>\n<p>Second, with &lt;script&gt;alert(1)&lt;/script&gt; as text.</p>\n",
        "relatedArticles":[{"id":2,"slug":"another-synthetic-article","title":"Another synthetic article","categories":[],"tags":[]}]},
        "meta":{"version":"1.0"}}
        """;

    public const string OtherArticleJson = """
        {"success":true,"data":{"id":2,"slug":"another-synthetic-article","title":"Another synthetic article",
        "categories":[],"tags":[],"language":"en","readingTime":1,"content":"<p>Only paragraph.</p>\n","relatedArticles":[]},
        "meta":{"version":"1.0"}}
        """;

    public const string PublicationsPath = "/api/v1/publications";

    /// <summary>Seven synthetic publications in five languages, out of order, one of them without a language.</summary>
    public const string PublicationsJson = """
        {"success":true,"data":[
        {"title":"Zeta guide","summary":"A synthetic summary of the zeta guide.","type":"PDF","size":"1 MB","updated":"Jun 26, 2025",
         "language":"English","file":"/downloads/synthetic/zeta-guide.pdf","downloadOnly":false},
        {"title":"قرآن کی مصنوعی کتاب","summary":"ایک مصنوعی خلاصہ","type":"PDF","updated":"Mar 19, 2024",
         "language":"Urdu","file":"/downloads/synthetic/urdu-book.pdf","downloadOnly":true},
        {"title":"beta notes","type":"PDF","size":"2 MB","updated":"Jan 02, 2025",
         "language":" English ","file":"/downloads/synthetic/beta-notes.pdf","downloadOnly":false},
        {"title":"A synthetic web book","type":"Web","updated":"Feb 03, 2025",
         "language":"Hindi","readOnlineUrl":"/a-synthetic-web-book","downloadOnly":false},
        {"title":"Alpha <guide>","summary":"Both a file & a page.","type":"PDF","size":"3 MB","updated":"Apr 04, 2025",
         "language":"English","file":"/downloads/synthetic/alpha-guide.pdf","readOnlineUrl":"/alpha-guide-toc","downloadOnly":false},
        {"title":"A synthetic Bengali book","type":"PDF","size":"4 MB","language":"Bengali",
         "file":"https://files.example.invalid/bengali-book.pdf","downloadOnly":false},
        {"title":"A book of no language","type":"PDF","size":"5 MB","updated":"May 05, 2025",
         "file":"/downloads/synthetic/no-language.pdf","downloadOnly":false}],
        "meta":{"version":"1.0"},"pagination":{"total":7,"limit":7,"offset":0,"hasMore":false}}
        """;

    public static readonly (string Path, HttpStatusCode Status, string Json)[] HealthyAnswers =
    [
        ("/health", HttpStatusCode.OK, HealthJson),
        (ListPath, HttpStatusCode.OK, ListJson),
        (CategoriesPath, HttpStatusCode.OK, CategoriesJson),
        (ArticlePath, HttpStatusCode.OK, ArticleJson),
        (OtherArticlePath, HttpStatusCode.OK, OtherArticleJson),
        (PublicationsPath, HttpStatusCode.OK, PublicationsJson),
    ];

    /// <summary>The addresses asked, in order, with their query.</summary>
    public List<string> Asked { get; } = [];

    public static SiteApi With(params (string Path, HttpStatusCode Status, string Json)[] answers) => With(out _, answers);

    public static SiteApi With(out FakeApi fake, params (string Path, HttpStatusCode Status, string Json)[] answers)
    {
        fake = new FakeApi(answers.ToDictionary(a => Uri.UnescapeDataString(a.Path), a => (a.Status, a.Json)));
#pragma warning disable CA2000 // The HttpClient owns the handler and lives as long as the test.
        var http = new HttpClient(fake) { BaseAddress = new Uri("http://fake.test"), Timeout = TimeSpan.FromSeconds(5) };
#pragma warning restore CA2000
        return new SiteApi(http);
    }

    public static SiteApi Healthy() => With(HealthyAnswers);

    /// <summary>The healthy answers with one replaced.</summary>
    public static SiteApi HealthyBut(string path, HttpStatusCode status, string json) =>
        With(HealthyAnswers.Select(a => a.Path == path ? (path, status, json) : a).ToArray());

    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var uri = request.RequestUri!;
        Asked.Add(uri.PathAndQuery);
        // The client may write a percent-encoded byte in either case; the canned paths are compared decoded.
        var found = answers.TryGetValue(Uri.UnescapeDataString(uri.PathAndQuery), out var answer)
            || answers.TryGetValue(Uri.UnescapeDataString(uri.AbsolutePath), out answer);
        var (status, json) = found ? answer : (HttpStatusCode.NotFound, """{"detail":"no"}""");
        return Task.FromResult(new HttpResponseMessage(status)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json"),
        });
    }
}
