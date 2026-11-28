using System.Text;
using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The engine work of lecture search over a fake index and a fake embedder: the fuzzy retry (TC-SRCH-R7-02), the meaning layer and its fusion (R10), the keyword-only answer when the embedder gives nothing (R11-02, the website's quirk kept), the
/// browse (R8) and the failures (R12: no fallback, the engine's failure is the caller's).
/// </summary>
[TestFixture]
internal sealed class LectureSearchTests
{
    private sealed class FakeIndex(bool configured, Func<string, string> answer) : ILibraryIndex
    {
        public bool IsConfigured => configured;

        public List<string> Bodies { get; } = [];

        public Task<string> SearchAsync(string index, string body, CancellationToken ct)
        {
            Assert.That(index, Is.EqualTo("tsr-lectures"));
            Bodies.Add(body);
            return Task.FromResult(answer(body));
        }

        public Task<bool> EnsureIndexAsync(string index, string mappingJson, CancellationToken ct) => throw new NotSupportedException();

        public Task<IReadOnlyList<string>> ListIdsAsync(string index, CancellationToken ct) => throw new NotSupportedException();

        public Task BulkAsync(string ndjson, CancellationToken ct) => throw new NotSupportedException();
    }

    private sealed class FakeEmbedder(float[]? vector) : IQueryEmbedder
    {
        public int Calls { get; private set; }

        public Task<float[]?> EmbedQueryAsync(string q, CancellationToken ct)
        {
            Calls++;
            return Task.FromResult(vector);
        }
    }

    private static string Answer(long total, params string[] slugs)
    {
        var hits = string.Join(",", slugs.Select((slug, i) => "{\"_score\":" + (10 - i) + ",\"_source\":{\"slug\":\"" + slug + "\",\"title\":\"T " + slug + "\",\"url\":\"https://v/" + slug + "\"}}"));
        return "{\"hits\":{\"total\":{\"value\":" + total + "},\"hits\":[" + hits + "]}}";
    }

    private static LectureSearchRequest Request(string q = "patience", string? language = null, int limit = 20, int offset = 0) => new(q, language, limit, offset);

    private static Task<LectureSearchOutcome> RunAsync(FakeIndex index, IQueryEmbedder embedder, double weight, LectureSearchRequest request) =>
        LectureSearch.RunAsync(index, embedder, weight, request, CancellationToken.None);

    [Test]
    public async Task A_strict_stage_with_three_or_more_hits_is_the_answer_and_no_fuzzy_body_is_sent()
    {
        var index = new FakeIndex(true, _ => Answer(3, "a", "b", "c"));

        var outcome = await RunAsync(index, new FakeEmbedder(null), 0, Request());

        Assert.That(index.Bodies, Has.Count.EqualTo(1));
        Assert.That(outcome.Results.Select(r => r.Slug), Is.EqualTo((string[])["a", "b", "c"]));
        Assert.That(outcome.Engine, Is.EqualTo("elasticsearch"));
        Assert.That(outcome.Total, Is.EqualTo(3));
        Assert.That(outcome.Query, Is.EqualTo("patience"));
    }

    [Test]
    public async Task A_strict_total_below_three_sends_the_fuzzy_body_once_and_uses_its_answer()
    {
        var index = new FakeIndex(true, body => body.Contains("fuzziness", StringComparison.Ordinal) ? Answer(2, "typo-a", "typo-b") : Answer(2, "strict-a"));

        var outcome = await RunAsync(index, new FakeEmbedder(null), 0, Request());

        Assert.That(index.Bodies, Has.Count.EqualTo(2));
        Assert.That(index.Bodies[0], Does.Not.Contain("fuzziness"));
        Assert.That(index.Bodies[1], Does.Contain("\"fuzziness\":\"AUTO\""));
        Assert.That(outcome.Results.Select(r => r.Slug), Is.EqualTo((string[])["typo-a", "typo-b"]));
    }

    [Test]
    public async Task The_decision_to_retry_is_made_on_the_total_not_on_the_page()
    {
        var index = new FakeIndex(true, _ => Answer(40, "only-one-on-this-page"));

        _ = await RunAsync(index, new FakeEmbedder(null), 0, Request(offset: 39));

        Assert.That(index.Bodies, Has.Count.EqualTo(1));
    }

    [Test]
    public async Task With_the_meaning_layer_off_the_embedder_is_never_asked_and_the_page_is_the_engines()
    {
        var embedder = new FakeEmbedder(new float[384]);
        var index = new FakeIndex(true, _ => Answer(30, "a", "b"));

        var outcome = await RunAsync(index, embedder, weight: 0, Request(limit: 5, offset: 10));

        Assert.That(embedder.Calls, Is.Zero);
        Assert.That(index.Bodies.Single(), Does.Contain("\"size\":5,\"from\":10"));
        Assert.That(outcome.Engine, Is.EqualTo("elasticsearch"));
    }

    [Test]
    public async Task With_a_vector_the_two_rankings_are_fused_and_the_page_is_cut_from_the_fused_list()
    {
        var keyword = Answer(9, "k1", "k2", "both");
        var meaning = Answer(50, "both", "m1", "m2");
        var index = new FakeIndex(true, body => body.StartsWith("{\"knn\"", StringComparison.Ordinal) ? meaning : keyword);

        var outcome = await RunAsync(index, new FakeEmbedder([0.5f, 0.25f]), 0.25, Request(limit: 2, offset: 1, language: "hi"));

        // k1 1/61 = 0.016393; both 1/63 + 0.25/61 = 0.019971; k2 1/62 = 0.016129; m1 0.25/62; m2 0.25/63: both, k1, k2, m1, m2.
        Assert.That(outcome.Engine, Is.EqualTo("elasticsearch+semantic"));
        Assert.That(outcome.Total, Is.EqualTo(5), "the length of the fused list, not the engine's count");
        Assert.That(outcome.Results.Select(r => r.Slug), Is.EqualTo((string[])["k1", "k2"]));
        Assert.That(index.Bodies, Has.Count.EqualTo(2));
        Assert.That(index.Bodies[0], Does.Contain("\"size\":50,\"from\":0"));
        Assert.That(index.Bodies[1], Does.Contain("\"filter\":[{\"term\":{\"language\":\"hi\"}}]"));
    }

    [Test]
    public async Task The_kept_hit_of_a_lecture_in_both_lists_is_the_keyword_one_with_its_score()
    {
        var index = new FakeIndex(true, body => body.StartsWith("{\"knn\"", StringComparison.Ordinal) ? Answer(1, "both").Replace("\"_score\":10", "\"_score\":0.77", StringComparison.Ordinal) : Answer(3, "both", "x", "y"));

        var outcome = await RunAsync(index, new FakeEmbedder([1f]), 0.25, Request());

        Assert.That(outcome.Results[0].Slug, Is.EqualTo("both"));
        Assert.That(outcome.Results[0].Score, Is.EqualTo(10));
    }

    [Test]
    public async Task Without_a_vector_the_keyword_pool_of_fifty_is_cut_by_offset_and_limit_and_the_total_stays_the_engines_quirk_kept()
    {
        var pool = Enumerable.Range(1, 50).Select(i => "s" + i).ToArray();
        var index = new FakeIndex(true, _ => Answer(80, pool));

        var page = await RunAsync(index, new FakeEmbedder(null), 0.25, Request(limit: 3, offset: 10));
        var beyond = await RunAsync(index, new FakeEmbedder(null), 0.25, Request(limit: 3, offset: 50));

        Assert.That(page.Engine, Is.EqualTo("elasticsearch"));
        Assert.That(page.Total, Is.EqualTo(80));
        Assert.That(page.Results.Select(r => r.Slug), Is.EqualTo((string[])["s11", "s12", "s13"]));
        Assert.That(beyond.Results, Is.Empty, "a page at offset 50 or more is empty while the total says there is more");
        Assert.That(index.Bodies, Has.None.StartWith("{\"knn\""));
    }

    [Test]
    public async Task A_blank_text_browses_newest_first_with_the_browse_form_of_each_result_and_an_empty_query()
    {
        var index = new FakeIndex(true, _ => Answer(12, "a", "b").Replace("\"_score\":10", "\"_score\":5", StringComparison.Ordinal));
        var embedder = new FakeEmbedder(new float[384]);

        var outcome = await RunAsync(index, embedder, 0.25, Request(q: "  \t", language: "en", limit: 5, offset: 10));

        Assert.That(index.Bodies.Single(), Does.StartWith("{\"query\":{\"bool\":{\"must\":[{\"match_all\":{}}]"));
        Assert.That(embedder.Calls, Is.Zero);
        Assert.That(outcome.Query, Is.Empty);
        Assert.That(outcome.Total, Is.EqualTo(12));
        Assert.That(outcome.Results.Select(r => r.Score), Is.All.Zero);
        Assert.That(outcome.Engine, Is.EqualTo("elasticsearch"));
    }

    [Test]
    public async Task The_text_is_answered_as_it_came_untrimmed()
    {
        var outcome = await RunAsync(new FakeIndex(true, _ => Answer(3, "a", "b", "c")), new FakeEmbedder(null), 0, Request(q: "  patience "));

        Assert.That(outcome.Query, Is.EqualTo("  patience "));
    }

    [Test]
    public async Task An_engine_that_is_not_configured_is_a_failure_with_no_fallback()
    {
        var index = new FakeIndex(false, _ => throw new InvalidOperationException("must not be called"));

        await Assert.ThatAsync(() => RunAsync(index, new FakeEmbedder(null), 0, Request()), Throws.InstanceOf<SearchUnavailableException>());
        Assert.That(index.Bodies, Is.Empty);
    }

    [TestCase("unavailable")]
    [TestCase("garbage")]
    public async Task An_engine_that_fails_or_answers_with_garbage_is_a_failure_with_no_fallback(string how)
    {
        var index = new FakeIndex(true, _ => how == "garbage" ? "<html>502</html>" : throw new SearchUnavailableException("Elasticsearch answered 500"));

        await Assert.ThatAsync(() => RunAsync(index, new FakeEmbedder(null), 0, Request()), Throws.InstanceOf<SearchUnavailableException>());
    }

    [Test]
    public async Task A_failure_of_the_meaning_half_after_a_vector_is_the_engines_failure()
    {
        var index = new FakeIndex(true, body => body.StartsWith("{\"knn\"", StringComparison.Ordinal) ? throw new SearchUnavailableException("Elasticsearch answered 400") : Answer(5, "a"));

        await Assert.ThatAsync(() => RunAsync(index, new FakeEmbedder([1f]), 0.25, Request()), Throws.InstanceOf<SearchUnavailableException>());
    }

    [Test]
    public async Task No_request_goes_anywhere_but_the_lecture_index_so_no_analytics_event_is_written()
    {
        var index = new FakeIndex(true, _ => Answer(3, "a", "b", "c"));

        _ = await RunAsync(index, new FakeEmbedder(null), 0, Request());

        Assert.That(index.Bodies.Select(b => Encoding.UTF8.GetByteCount(b)), Is.All.GreaterThan(0));
        Assert.That(index.Bodies, Has.All.Not.Contain("tsr-analytics"));
    }
}
