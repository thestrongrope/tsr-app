using System.Collections.Concurrent;
using System.Globalization;
using System.Reflection;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;
using Tsr.Content.Api;
using Tsr.Content.Api.Domain;
using Tsr.Content.Api.Workers;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The content refresh (LIB-R12, LIB-R20 to LIB-R24) against a real database as the limited role, with a fixed clock: a tick is called directly, never the timer loop.
/// Each test writes its own content directory; the last one reads the synthetic set of db/synthetic/content. The draft case also asks the read routes; elsewhere "the list" is the table.
/// </summary>
public sealed class ContentRefreshTests
{
    private const string Slugs = "select coalesce(string_agg(slug, ',' order by slug), '') from content.published_articles";

    private sealed class MovableClock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;

        public override DateTimeOffset GetUtcNow() => Now;
    }

    private sealed class CaptureLog : ILogger
    {
        public ConcurrentQueue<(LogLevel Level, string Line)> Lines { get; } = new();

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Enqueue((logLevel, formatter(state, exception)));
    }

    private static readonly DateTimeOffset T0 = DateTimeOffset.Parse("2026-11-13T10:00:00+00:00", CultureInfo.InvariantCulture);

    private MovableClock clock = null!;
    private CaptureLog log = null!;
    private ContentTestFiles files = null!;
    private WebApplicationFactory<Program> factory = null!;

    [SetUp]
    public async Task StartAsync()
    {
        clock = new MovableClock(T0);
        log = new CaptureLog();
        files = new ContentTestFiles();
        factory = TestApi.Create();
        await TestDatabase.ExecuteAsync("truncate content.published_articles, content.categories, content.publications, content.refresh_state");
    }

    [TearDown]
    public void Stop()
    {
        factory.Dispose();
        files.Dispose();
    }

    private Task<RefreshOutcome> TickAsync() => TickAsync(files.Root);

    private async Task<RefreshOutcome> TickAsync(string? directory, Func<CancellationToken, Task>? beforeCommit = null)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        return await ContentRefresh.TickAsync(scope.ServiceProvider.GetRequiredService<ContentContext>(), directory, clock, log, beforeCommit, CancellationToken.None);
    }

    private async Task<RefreshOutcome> StoreAsync(ContentSet set)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        return await ContentRefresh.StoreAsync(scope.ServiceProvider.GetRequiredService<ContentContext>(), Result.Ok(set), clock, log, beforeCommit: null, CancellationToken.None);
    }

    private static PublishedArticle AnArticle() => new()
    {
        Slug = "one",
        SlugDecoded = "one",
        LegacyId = 4,
        Title = "One",
        Excerpt = "Words",
        BodyMarkdown = "Body",
        BodyHtml = "<p>Body</p>",
        PublishedAt = T0,
        PublishedDateText = "2026-11-13T10:00:00",
        ModifiedAt = T0,
        ModifiedDateText = "2026-11-13T10:00:00",
        Author = "admin",
        Language = "en",
        ReadingMinutes = 1,
        Categories = ["shared-category"],
        Tags = ["Shared Tag"],
    };

    private static Category ACategory() => new() { Slug = "shared-category", Title = "Shared", Description = "Words", SortOrder = 1, ParentSlug = "top" };

    private static Publication APublication() => new()
    {
        Position = 1,
        Title = "Booklet",
        Summary = "Words",
        Type = "PDF",
        Size = "1 MB",
        Updated = "Jun 2025",
        Language = "English",
        File = "/downloads/booklet.pdf",
        ReadOnlineUrl = "/read/booklet",
        DownloadOnly = false,
    };

    /// <summary>Another value of the same kind. A property of a kind not listed here fails the test, so a new stored field cannot go unproven.</summary>
    private static object Changed(PropertyInfo property, object? value) => value switch
    {
        string text => text + "x",
        int number => number + 1,
        bool flag => !flag,
        DateTimeOffset instant => instant.AddSeconds(1),
        string[] list => (string[])[.. list, "x"],
        _ => throw new AssertionException("teach this test to change " + property.DeclaringType!.Name + "." + property.Name),
    };

    private static Task<string> SlugsAsync() => TestDatabase.ScalarAsync<string>(Slugs, TestDatabase.OwnerConnection);

    private static Task<long> CountAsync(string table) => TestDatabase.ScalarAsync<long>("select count(*) from content." + table, TestDatabase.OwnerConnection);

    private static async Task<Dictionary<string, string?>> ArticleAsync(string slug) =>
        await TestDatabase.RowAsync("select * from content.published_articles where slug = '" + slug + "'") ?? throw new AssertionException("no article " + slug);

    private static async Task<Dictionary<string, string?>> StateAsync() =>
        await TestDatabase.RowAsync("select * from content.refresh_state") ?? throw new AssertionException("no refresh_state row");

    private List<string> Warnings() => [.. log.Lines.Where(l => l.Level == LogLevel.Warning).Select(l => l.Line)];

    private async Task FourArticlesRefreshedAsync()
    {
        foreach (var slug in (string[])["one", "two", "three", "four"])
        {
            files.Article(slug);
        }

        Assert.That((await TickAsync()).Result, Is.EqualTo(RefreshResult.Refreshed));
    }

    [Test]
    public async Task A_draft_is_never_copied_and_appears_in_no_read()
    {
        files.Article("published-one");
        files.Article("published-two");
        files.Article("hidden-draft", status: "draft", day: 9);
        files.Category("shared-category", "title: Shared");

        var outcome = await TickAsync();

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
        Assert.That(await SlugsAsync(), Is.EqualTo("published-one,published-two"));
        Assert.That(
            await TestDatabase.ScalarAsync<long>("select count(*) from content.published_articles where slug like '%draft%' or title like '%draft%' or excerpt like '%draft%'", TestDatabase.OwnerConnection),
            Is.Zero);

        // The reads: the draft shares the category and the tag of the two, and is the newest, so a leak would put it first and raise both counts to 3.
        using var client = factory.CreateClient();
        var list = await client.GetStringAsync("/api/v1/articles");
        var categories = await client.GetStringAsync("/api/v1/taxonomies/categories");
        var tags = await client.GetStringAsync("/api/v1/taxonomies/tags");
        var one = await client.GetStringAsync("/api/v1/articles/published-one");
        var two = await client.GetStringAsync("/api/v1/articles/published-two");
        var draft = await client.GetAsync("/api/v1/articles/hidden-draft");
        Assert.That(list, Does.Contain("\"total\":2").And.Contain("published-one").And.Not.Contain("draft"));
        Assert.That(categories, Does.Contain("\"slug\":\"shared-category\",\"title\":\"Shared\",\"order\":999,\"articleCount\":2").And.Not.Contain("draft"));
        Assert.That(tags, Does.Contain("[{\"name\":\"Shared Tag\",\"slug\":\"shared-tag\",\"articleCount\":2}]").And.Not.Contain("draft"));
        Assert.That(one, Does.Contain("\"relatedArticles\":[{\"id\":0,\"slug\":\"published-two\"").And.Not.Contain("draft"));
        Assert.That(two, Does.Contain("\"relatedArticles\":[{\"id\":0,\"slug\":\"published-one\"").And.Not.Contain("draft"));
        Assert.That(draft.StatusCode, Is.EqualTo(System.Net.HttpStatusCode.NotFound));
    }

    [Test]
    public async Task A_refresh_stores_every_field_of_an_article_and_the_state()
    {
        files.Write("articles", "2025-01-01-any-name.md", """
            ---
            title: "A Stored Title"
            slug: 'stored%2Dslug'
            publishedDate: '2024-05-10T08:15:00.000Z'
            modifiedDate: '2024-05-12T09:00:00.482913'
            excerpt: An excerpt
            tags:
              - First Tag
              - Second Tag
            status: published
            categories: [alpha, beta]
            id: 41
            ---
            ## Heading

            Some body.
            """);

        await TickAsync();

        var article = await ArticleAsync("stored%2Dslug");
        Assert.That(article["slug_decoded"], Is.EqualTo("stored-slug"));
        Assert.That(article["legacy_id"], Is.EqualTo("41"));
        Assert.That(article["title"], Is.EqualTo("A Stored Title"));
        Assert.That(article["excerpt"], Is.EqualTo("An excerpt"));
        Assert.That(article["body_markdown"], Is.EqualTo("## Heading\n\nSome body."));
        Assert.That(article["body_html"], Does.Contain("<h2>Heading</h2>").And.Contain("<p>Some body.</p>"));
        Assert.That(article["published_date_text"], Is.EqualTo("2024-05-10T08:15:00.000Z"));
        Assert.That(article["modified_date_text"], Is.EqualTo("2024-05-12T09:00:00.482913"));
        Assert.That(article["author"], Is.EqualTo("admin"));
        Assert.That(article["language"], Is.EqualTo("en"));
        Assert.That(article["reading_minutes"], Is.EqualTo("1"));
        Assert.That(article["categories"], Is.EqualTo("[\"alpha\",\"beta\"]"));
        Assert.That(article["tags"], Is.EqualTo("[\"First Tag\",\"Second Tag\"]"));
        Assert.That(
            await TestDatabase.ScalarAsync<long>(
                "select count(*) from content.published_articles where published_at = '2024-05-10T08:15:00Z' and modified_at = '2024-05-12T09:00:00.482913Z'", TestDatabase.OwnerConnection),
            Is.EqualTo(1));
        var state = await StateAsync();
        Assert.That(state["id"], Is.EqualTo("1"));
        Assert.That(state["content_hash"], Has.Length.EqualTo(64));
        Assert.That(state["article_count"], Is.EqualTo("1"));
        Assert.That(DateTimeOffset.Parse(state["refreshed_at"]!, CultureInfo.InvariantCulture), Is.EqualTo(T0));
        Assert.That(state["last_failure_at"], Is.Null);
        Assert.That(Warnings(), Is.Empty);
    }

    [Test]
    public async Task A_new_published_file_is_read_on_the_next_tick()
    {
        files.Article("first");
        await TickAsync();
        files.Article("second");

        var outcome = await TickAsync();

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
        Assert.That(await SlugsAsync(), Is.EqualTo("first,second"));
        Assert.That((await StateAsync())["article_count"], Is.EqualTo("2"));
    }

    [Test]
    public async Task A_changed_file_replaces_the_article()
    {
        files.Article("changing", title: "Old Title", body: "Old body.");
        files.Article("steady");
        await TickAsync();
        var steady = await ArticleAsync("steady");
        files.Article("changing", title: "New Title", body: "New body.");

        var outcome = await TickAsync();

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
        var changed = await ArticleAsync("changing");
        Assert.That(changed["title"], Is.EqualTo("New Title"));
        Assert.That(changed["body_markdown"], Is.EqualTo("New body."));
        Assert.That(changed["body_html"], Does.Contain("New body.").And.Not.Contain("Old"));
        Assert.That(await ArticleAsync("steady"), Is.EqualTo(steady));
        Assert.That(await CountAsync("published_articles"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_file_removed_or_set_to_draft_is_no_longer_returned()
    {
        await FourArticlesRefreshedAsync();
        files.Delete("articles", "one.md");
        files.Article("two", status: "draft");

        var outcome = await TickAsync();

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
        Assert.That(await SlugsAsync(), Is.EqualTo("four,three"));
    }

    [Test]
    public async Task A_reader_sees_the_last_complete_set_until_the_refresh_commits()
    {
        files.Article("one");
        files.Article("two");
        await TickAsync();
        files.Article("three");
        string? seenBeforeCommit = null;

        var outcome = await TickAsync(files.Root, async _ => seenBeforeCommit = await SlugsAsync());

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
        Assert.That(seenBeforeCommit, Is.EqualTo("one,two"));
        Assert.That(await SlugsAsync(), Is.EqualTo("one,three,two"));
    }

    [Test]
    public async Task A_refresh_that_throws_before_its_commit_leaves_the_last_set()
    {
        files.Article("one");
        await TickAsync();
        var before = await StateAsync();
        files.Article("two");

        await Assert.ThrowsAsync<InvalidOperationException>(() => TickAsync(files.Root, _ => throw new InvalidOperationException("stop")));

        Assert.That(await SlugsAsync(), Is.EqualTo("one"));
        Assert.That(await StateAsync(), Is.EqualTo(before));
    }

    [TestCase("unparsable", "cannot parse file: broken.md")]
    [TestCase("no-directory", "no content directory")]
    [TestCase("none-published", "too few articles")]
    [TestCase("four-to-one", "too few articles")]
    public async Task A_refresh_that_fails_or_shrinks_keeps_the_last_set_and_records_why(string scenario, string cause)
    {
        await FourArticlesRefreshedAsync();
        var before = await StateAsync();
        clock.Now = T0.AddMinutes(5);
        var directory = files.Root;
        switch (scenario)
        {
            case "unparsable":
                files.Write("articles", "broken.md", "---\ntitle: [never closed\nstatus: publish\n---\nBody\n");
                break;
            case "no-directory":
                directory = Path.Combine(files.Root, "missing");
                break;
            case "none-published":
                foreach (var slug in (string[])["one", "two", "three", "four"])
                {
                    files.Article(slug, status: "draft");
                }

                break;
            default:
                foreach (var slug in (string[])["two", "three", "four"])
                {
                    files.Delete("articles", slug + ".md");
                }

                break;
        }

        var outcome = await TickAsync(directory);

        Assert.That(outcome, Is.EqualTo(new RefreshOutcome(RefreshResult.Kept, cause)));
        Assert.That(await SlugsAsync(), Is.EqualTo("four,one,three,two"));
        var state = await StateAsync();
        Assert.That(state["last_failure_cause"], Is.EqualTo(cause));
        Assert.That(DateTimeOffset.Parse(state["last_failure_at"]!, CultureInfo.InvariantCulture), Is.EqualTo(T0.AddMinutes(5)));
        Assert.That(state["content_hash"], Is.EqualTo(before["content_hash"]));
        Assert.That(state["article_count"], Is.EqualTo("4"));
        Assert.That(state["refreshed_at"], Is.EqualTo(before["refreshed_at"]));
        Assert.That(Warnings(), Has.Count.EqualTo(1));
        Assert.That(Warnings()[0], Does.Contain(cause));
    }

    [TestCase(null)]
    [TestCase("")]
    public async Task The_first_ever_tick_failing_inserts_the_state_row_with_no_refresh_time(string? directory)
    {
        var outcome = await TickAsync(directory);

        Assert.That(outcome, Is.EqualTo(new RefreshOutcome(RefreshResult.Kept, "no content directory")));
        var state = await StateAsync();
        Assert.That(state["id"], Is.EqualTo("1"));
        Assert.That(state["content_hash"], Is.Empty);
        Assert.That(state["article_count"], Is.EqualTo("0"));
        Assert.That(state["refreshed_at"], Is.Null);
        Assert.That(state["last_failure_cause"], Is.EqualTo("no content directory"));
        Assert.That(state["last_failure_at"], Is.Not.Null);
        Assert.That(Warnings(), Has.Count.EqualTo(1));
        Assert.That(await CountAsync("published_articles"), Is.Zero);
    }

    [Test]
    public async Task A_good_refresh_follows_a_first_failure_and_two_failures_keep_one_row()
    {
        await TickAsync(null);
        await TickAsync(null);
        Assert.That(await CountAsync("refresh_state"), Is.EqualTo(1));
        files.Article("one");

        var outcome = await TickAsync();

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
        Assert.That(await SlugsAsync(), Is.EqualTo("one"));
        Assert.That(await CountAsync("refresh_state"), Is.EqualTo(1));
    }

    [Test]
    public async Task Four_articles_down_to_two_is_not_a_halved_refresh()
    {
        await FourArticlesRefreshedAsync();
        files.Delete("articles", "one.md");
        files.Delete("articles", "two.md");

        Assert.That((await TickAsync()).Result, Is.EqualTo(RefreshResult.Refreshed));
    }

    [Test]
    public async Task An_unchanged_set_is_not_written_again()
    {
        files.Article("one");
        await TickAsync();
        var before = await StateAsync();
        clock.Now = T0.AddMinutes(5);

        var outcome = await TickAsync();

        Assert.That(outcome, Is.EqualTo(new RefreshOutcome(RefreshResult.Unchanged)));
        Assert.That(await StateAsync(), Is.EqualTo(before));
        Assert.That(Warnings(), Is.Empty);
    }

    [TestCase("category")]
    [TestCase("publication")]
    [TestCase("tag-order")]
    public async Task A_change_to_one_field_outside_the_article_text_is_still_a_change(string what)
    {
        files.Write("articles", "one.md", "---\ntitle: One\nslug: one\npublishedDate: '2024-01-01T00:00:00.000Z'\nstatus: publish\ntags:\n  - A\n  - B\n---\nBody\n");
        files.Category("shared-category", "title: Shared\norder: 1\ndescription: Old words");
        files.Write("pages", "tsr-publications.md", "---\npublications:\n- title: Booklet\n  size: 1 MB\n  file: /downloads/booklet.pdf\n---\n");
        await TickAsync();
        switch (what)
        {
            case "category":
                files.Category("shared-category", "title: Shared\norder: 1\ndescription: New words");
                break;
            case "publication":
                files.Write("pages", "tsr-publications.md", "---\npublications:\n- title: Booklet\n  size: 2 MB\n  file: /downloads/booklet.pdf\n---\n");
                break;
            default:
                files.Write("articles", "one.md", "---\ntitle: One\nslug: one\npublishedDate: '2024-01-01T00:00:00.000Z'\nstatus: publish\ntags:\n  - B\n  - A\n---\nBody\n");
                break;
        }

        var outcome = await TickAsync();

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
        Assert.That(
            await TestDatabase.ScalarAsync<long>(
                "select (select count(*) from content.categories where description = 'New words') + (select count(*) from content.publications where size = '2 MB') "
                + "+ (select count(*) from content.published_articles where tags = '{B,A}')",
                TestDatabase.OwnerConnection),
            Is.EqualTo(1));
    }

    /// <summary>Every public property of the three stored entities, read by reflection: a field added to an entity later and left out of the hash fails here.</summary>
    private static IEnumerable<PropertyInfo> StoredFields() =>
        ((Type[])[typeof(PublishedArticle), typeof(Category), typeof(Publication)]).SelectMany(type => type.GetProperties(BindingFlags.Public | BindingFlags.Instance));

    [Test]
    public async Task A_change_to_any_stored_field_of_an_article_a_category_or_a_publication_is_a_change()
    {
        Assert.That(StoredFields().Count(), Is.GreaterThanOrEqualTo(31));
        foreach (var field in StoredFields())
        {
            object[] rows = [AnArticle(), ACategory(), APublication()];
            var row = rows.Single(r => r.GetType() == field.DeclaringType);
            Assert.That(field.GetValue(row), Is.Not.Null, field.Name + " needs a value in the test's row");
            field.SetValue(row, Changed(field, field.GetValue(row)));
            await StoreAsync(new ContentSet([AnArticle()], [ACategory()], [APublication()]));

            var outcome = await StoreAsync(new ContentSet([(PublishedArticle)rows[0]], [(Category)rows[1]], [(Publication)rows[2]]));

            Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed), field.DeclaringType!.Name + "." + field.Name + " is not in the change hash");
        }
    }

    [Test]
    public async Task The_same_rows_stored_twice_are_unchanged()
    {
        await StoreAsync(new ContentSet([AnArticle()], [ACategory()], [APublication()]));

        var outcome = await StoreAsync(new ContentSet([AnArticle()], [ACategory()], [APublication()]));

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Unchanged));
    }

    [Test]
    public async Task The_worker_reads_its_directory_from_the_setting_TSR_CONTENT_DIR()
    {
        files.Article("from-the-setting");
        using var configured = factory.WithWebHostBuilder(builder => builder.UseSetting("TSR_CONTENT_DIR", files.Root));
        using var worker = new ContentRefreshWorker(configured.Services.GetRequiredService<IServiceScopeFactory>(), NullLogger<ContentRefreshWorker>.Instance);

        await worker.RunTickAsync(CancellationToken.None);

        Assert.That(await SlugsAsync(), Is.EqualTo("from-the-setting"));
    }

    [Test]
    public async Task A_read_that_throws_keeps_the_last_set_and_records_the_exception_type()
    {
        await FourArticlesRefreshedAsync();
        files.Article("deep", body: new string('>', 50_000) + " SECRET BODY\n");
        const string Cause = "content read failed: ArgumentException in deep.md";

        var outcome = await TickAsync();

        Assert.That(outcome, Is.EqualTo(new RefreshOutcome(RefreshResult.Kept, Cause)));
        Assert.That(await SlugsAsync(), Is.EqualTo("four,one,three,two"));
        Assert.That((await StateAsync())["last_failure_cause"], Is.EqualTo(Cause));
        Assert.That(Warnings(), Has.Count.EqualTo(1));
        Assert.That(Warnings()[0], Does.Contain(Cause).And.Not.Contain("SECRET"));
    }

    [Test]
    public async Task A_front_matter_nested_too_deep_keeps_the_last_set_and_records_why()
    {
        await FourArticlesRefreshedAsync();
        files.Write("articles", "nested.md", "---\nstatus: draft\nk: " + new string('[', 60_000) + "\n---\nBody\n");

        var outcome = await TickAsync();

        Assert.That(outcome, Is.EqualTo(new RefreshOutcome(RefreshResult.Kept, "front matter too deep: nested.md")));
        Assert.That((await StateAsync())["last_failure_cause"], Is.EqualTo("front matter too deep: nested.md"));
        Assert.That(Warnings(), Has.Count.EqualTo(1));
    }

    [Test]
    public async Task A_tick_cancelled_because_the_host_is_stopping_throws_and_records_nothing()
    {
        await FourArticlesRefreshedAsync();
        var before = await StateAsync();
        using var stopping = new CancellationTokenSource();
        await stopping.CancelAsync();

        await using var scope = factory.Services.CreateAsyncScope();
        Assert.That(
            async () => await ContentRefresh.TickAsync(scope.ServiceProvider.GetRequiredService<ContentContext>(), files.Root, clock, log, stopping.Token),
            Throws.InstanceOf<OperationCanceledException>());

        Assert.That(await StateAsync(), Is.EqualTo(before));
        Assert.That(Warnings(), Is.Empty);
    }

    [Test]
    public async Task A_cause_naming_a_long_file_is_cut_to_what_the_column_holds()
    {
        var name = new string('n', 230) + ".md";
        files.Write("articles", name, "---\ntitle: [never closed\n---\n");

        var outcome = await TickAsync();

        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Kept));
        Assert.That(outcome.Cause, Has.Length.EqualTo(200));
        Assert.That(outcome.Cause, Does.StartWith("cannot parse file: nnn"));
        Assert.That((await StateAsync())["last_failure_cause"], Is.EqualTo(outcome.Cause));
    }

    [Test]
    public async Task The_synthetic_content_set_lands_whole()
    {
        var outcome = await TickAsync(Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "content"));

        Assert.That(outcome, Is.EqualTo(new RefreshOutcome(RefreshResult.Refreshed)));
        Assert.That(await CountAsync("published_articles"), Is.EqualTo(12));
        Assert.That(await CountAsync("categories"), Is.EqualTo(7));
        Assert.That(await CountAsync("publications"), Is.EqualTo(3));
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from content.published_articles where legacy_id is not null", TestDatabase.OwnerConnection), Is.EqualTo(6));
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from content.published_articles where char_length(slug) = 199", TestDatabase.OwnerConnection), Is.EqualTo(1));
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from content.published_articles where slug like '\\%d9%' and slug_decoded = 'مطالعہ-نوٹس'", TestDatabase.OwnerConnection), Is.EqualTo(1));
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from content.published_articles where 'Study Skills' = any(tags)", TestDatabase.OwnerConnection), Is.EqualTo(7));
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from content.published_articles where language = 'ur'", TestDatabase.OwnerConnection), Is.EqualTo(1));
        var rawHtml = await ArticleAsync("every-table-tells-a-story");
        Assert.That(rawHtml["body_markdown"], Does.Contain("<script").And.Contain("onerror=").And.Contain("javascript:"));
        Assert.That(rawHtml["body_html"], Does.Contain("<h2>Rows and columns</h2>").And.Contain("<a href=\"\">"));
        Assert.That(rawHtml["body_html"], Does.Not.Contain("<script").And.Not.Contain("onerror=").And.Not.Contain("javascript:").And.Not.Contain("<div").And.Not.Contain("<table"));
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from content.categories where parent_slug is null", TestDatabase.OwnerConnection), Is.EqualTo(3));
        Assert.That(
            await TestDatabase.ScalarAsync<string>("select string_agg(coalesce(language, '-'), ',' order by position) from content.publications", TestDatabase.OwnerConnection),
            Is.EqualTo("English,Urdu,English"));
        Assert.That(Warnings(), Is.Empty);
    }
}
