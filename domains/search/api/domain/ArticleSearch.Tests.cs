using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>SRCH-R6: the engine answers when it can; whatever else it does (not configured, a failure, an answer that is not a search answer) the published articles in the database answer, never a 500.</summary>
[TestFixture]
internal sealed class ArticleSearchTests
{
    private static readonly ArticleSearchRequest Request = new("patience", null, 20, 0);

    private sealed class FakeIndex(bool configured, Func<string> answer) : ILibraryIndex
    {
        public bool IsConfigured => configured;

        public List<string> Bodies { get; } = [];

        public Task<string> SearchAsync(string index, string body, CancellationToken ct)
        {
            Bodies.Add(index + " " + body);
            return Task.FromResult(answer());
        }

        public Task<bool> EnsureIndexAsync(string index, string mappingJson, CancellationToken ct) => throw new NotSupportedException();

        public Task<IReadOnlyList<string>> ListIdsAsync(string index, CancellationToken ct) => throw new NotSupportedException();

        public Task BulkAsync(string ndjson, CancellationToken ct) => throw new NotSupportedException();
    }

    private sealed class FakeFallback : IArticleFallback
    {
        public int Calls { get; private set; }

        public Task<IReadOnlyList<ArticleResult>> SearchAsync(ArticleSearchRequest request, CancellationToken ct)
        {
            Calls++;
            return Task.FromResult<IReadOnlyList<ArticleResult>>([new ArticleResult(0, "db", "From the database", null, "", null, "admin", [], [], "en", 1, 1, null)]);
        }
    }

    private const string OneHit = """{"hits":{"hits":[{"_score":2,"_source":{"slug":"es","title":"From the engine"}}]}}""";

    [Test]
    public async Task A_working_engine_answers_and_the_database_is_not_asked()
    {
        var index = new FakeIndex(true, () => OneHit);
        var fallback = new FakeFallback();

        var outcome = await ArticleSearch.RunAsync(index, fallback, Request, NullLogger.Instance, CancellationToken.None);

        Assert.That(outcome.Engine, Is.EqualTo("elasticsearch"));
        Assert.That(outcome.Results.Select(r => r.Slug), Is.EqualTo((string[])["es"]));
        Assert.That(fallback.Calls, Is.Zero);
        Assert.That(index.Bodies, Has.Count.EqualTo(1));
        Assert.That(index.Bodies[0], Does.StartWith("tsr-articles {\"query\""));
    }

    [Test]
    public async Task An_engine_that_is_not_configured_is_not_asked_and_the_database_answers()
    {
        var index = new FakeIndex(false, () => throw new InvalidOperationException("must not be called"));
        var fallback = new FakeFallback();

        var outcome = await ArticleSearch.RunAsync(index, fallback, Request, NullLogger.Instance, CancellationToken.None);

        Assert.That(outcome.Engine, Is.EqualTo("fuse"));
        Assert.That(outcome.Results.Select(r => r.Slug), Is.EqualTo((string[])["db"]));
        Assert.That(index.Bodies, Is.Empty);
    }

    [TestCase("unavailable")]
    [TestCase("garbage")]
    public async Task An_engine_that_fails_or_answers_with_garbage_gives_the_database_answer(string how)
    {
        var index = new FakeIndex(true, () => how == "garbage" ? "<html>502</html>" : throw new SearchUnavailableException("Elasticsearch answered 500"));
        var fallback = new FakeFallback();

        var outcome = await ArticleSearch.RunAsync(index, fallback, Request, NullLogger.Instance, CancellationToken.None);

        Assert.That(outcome.Engine, Is.EqualTo("fuse"));
        Assert.That(fallback.Calls, Is.EqualTo(1));
    }

    [Test]
    public async Task A_cancelled_request_is_not_turned_into_a_fallback()
    {
        using var cancelled = new CancellationTokenSource();
        cancelled.Cancel();
        var index = new FakeIndex(true, () => throw new OperationCanceledException(cancelled.Token));

        await Assert.ThatAsync(() => ArticleSearch.RunAsync(index, new FakeFallback(), Request, NullLogger.Instance, cancelled.Token), Throws.InstanceOf<OperationCanceledException>());
    }
}
