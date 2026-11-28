using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>The reading of an Elasticsearch lecture answer and the writing of a result in the website's field order (tsr-web <c>toResult</c> and <c>browseLectures</c>).</summary>
[TestFixture]
internal sealed class LectureResultTests
{
    private const string Answer = """
        {"took":2,"hits":{"total":{"value":7,"relation":"eq"},"hits":[
          {"_id":"a","_score":3.5,
           "_source":{"slug":"a","title":"A","url":"https://v/a","excerpt":"Ex","tags":["t"],"language":"hi","publishedDate":"2026-03-01T00:00:00Z","durationSec":840,
                      "chapters":[{"start_sec":0,"title":"One","summary":"S","url":"https://v/a&t=0s"}],"key_points":["k"]},
           "highlight":{"title":["<em>A</em>"]},
           "inner_hits":{"matched_chapters":{"hits":{"hits":[
             {"_source":{"start_sec":0,"title":"One","summary":"S","url":"https://v/a&t=0s"},"highlight":{"chapters.title":["<em>One</em>"]}},
             {"_source":{"start_sec":9,"title":"Two","url":"https://v/a&t=9s"}}]}}}},
          {"_id":"b","_score":null,"_source":{"slug":"b","title":"B","url":"https://v/b"}}]}}
        """;

    [Test]
    public void A_hit_is_written_in_the_websites_field_order_with_its_matched_chapters_and_highlights()
    {
        var page = LectureResult.ReadPage(Answer);

        Assert.That(page.Total, Is.EqualTo(7));
        Assert.That(page.Hits, Has.Count.EqualTo(2));
        Assert.That(Written(page.Hits[0]), Is.EqualTo(
            """{"slug":"a","title":"A","url":"https://v/a","excerpt":"Ex","tags":["t"],"language":"hi","publishedDate":"2026-03-01T00:00:00Z","durationSec":840,"chapters":[{"start_sec":0,"title":"One","summary":"S","url":"https://v/a&t=0s"}],"matchedChapters":[{"start_sec":0,"title":"One","summary":"S","url":"https://v/a&t=0s","highlight":{"title":["<em>One</em>"]}},{"start_sec":9,"title":"Two","url":"https://v/a&t=9s"}],"key_points":["k"],"thumbnail":"https://i.ytimg.com/vi/a/mqdefault.jpg","score":3.5,"highlights":{"title":["<em>A</em>"]}}"""));
    }

    [Test]
    public void A_hit_with_little_in_its_source_gets_the_websites_defaults_and_leaves_out_what_is_absent()
    {
        var page = LectureResult.ReadPage(Answer);

        Assert.That(Written(page.Hits[1]), Is.EqualTo(
            """{"slug":"b","title":"B","url":"https://v/b","tags":[],"language":"en","chapters":[],"matchedChapters":[],"key_points":[],"thumbnail":"https://i.ytimg.com/vi/b/mqdefault.jpg","score":0}"""));
    }

    [Test]
    public void A_browse_result_has_score_zero_no_matched_chapters_and_no_highlights()
    {
        var hit = LectureResult.ReadPage(Answer).Hits[0].ForBrowse();

        Assert.That(Written(hit), Does.Contain("\"matchedChapters\":[]").And.Contain("\"score\":0").And.Not.Contain("highlights"));
    }

    [Test]
    public void The_total_may_be_a_plain_number_and_without_one_it_is_the_number_of_hits()
    {
        Assert.That(LectureResult.ReadPage("""{"hits":{"total":12,"hits":[]}}""").Total, Is.EqualTo(12));
        Assert.That(LectureResult.ReadPage("""{"hits":{"hits":[{"_source":{"slug":"a","title":"A","url":"u"}}]}}""").Total, Is.EqualTo(1));
    }

    [TestCase("")]
    [TestCase("not json")]
    [TestCase("""{"error":"x"}""")]
    [TestCase("""{"hits":{"hits":[{"_source":{"title":"no slug","url":"u"}}]}}""")]
    [TestCase("""{"hits":{"hits":[{"_source":{"slug":"a","url":"u"}}]}}""")]
    public void An_answer_that_cannot_be_read_is_unavailable_never_empty(string answer) =>
        Assert.Throws<SearchUnavailableException>(() => LectureResult.ReadPage(answer));

    private static string Written(LectureResult result)
    {
        using var stream = new MemoryStream();
        using (var json = new Utf8JsonWriter(stream, new JsonWriterOptions { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }))
        {
            result.Write(json);
        }

        return System.Text.Encoding.UTF8.GetString(stream.ToArray());
    }
}
