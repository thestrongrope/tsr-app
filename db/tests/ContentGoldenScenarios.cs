namespace Tsr.Db.Tests;

/// <summary>
/// The scenarios behind content's golden files (issue 100): each is a fixed list of requests on its own copy of the seeded template. Names are short, because
/// PostgreSQL cuts a database name at 63 bytes and a database is named from the scenario.
/// </summary>
internal static class ContentGoldenScenarios
{
    private const string Urdu = "%d9%85%d8%b7%d8%a7%d9%84%d8%b9%db%81-%d9%86%d9%88%d9%b9%d8%b3";

    private const string LongSlug =
        "keeping-long-titles-readable-when-a-heading-runs-past-the-edge-of-the-page-and-the-reader-still-needs-to-find-the-one-idea-that-matters-most-in-a-crowded-set-of-lesson-notes-written-across-a-full-ter";

    private static readonly HttpMethod Get = HttpMethod.Get;

    /// <summary>TC-CON-R1-01, task 1: the six public Library routes.</summary>
    public static IReadOnlyDictionary<string, Func<GoldenScenario, Task>> Library { get; } = new Dictionary<string, Func<GoldenScenario, Task>>
    {
        ["lib-articles-sorts"] = ArticlesSortsAsync,
        ["lib-articles-filters"] = ArticlesFiltersAsync,
        ["lib-articles-paging"] = ArticlesPagingAsync,
        ["lib-articles-304"] = ArticlesConditionalAsync,
        ["lib-article"] = ArticleAsync,
        ["lib-categories"] = CategoriesAsync,
        ["lib-tags"] = TagsAsync,
        ["lib-publications"] = PublicationsAsync,
        ["lib-videos"] = VideosAsync,
    };

    /// <summary>TC-CON-R1-01, task 2: the surah list (signed in or not) and the old article list.</summary>
    public static IReadOnlyDictionary<string, Func<GoldenScenario, Task>> Others { get; } = new Dictionary<string, Func<GoldenScenario, Task>>
    {
        ["holy-quran"] = HolyQuranAsync,
        ["old-article-list"] = run => run.SendAsync(null, Get, "/articles"),
    };

    // The default order, each sort, a sort that does not exist (400) and an empty one (no option).
    private static async Task ArticlesSortsAsync(GoldenScenario run)
    {
        foreach (var query in (string[])["", "?sort=publishedDate:desc", "?sort=publishedDate:asc", "?sort=title:asc", "?sort=title:desc", "?sort=title", "?sort="])
        {
            await run.SendAsync(null, Get, "/api/v1/articles" + query);
        }
    }

    // Each filter alone, a filter that matches nothing, one holding a NUL (nothing is sent to the database), an empty one, a locale in another case, and two filters together.
    private static async Task ArticlesFiltersAsync(GoldenScenario run)
    {
        foreach (var query in (string[])[
            "?category=note-taking", "?category=note", "?category=Note-Taking", "?tag=Night%20Reading", "?tag=Night", "?locale=ur", "?locale=UR", "?locale=en",
            "?q=zorvath", "?q=ZORVATH", "?q=quelmbry", "?q=night%20read", "?q=imam%20ali", "?category=%00", "?tag=a%00b", "?locale=%00", "?q=%00",
            "?category=", "?unknown=1", "?category=practice&tag=Study%20Skills&sort=title:asc&limit=2"])
        {
            await run.SendAsync(null, Get, "/api/v1/articles" + query);
        }
    }

    // limit and offset: clamped, never refused; unreadable text is the default; past the end is one empty page.
    private static async Task ArticlesPagingAsync(GoldenScenario run)
    {
        foreach (var query in (string[])[
            "?limit=1", "?limit=0", "?limit=-3", "?limit=1000", "?limit=abc", "?limit=2x", "?limit=%2B3", "?offset=2&limit=2", "?offset=-5",
            "?offset=11", "?offset=12", "?offset=100000", "?offset=99999999999999", "?limit=5&offset=10", "?limit=100"])
        {
            await run.SendAsync(null, Get, "/api/v1/articles" + query);
        }
    }

    // 304 by If-None-Match (a tag of this answer, and one of another), by If-Modified-Since on the list (equal, a second earlier, one far later), and both headers together.
    private static async Task ArticlesConditionalAsync(GoldenScenario run)
    {
        var first = await run.SendAsync(null, Get, "/api/v1/articles");
        await run.SendAsync(null, Get, "/api/v1/articles", ifNoneMatch: first.ETag);
        await run.SendAsync(null, Get, "/api/v1/articles?limit=1", ifNoneMatch: first.ETag);
        await run.SendAsync(null, Get, "/api/v1/articles", ifNoneMatch: "\"other\"");
        await run.SendAsync(null, Get, "/api/v1/articles", ifModifiedSince: first.LastModified);
        await run.SendAsync(null, Get, "/api/v1/articles", ifModifiedSince: "Wed, 01 Jan 2020 00:00:00 GMT");
        await run.SendAsync(null, Get, "/api/v1/articles", ifModifiedSince: "Tue, 01 Jan 2041 00:00:00 GMT");
        await run.SendAsync(null, Get, "/api/v1/articles", ifModifiedSince: "not a date");
        await run.SendAsync(null, Get, "/api/v1/articles", ifNoneMatch: "\"other\"", ifModifiedSince: first.LastModified);
        await run.SendAsync(null, Get, "/api/v1/articles", ifNoneMatch: first.ETag, ifModifiedSince: "Wed, 01 Jan 2020 00:00:00 GMT");
    }

    // One article with its five related (an ASCII slug, one with raw HTML and a table, the percent-encoded Urdu slug, the 199-character slug), an unknown slug, a draft's slug, and the validators.
    private static async Task ArticleAsync(GoldenScenario run)
    {
        foreach (var slug in (string[])["a-first-look-at-margin-notes", "the-zorvath-timetable", "every-table-tells-a-story", Urdu, LongSlug, "no-such-article", "unfinished-outline-on-margin-notes", "A-First-Look-At-Margin-Notes", "term-planner-for-next-year"])
        {
            await run.SendAsync(null, Get, "/api/v1/articles/" + slug);
        }

        var first = await run.SendAsync(null, Get, "/api/v1/articles/choosing-a-quiet-hour");
        await run.SendAsync(null, Get, "/api/v1/articles/choosing-a-quiet-hour", ifNoneMatch: first.ETag);
        await run.SendAsync(null, Get, "/api/v1/articles/choosing-a-quiet-hour", ifModifiedSince: first.LastModified);
        await run.SendAsync(null, Get, "/api/v1/articles/choosing-a-quiet-hour", ifModifiedSince: "Wed, 01 Jan 2020 00:00:00 GMT");
    }

    // The tree with counts (the default), flat, without counts, and neither; any other value than "false" is on.
    private static async Task CategoriesAsync(GoldenScenario run)
    {
        foreach (var query in (string[])[
            "", "?hierarchical=false", "?hierarchical=true", "?includeArticleCounts=false", "?hierarchical=false&includeArticleCounts=false", "?hierarchical=FALSE", "?hierarchical=0"])
        {
            await run.SendAsync(null, Get, "/api/v1/taxonomies/categories" + query);
        }

        var first = await run.SendAsync(null, Get, "/api/v1/taxonomies/categories");
        await run.SendAsync(null, Get, "/api/v1/taxonomies/categories", ifNoneMatch: first.ETag);
    }

    private static async Task TagsAsync(GoldenScenario run)
    {
        var first = await run.SendAsync(null, Get, "/api/v1/taxonomies/tags");
        await run.SendAsync(null, Get, "/api/v1/taxonomies/tags?limit=1");
        await run.SendAsync(null, Get, "/api/v1/taxonomies/tags", ifNoneMatch: first.ETag);
    }

    // No filter, a language in the case it is stored in, in another case, a prefix, an empty one (no filter), and one nothing has.
    private static async Task PublicationsAsync(GoldenScenario run)
    {
        foreach (var query in (string[])["", "?language=English", "?language=english", "?language=ENGLISH", "?language=Urdu", "?language=Eng", "?language=", "?language=french"])
        {
            await run.SendAsync(null, Get, "/api/v1/publications" + query);
        }

        var first = await run.SendAsync(null, Get, "/api/v1/publications");
        await run.SendAsync(null, Get, "/api/v1/publications", ifNoneMatch: first.ETag);
    }

    // No feed is read in a test host (the channel setting is empty): the list is empty, whatever limit and offset say, and no validator is ever honoured.
    private static async Task VideosAsync(GoldenScenario run)
    {
        foreach (var query in (string[])["", "?limit=1&offset=0", "?limit=0", "?limit=1000&offset=5", "?offset=-1", "?limit=abc"])
        {
            await run.SendAsync(null, Get, "/api/v1/youtube" + query);
        }

        var first = await run.SendAsync(null, Get, "/api/v1/youtube");
        await run.SendAsync(null, Get, "/api/v1/youtube", ifNoneMatch: first.ETag);
    }

    // Signed in as the seeded member (the three surahs, one with no Arabic name and one with characters JSON may escape), and nobody signed in.
    private static async Task HolyQuranAsync(GoldenScenario run)
    {
        await run.SendAsync(ContentGolden.Member, Get, "/holy-quran");
        await run.SendAsync(null, Get, "/holy-quran");
    }
}
