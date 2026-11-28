using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The Elasticsearch requests of lecture search (TC-SRCH-R7-02, R9-02 and the body comparison of task 10): the strict and the fuzzy keyword body, the browse body and the kNN body. The stored bodies were produced once by running tsr-web's own
/// <c>searchLectures</c> (<c>web/src/app/api/lib/lectures-search-service.ts</c>) in node against a client that records every request it is given: the exact text of <c>JSON.stringify</c> of each, the index name apart.
/// The one deliberate difference (plan 3.10): every highlight asks for HTML-encoded text, so <c>"encoder":"html"</c> is added after <c>post_tags</c> in each highlight object.
/// </summary>
[TestFixture]
internal sealed class LectureSearchQueryTests
{
    private sealed record Body(string Kind, string Json);

    private sealed record Case(string Q, string? Language, int Limit, int Offset, bool Semantic, float[]? Vector, Body[] Bodies);

    private static readonly Case[] Cases =
    [
        new("patience", null, 20, 0, false, null, [new("Strict", "{\"size\":20,\"from\":0,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":2,\"fragment_size\":150},\"search_phrases\":{\"number_of_fragments\":2,\"fragment_size\":120},\"key_points\":{\"number_of_fragments\":2,\"fragment_size\":150}}},\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"patience\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"patience\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"patience \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"patience\",\"fields\":[\"title^4\",\"excerpt^2\",\"search_phrases^3\",\"key_points^1.5\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"patience patience\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"search_phrases^2\",\"content\",\"tags\"],\"type\":\"best_fields\"}},{\"nested\":{\"path\":\"chapters\",\"query\":{\"multi_match\":{\"query\":\"patience patience\",\"fields\":[\"chapters.title^2\",\"chapters.summary\"],\"type\":\"best_fields\"}},\"score_mode\":\"max\",\"boost\":8,\"inner_hits\":{\"name\":\"matched_chapters\",\"size\":3,\"_source\":[\"chapters.start_sec\",\"chapters.title\",\"chapters.summary\",\"chapters.url\"],\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"chapters.title\":{\"number_of_fragments\":0},\"chapters.summary\":{\"number_of_fragments\":1,\"fragment_size\":160}}}}}}],\"minimum_should_match\":1,\"filter\":[]}}}")]),
        new("Ameerul Momineen tears", "en", 5, 10, false, null, [new("Strict", "{\"size\":5,\"from\":10,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":2,\"fragment_size\":150},\"search_phrases\":{\"number_of_fragments\":2,\"fragment_size\":120},\"key_points\":{\"number_of_fragments\":2,\"fragment_size\":150}}},\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"Ameerul Momineen tears\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"Ameerul Momineen tears\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"imam ali ameerul momineen ali ibn abi talib amirul momineen\",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"tears weep weeping crying cry\",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"Ameerul Momineen tears\",\"fields\":[\"title^4\",\"excerpt^2\",\"search_phrases^3\",\"key_points^1.5\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"Ameerul Momineen tears amirul mominin tears weep weeping crying cry imam ali ali ibn abi talib ali\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"search_phrases^2\",\"content\",\"tags\"],\"type\":\"best_fields\"}},{\"nested\":{\"path\":\"chapters\",\"query\":{\"multi_match\":{\"query\":\"Ameerul Momineen tears amirul mominin tears weep weeping crying cry imam ali ali ibn abi talib ali\",\"fields\":[\"chapters.title^2\",\"chapters.summary\"],\"type\":\"best_fields\"}},\"score_mode\":\"max\",\"boost\":8,\"inner_hits\":{\"name\":\"matched_chapters\",\"size\":3,\"_source\":[\"chapters.start_sec\",\"chapters.title\",\"chapters.summary\",\"chapters.url\"],\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"chapters.title\":{\"number_of_fragments\":0},\"chapters.summary\":{\"number_of_fragments\":1,\"fragment_size\":160}}}}}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"language\":\"en\"}}]}}}"),
            new("Fuzzy", "{\"size\":5,\"from\":10,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":2,\"fragment_size\":150},\"search_phrases\":{\"number_of_fragments\":2,\"fragment_size\":120},\"key_points\":{\"number_of_fragments\":2,\"fragment_size\":150}}},\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"Ameerul Momineen tears\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"Ameerul Momineen tears\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"imam ali ameerul momineen ali ibn abi talib amirul momineen\",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"tears weep weeping crying cry\",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"Ameerul Momineen tears\",\"fields\":[\"title^4\",\"excerpt^2\",\"search_phrases^3\",\"key_points^1.5\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"Ameerul Momineen tears amirul mominin tears weep weeping crying cry imam ali ali ibn abi talib ali\",\"fields\":[\"content\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}},{\"nested\":{\"path\":\"chapters\",\"query\":{\"multi_match\":{\"query\":\"Ameerul Momineen tears amirul mominin tears weep weeping crying cry imam ali ali ibn abi talib ali\",\"fields\":[\"chapters.title^2\",\"chapters.summary\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}},\"score_mode\":\"max\",\"boost\":8,\"inner_hits\":{\"name\":\"matched_chapters\",\"size\":3,\"_source\":[\"chapters.start_sec\",\"chapters.title\",\"chapters.summary\",\"chapters.url\"],\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"chapters.title\":{\"number_of_fragments\":0},\"chapters.summary\":{\"number_of_fragments\":1,\"fragment_size\":160}}}}}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"language\":\"en\"}}]}}}")]),
        new("7usain \"} , {\"match_all\": {}} ", null, 100, 0, false, null, [new("Strict", "{\"size\":100,\"from\":0,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":2,\"fragment_size\":150},\"search_phrases\":{\"number_of_fragments\":2,\"fragment_size\":120},\"key_points\":{\"number_of_fragments\":2,\"fragment_size\":150}}},\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}} \",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}} \",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"7usain \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"{\\\"match_all\\\": \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"{}} \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}} \",\"fields\":[\"title^4\",\"excerpt^2\",\"search_phrases^3\",\"key_points^1.5\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}}  husain \\\"} , {\\\"match_all\\\": {}}  hussain husayn hussein\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"search_phrases^2\",\"content\",\"tags\"],\"type\":\"best_fields\"}},{\"nested\":{\"path\":\"chapters\",\"query\":{\"multi_match\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}}  husain \\\"} , {\\\"match_all\\\": {}}  hussain husayn hussein\",\"fields\":[\"chapters.title^2\",\"chapters.summary\"],\"type\":\"best_fields\"}},\"score_mode\":\"max\",\"boost\":8,\"inner_hits\":{\"name\":\"matched_chapters\",\"size\":3,\"_source\":[\"chapters.start_sec\",\"chapters.title\",\"chapters.summary\",\"chapters.url\"],\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"chapters.title\":{\"number_of_fragments\":0},\"chapters.summary\":{\"number_of_fragments\":1,\"fragment_size\":160}}}}}}],\"minimum_should_match\":1,\"filter\":[]}}}"),
            new("Fuzzy", "{\"size\":100,\"from\":0,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":2,\"fragment_size\":150},\"search_phrases\":{\"number_of_fragments\":2,\"fragment_size\":120},\"key_points\":{\"number_of_fragments\":2,\"fragment_size\":150}}},\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}} \",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}} \",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"7usain \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"{\\\"match_all\\\": \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}},{\"multi_match\":{\"query\":\"{}} \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}} \",\"fields\":[\"title^4\",\"excerpt^2\",\"search_phrases^3\",\"key_points^1.5\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}}  husain \\\"} , {\\\"match_all\\\": {}}  hussain husayn hussein\",\"fields\":[\"content\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}},{\"nested\":{\"path\":\"chapters\",\"query\":{\"multi_match\":{\"query\":\"7usain \\\"} , {\\\"match_all\\\": {}}  husain \\\"} , {\\\"match_all\\\": {}}  hussain husayn hussein\",\"fields\":[\"chapters.title^2\",\"chapters.summary\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}},\"score_mode\":\"max\",\"boost\":8,\"inner_hits\":{\"name\":\"matched_chapters\",\"size\":3,\"_source\":[\"chapters.start_sec\",\"chapters.title\",\"chapters.summary\",\"chapters.url\"],\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"chapters.title\":{\"number_of_fragments\":0},\"chapters.summary\":{\"number_of_fragments\":1,\"fragment_size\":160}}}}}}],\"minimum_should_match\":1,\"filter\":[]}}}")]),
        new("of the", "hi", 20, 0, true, [0.5f, 0.25f, -0.125f], [new("Strict", "{\"size\":50,\"from\":0,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":2,\"fragment_size\":150},\"search_phrases\":{\"number_of_fragments\":2,\"fragment_size\":120},\"key_points\":{\"number_of_fragments\":2,\"fragment_size\":150}}},\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"of the\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"of the\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[],\"boost\":30}},{\"multi_match\":{\"query\":\"of the\",\"fields\":[\"title^4\",\"excerpt^2\",\"search_phrases^3\",\"key_points^1.5\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"of the of se\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"search_phrases^2\",\"content\",\"tags\"],\"type\":\"best_fields\"}},{\"nested\":{\"path\":\"chapters\",\"query\":{\"multi_match\":{\"query\":\"of the of se\",\"fields\":[\"chapters.title^2\",\"chapters.summary\"],\"type\":\"best_fields\"}},\"score_mode\":\"max\",\"boost\":8,\"inner_hits\":{\"name\":\"matched_chapters\",\"size\":3,\"_source\":[\"chapters.start_sec\",\"chapters.title\",\"chapters.summary\",\"chapters.url\"],\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"chapters.title\":{\"number_of_fragments\":0},\"chapters.summary\":{\"number_of_fragments\":1,\"fragment_size\":160}}}}}}],\"minimum_should_match\":1,\"filter\":[{\"term\":{\"language\":\"hi\"}}]}}}"),
            new("Knn", "{\"knn\":{\"field\":\"embedding\",\"query_vector\":[0.5,0.25,-0.125],\"k\":50,\"num_candidates\":200,\"filter\":[{\"term\":{\"language\":\"hi\"}}]},\"size\":50,\"_source\":{\"excludes\":[\"content\",\"embedding\"]}}")]),
        new("zorvath", null, 20, 40, true, [1f, 0f], [new("Strict", "{\"size\":50,\"from\":0,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":2,\"fragment_size\":150},\"search_phrases\":{\"number_of_fragments\":2,\"fragment_size\":120},\"key_points\":{\"number_of_fragments\":2,\"fragment_size\":150}}},\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"zorvath\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"zorvath\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"zorvath \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"zorvath\",\"fields\":[\"title^4\",\"excerpt^2\",\"search_phrases^3\",\"key_points^1.5\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"zorvath zorvas\",\"fields\":[\"title^2\",\"excerpt^1.5\",\"search_phrases^2\",\"content\",\"tags\"],\"type\":\"best_fields\"}},{\"nested\":{\"path\":\"chapters\",\"query\":{\"multi_match\":{\"query\":\"zorvath zorvas\",\"fields\":[\"chapters.title^2\",\"chapters.summary\"],\"type\":\"best_fields\"}},\"score_mode\":\"max\",\"boost\":8,\"inner_hits\":{\"name\":\"matched_chapters\",\"size\":3,\"_source\":[\"chapters.start_sec\",\"chapters.title\",\"chapters.summary\",\"chapters.url\"],\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"chapters.title\":{\"number_of_fragments\":0},\"chapters.summary\":{\"number_of_fragments\":1,\"fragment_size\":160}}}}}}],\"minimum_should_match\":1,\"filter\":[]}}}"),
            new("Fuzzy", "{\"size\":50,\"from\":0,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]},\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"title\":{\"number_of_fragments\":0},\"excerpt\":{\"number_of_fragments\":1,\"fragment_size\":200},\"content\":{\"number_of_fragments\":2,\"fragment_size\":150},\"search_phrases\":{\"number_of_fragments\":2,\"fragment_size\":120},\"key_points\":{\"number_of_fragments\":2,\"fragment_size\":150}}},\"query\":{\"bool\":{\"should\":[{\"match_phrase\":{\"title\":{\"query\":\"zorvath\",\"boost\":15,\"slop\":3}}},{\"match_phrase\":{\"content\":{\"query\":\"zorvath\",\"boost\":5,\"slop\":3}}},{\"bool\":{\"must\":[{\"multi_match\":{\"query\":\"zorvath \",\"fields\":[\"title^3\",\"excerpt\",\"search_phrases^2\"],\"type\":\"best_fields\"}}],\"boost\":30}},{\"multi_match\":{\"query\":\"zorvath\",\"fields\":[\"title^4\",\"excerpt^2\",\"search_phrases^3\",\"key_points^1.5\",\"content\",\"tags^1.5\"],\"type\":\"cross_fields\",\"operator\":\"or\"}},{\"multi_match\":{\"query\":\"zorvath zorvas\",\"fields\":[\"content\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}},{\"nested\":{\"path\":\"chapters\",\"query\":{\"multi_match\":{\"query\":\"zorvath zorvas\",\"fields\":[\"chapters.title^2\",\"chapters.summary\"],\"type\":\"best_fields\",\"fuzziness\":\"AUTO\"}},\"score_mode\":\"max\",\"boost\":8,\"inner_hits\":{\"name\":\"matched_chapters\",\"size\":3,\"_source\":[\"chapters.start_sec\",\"chapters.title\",\"chapters.summary\",\"chapters.url\"],\"highlight\":{\"pre_tags\":[\"<em>\"],\"post_tags\":[\"</em>\"],\"fields\":{\"chapters.title\":{\"number_of_fragments\":0},\"chapters.summary\":{\"number_of_fragments\":1,\"fragment_size\":160}}}}}}],\"minimum_should_match\":1,\"filter\":[]}}}"),
            new("Knn", "{\"knn\":{\"field\":\"embedding\",\"query_vector\":[1,0],\"k\":50,\"num_candidates\":200},\"size\":50,\"_source\":{\"excludes\":[\"content\",\"embedding\"]}}")]),
        new("   ", "ar", 7, 3, false, null, [new("Browse", "{\"query\":{\"bool\":{\"must\":[{\"match_all\":{}}],\"filter\":[{\"term\":{\"language\":\"ar\"}}]}},\"sort\":[{\"publishedDate\":{\"order\":\"desc\",\"missing\":\"_last\"}}],\"size\":7,\"from\":3,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]}}")]),
        new("", null, 20, 0, false, null, [new("Browse", "{\"query\":{\"bool\":{\"must\":[{\"match_all\":{}}],\"filter\":[]}},\"sort\":[{\"publishedDate\":{\"order\":\"desc\",\"missing\":\"_last\"}}],\"size\":20,\"from\":0,\"track_total_hits\":true,\"_source\":{\"excludes\":[\"content\",\"embedding\"]}}")]),
    ];

    public static IEnumerable<TestCaseData> Inputs => Cases.Select(c => new TestCaseData(c).SetArgDisplayNames(c.Q.Length == 0 ? "(empty)" : c.Q.Trim().Length == 0 ? "(blank)" : c.Q));

    private static string WithHtmlEncoder(string websiteBody) =>
        websiteBody.Replace("\"post_tags\":[\"</em>\"],", "\"post_tags\":[\"</em>\"],\"encoder\":\"html\",", StringComparison.Ordinal);

    private static string Written(Case c, Body body) => body.Kind switch
    {
        "Strict" => LectureSearchQuery.Keyword(c.Q, c.Language, c.Limit, c.Offset, c.Semantic, fuzzy: false),
        "Fuzzy" => LectureSearchQuery.Keyword(c.Q, c.Language, c.Limit, c.Offset, c.Semantic, fuzzy: true),
        "Browse" => LectureSearchQuery.Browse(c.Language, c.Limit, c.Offset),
        "Knn" => LectureSearchQuery.Knn(c.Vector!, c.Language),
        _ => throw new InvalidOperationException(body.Kind),
    };

    [TestCaseSource(nameof(Inputs))]
    public void Every_body_equals_the_one_tsr_web_sends(object testCase)
    {
        var expected = (Case)testCase;

        foreach (var body in expected.Bodies)
        {
            Assert.That(Written(expected, body), Is.EqualTo(WithHtmlEncoder(body.Json)), body.Kind);
        }
    }

    [Test]
    public void The_fuzzy_body_confines_the_expanded_clause_to_content_and_makes_the_chapters_fuzzy_and_nothing_else()
    {
        using var strict = JsonDocument.Parse(LectureSearchQuery.Keyword("patience", null, 20, 0, semantic: false, fuzzy: false));
        using var fuzzy = JsonDocument.Parse(LectureSearchQuery.Keyword("patience", null, 20, 0, semantic: false, fuzzy: true));

        var strictShould = strict.RootElement.GetProperty("query").GetProperty("bool").GetProperty("should");
        var fuzzyShould = fuzzy.RootElement.GetProperty("query").GetProperty("bool").GetProperty("should");

        for (var i = 0; i < 4; i++)
        {
            Assert.That(fuzzyShould[i].GetRawText(), Is.EqualTo(strictShould[i].GetRawText()), "clause " + i);
        }

        Assert.That(strictShould[4].GetProperty("multi_match").TryGetProperty("fuzziness", out _), Is.False);
        Assert.That(fuzzyShould[4].GetProperty("multi_match").GetProperty("fields").GetRawText(), Is.EqualTo("""["content"]"""));
        Assert.That(fuzzyShould[4].GetProperty("multi_match").GetProperty("fuzziness").GetString(), Is.EqualTo("AUTO"));
        Assert.That(fuzzyShould[5].GetProperty("nested").GetProperty("query").GetProperty("multi_match").GetProperty("fuzziness").GetString(), Is.EqualTo("AUTO"));
        Assert.That(strictShould[5].GetProperty("nested").GetProperty("query").GetProperty("multi_match").TryGetProperty("fuzziness", out _), Is.False);
    }

    [Test]
    public void The_meaning_layer_asks_for_a_pool_of_fifty_from_the_start_and_the_knn_body_holds_the_same_language_filter()
    {
        using var pool = JsonDocument.Parse(LectureSearchQuery.Keyword("patience", "en", 20, 40, semantic: true, fuzzy: false));
        using var page = JsonDocument.Parse(LectureSearchQuery.Keyword("patience", "en", 20, 40, semantic: false, fuzzy: false));
        using var knn = JsonDocument.Parse(LectureSearchQuery.Knn([0.5f, 0.25f], "en"));
        using var knnAll = JsonDocument.Parse(LectureSearchQuery.Knn([0.5f], null));

        Assert.That(pool.RootElement.GetProperty("size").GetInt32(), Is.EqualTo(50));
        Assert.That(pool.RootElement.GetProperty("from").GetInt32(), Is.Zero);
        Assert.That(page.RootElement.GetProperty("size").GetInt32(), Is.EqualTo(20));
        Assert.That(page.RootElement.GetProperty("from").GetInt32(), Is.EqualTo(40));
        var filter = knn.RootElement.GetProperty("knn").GetProperty("filter");
        Assert.That(filter.GetRawText(), Is.EqualTo("""[{"term":{"language":"en"}}]"""));
        Assert.That(pool.RootElement.GetProperty("query").GetProperty("bool").GetProperty("filter").GetRawText(), Is.EqualTo(filter.GetRawText()));
        Assert.That(knnAll.RootElement.GetProperty("knn").TryGetProperty("filter", out _), Is.False);
    }

    [TestCase(null, null)]
    [TestCase("", null)]
    [TestCase("hi", null)]
    [TestCase("en", null)]
    [TestCase("ar", null)]
    [TestCase("zh-CN", null)]
    [TestCase("abcdefghij", null)]
    [TestCase("abcdefghijk", "Invalid language: at most 10 letters and hyphens")]
    [TestCase("h i", "Invalid language: at most 10 letters and hyphens")]
    [TestCase("hi\"}", "Invalid language: at most 10 letters and hyphens")]
    [TestCase("hi1", "Invalid language: at most 10 letters and hyphens")]
    [TestCase("\u0939\u093f", "Invalid language: at most 10 letters and hyphens")]
    public void The_language_is_a_short_code_of_letters_and_hyphens(string? language, string? refusal) =>
        Assert.That(LectureSearchQuery.ValidateLanguage(language), Is.EqualTo(refusal));

    [TestCase("\"} , {\"match_all\": {}} ")]
    [TestCase("*:*")]
    public void The_callers_text_and_language_are_only_ever_json_string_values(string text)
    {
        using var keyword = JsonDocument.Parse(LectureSearchQuery.Keyword(text, text, 20, 0, false, false));
        Assert.That(PropertyNames(keyword.RootElement), Does.Not.Contain("match_all"));
        Assert.That(keyword.RootElement.GetProperty("query").GetProperty("bool").GetProperty("filter")[0].GetProperty("term").GetProperty("language").GetString(), Is.EqualTo(text));
    }

    private static List<string> PropertyNames(JsonElement element)
    {
        var names = new List<string>();
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (var property in element.EnumerateObject())
                {
                    names.Add(property.Name);
                    names.AddRange(PropertyNames(property.Value));
                }

                break;
            case JsonValueKind.Array:
                foreach (var item in element.EnumerateArray())
                {
                    names.AddRange(PropertyNames(item));
                }

                break;
        }

        return names;
    }
}
