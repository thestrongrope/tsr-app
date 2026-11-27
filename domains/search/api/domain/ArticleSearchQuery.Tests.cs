using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The article search body (TC-SRCH-R1-02, R1-03, Q3-01) and the reading of its answer. The stored bodies were produced once by running tsr-web's own
/// <c>searchArticlesElasticsearch</c> (<c>web/src/app/api/lib/search-service.ts</c> at commit 109927c) in node against a client that records the request it is given;
/// they are the exact text of <c>JSON.stringify</c> of what it sent, the index name apart.
/// </summary>
[TestFixture]
internal sealed class ArticleSearchQueryTests
{
    private sealed record Case(string Q, string? Category, int Limit, int Offset, string Body);

    private static readonly Case[] Cases =
    [
        new("patience", null, 20, 0, "{\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"patience\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"patience\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"patience \",\"fields\":[\"title^3\",\"excerpt\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"patience\",\"fields\":[\"title^4\",\"excerpt^2\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"patience patience\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"content\",\"tags\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"status\":\"publish\"}}]}},\"size\":20,\"from\":0,\"_source\":{\"excludes\":[\"content_embedding\",\"title_embedding\",\"content\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":3,\"fragment_size\":150}}}}"),
        new("Ameerul Momineen tears", "karbala", 5, 10, "{\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"Ameerul Momineen tears\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"Ameerul Momineen tears\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"imam ali ameerul momineen ali ibn abi talib amirul momineen\",\"fields\":[\"title^3\",\"excerpt\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"tears weep weeping crying cry\",\"fields\":[\"title^3\",\"excerpt\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"Ameerul Momineen tears\",\"fields\":[\"title^4\",\"excerpt^2\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"Ameerul Momineen tears amirul mominin tears weep weeping crying cry imam ali ali ibn abi talib ali\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"content\",\"tags\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"status\":\"publish\"}},{\"terms\":{\"categories\":[\"karbala\"]}}]}},\"size\":5,\"from\":10,\"_source\":{\"excludes\":[\"content_embedding\",\"title_embedding\",\"content\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":3,\"fragment_size\":150}}}}"),
        new("of the", null, 20, 0, "{\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"of the\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"of the\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[],\"boost\":30}},{\"multi_match\":{\"query\":\"of the\",\"fields\":[\"title^4\",\"excerpt^2\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"of the of se\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"content\",\"tags\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"status\":\"publish\"}}]}},\"size\":20,\"from\":0,\"_source\":{\"excludes\":[\"content_embedding\",\"title_embedding\",\"content\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":3,\"fragment_size\":150}}}}"),
        new("7usain Fatimah", null, 100, 0, "{\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"7usain Fatimah\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"7usain Fatimah\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"7usain \",\"fields\":[\"title^3\",\"excerpt\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"fatimah \",\"fields\":[\"title^3\",\"excerpt\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"7usain Fatimah\",\"fields\":[\"title^4\",\"excerpt^2\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"7usain Fatimah husain fatima hussain husayn hussein\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"content\",\"tags\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"status\":\"publish\"}}]}},\"size\":100,\"from\":0,\"_source\":{\"excludes\":[\"content_embedding\",\"title_embedding\",\"content\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":3,\"fragment_size\":150}}}}"),
        new("\"} , {\"match_all\": {}} ", null, 20, 0, "{\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"\\\"} , {\\\"match_all\\\": {}} \",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"\\\"} , {\\\"match_all\\\": {}} \",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"{\\\"match_all\\\": \",\"fields\":[\"title^3\",\"excerpt\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"{}} \",\"fields\":[\"title^3\",\"excerpt\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"\\\"} , {\\\"match_all\\\": {}} \",\"fields\":[\"title^4\",\"excerpt^2\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"\\\"} , {\\\"match_all\\\": {}}  \\\"} , {\\\"match_all\\\": {}} \",\"fields\":[\"title^2\",\"excerpt^1.5\",\"content\",\"tags\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"status\":\"publish\"}}]}},\"size\":20,\"from\":0,\"_source\":{\"excludes\":[\"content_embedding\",\"title_embedding\",\"content\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":3,\"fragment_size\":150}}}}"),
        new("*:*", null, 1, 0, "{\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"*:*\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"*:*\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"*:* \",\"fields\":[\"title^3\",\"excerpt\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"*:*\",\"fields\":[\"title^4\",\"excerpt^2\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"*:* *:*\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"content\",\"tags\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"status\":\"publish\"}}]}},\"size\":1,\"from\":0,\"_source\":{\"excludes\":[\"content_embedding\",\"title_embedding\",\"content\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":3,\"fragment_size\":150}}}}"),
    ];

    public static IEnumerable<TestCaseData> Inputs => Cases.Select(c => new TestCaseData(c).SetArgDisplayNames(c.Q));

    [TestCaseSource(nameof(Inputs))]
    public void The_body_equals_the_one_tsr_web_sends(object testCase)
    {
        var expected = (Case)testCase;

        Assert.That(ArticleSearchQuery.Body(expected.Q, expected.Category, expected.Limit, expected.Offset), Is.EqualTo(expected.Body));
    }

    [Test]
    public void A_text_with_no_term_left_keeps_the_empty_must_that_matches_every_article()
    {
        using var body = JsonDocument.Parse(ArticleSearchQuery.Body("of the", null, 20, 0));

        var clause = body.RootElement.GetProperty("query").GetProperty("bool").GetProperty("should")[2].GetProperty("bool");

        Assert.That(clause.GetProperty("must").GetArrayLength(), Is.Zero);
        Assert.That(clause.GetProperty("boost").GetInt32(), Is.EqualTo(30));
    }

    [TestCase("\"} , {\"match_all\": {}} ")]
    [TestCase("*:*")]
    [TestCase("a\\\"b\n\u0001")]
    public void The_callers_text_is_only_ever_a_json_string_value(string text)
    {
        using var body = JsonDocument.Parse(ArticleSearchQuery.Body(text, text, 20, 0));

        Assert.That(body.RootElement.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["query", "size", "from", "_source", "highlight"]));
        Assert.That(body.RootElement.GetProperty("query").GetProperty("bool").GetProperty("should").GetArrayLength(), Is.EqualTo(5));
        Assert.That(PropertyNames(body.RootElement), Does.Not.Contain("match_all"));
        var phrase = body.RootElement.GetProperty("query").GetProperty("bool").GetProperty("should")[0].GetProperty("match_phrase").GetProperty("title");
        Assert.That(phrase.GetProperty("query").GetString(), Is.EqualTo(text));
        var filter = body.RootElement.GetProperty("query").GetProperty("bool").GetProperty("filter");
        Assert.That(filter[1].GetProperty("terms").GetProperty("categories")[0].GetString(), Is.EqualTo(text));
    }

    [Test]
    public void Hits_are_read_with_the_websites_defaults_and_written_in_its_field_order()
    {
        const string answer = """
            {"took":3,"hits":{"total":{"value":2},"hits":[
              {"_id":"a","_score":4.5,"_source":{"slug":"a","title":"A","excerpt":"Ex","publishedDate":"2026-01-02","modifiedDate":"2026-01-03","author":"Writer","categories":["c"],"tags":["t"],"language":"ur"},
               "highlight":{"title":["<em>A</em>"]}},
              {"_id":"b","_score":null,"_source":{"slug":"b","title":"B"}}]}}
            """;

        var hits = ArticleSearchQuery.ReadHits(answer);

        Assert.That(hits, Has.Count.EqualTo(2));
        Assert.That(Written(hits[0]), Is.EqualTo(
            """{"id":0,"slug":"a","title":"A","excerpt":"Ex","publishedDate":"2026-01-02","modifiedDate":"2026-01-03","author":"Writer","categories":["c"],"tags":["t"],"language":"ur","readingTime":1,"score":4.5,"highlights":{"title":["<em>A</em>"]}}"""));
        Assert.That(Written(hits[1]), Is.EqualTo(
            """{"id":0,"slug":"b","title":"B","publishedDate":"","author":"admin","categories":[],"tags":[],"language":"en","readingTime":1,"score":0}"""));
    }

    [TestCase(20, 0, null)]
    [TestCase(100, 9900, null)]
    [TestCase(1, 9999, null)]
    [TestCase(20, 9990, "Result window too large: offset plus limit must not exceed 10000")]
    [TestCase(100, 9901, "Result window too large: offset plus limit must not exceed 10000")]
    [TestCase(1, int.MaxValue, "Result window too large: offset plus limit must not exceed 10000")]
    public void Offset_plus_limit_may_not_pass_the_engines_result_window(int limit, int offset, string? refusal) =>
        Assert.That(ArticleSearchQuery.Validate("patience", limit, offset), Is.EqualTo(refusal));

    [Test]
    public void A_text_of_200_characters_is_accepted_and_one_more_is_refused()
    {
        Assert.That(ArticleSearchQuery.Validate(new string('a', 200), 20, 0), Is.Null);
        Assert.That(ArticleSearchQuery.Validate(new string('a', 201), 20, 0), Is.EqualTo("Query too long: at most 200 characters"));
    }

    [TestCase("")]
    [TestCase("not json")]
    [TestCase("""{"error":"x"}""")]
    [TestCase("""{"hits":{"hits":[{"_source":{"title":"no slug"}}]}}""")]
    public void An_answer_that_cannot_be_read_is_unavailable_never_empty(string answer)
    {
        Assert.Throws<SearchUnavailableException>(() => ArticleSearchQuery.ReadHits(answer));
    }

    private static string Written(ArticleResult result)
    {
        using var stream = new MemoryStream();
        using (var json = new Utf8JsonWriter(stream))
        {
            result.Write(json);
        }

        return System.Text.Encoding.UTF8.GetString(stream.ToArray());
    }

    private static IEnumerable<string> PropertyNames(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in element.EnumerateObject())
            {
                yield return property.Name;
                foreach (var inner in PropertyNames(property.Value))
                {
                    yield return inner;
                }
            }
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in element.EnumerateArray())
            {
                foreach (var inner in PropertyNames(item))
                {
                    yield return inner;
                }
            }
        }
    }
}
