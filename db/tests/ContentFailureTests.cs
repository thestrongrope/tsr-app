using System.Net;
using NUnit.Framework;
using Npgsql;
using Tsr.Content.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Issue 100, failure pins on content as it is (CON-R5, R6, R17, R18): what a caller sees when a stored table cannot be read, and what a content copy does when the database
/// fails under it. A thrown failure is asserted by the SqlState of the database error inside it, never its type. The one place a type name is recorded is the body of a 500 from the two routes outside /api/v1 (CON-R17): the test host answers
/// with the developer error page, whose first line names Npgsql's own exception, which the conversion keeps. Each case runs on its own copy of the database, so a revoked right or a trigger never reaches another test.
/// </summary>
public sealed class ContentFailureTests
{
    private static readonly HttpMethod Get = HttpMethod.Get;

    // Which reads need which table: the categories answer counts articles by default, so it reads two; the article, the list and the tags read published_articles alone.
    // With includeArticleCounts=false the query still names published_articles, but PostgreSQL never checks the right on a branch the bound value switches off,
    // so that one read answers 200 while the table is unreadable.
    private const string CountsOff = "/api/v1/taxonomies/categories?includeArticleCounts=false";

    private static readonly Dictionary<string, string[]> LibraryReads = new()
    {
        ["published_articles"] =
        [
            "/api/v1/articles",
            "/api/v1/articles/a-first-look-at-margin-notes",
            "/api/v1/taxonomies/categories",
            CountsOff,
            "/api/v1/taxonomies/tags",
        ],
        ["categories"] = ["/api/v1/taxonomies/categories", "/api/v1/taxonomies/categories?includeArticleCounts=false&hierarchical=false"],
        ["publications"] = ["/api/v1/publications", "/api/v1/publications?language=english"],
    };

    [TestCase("published_articles")]
    [TestCase("categories")]
    [TestCase("publications")]
    public async Task Unreadable_library_tables_fail_each_library_read(string table)
    {
        await using var run = await GoldenScenario.StartAsync("failure-lib-" + table, set: ContentGolden.Set);
        await run.ExecuteAsync($"revoke select on content.{table} from tsr_app");

        foreach (var path in LibraryReads[table])
        {
            var reply = await run.SendAsync((int?)null, Get, path);

            var expected = table == "published_articles" && path == CountsOff ? HttpStatusCode.OK : HttpStatusCode.InternalServerError;
            Assert.That(reply.Status, Is.EqualTo(expected), path + ": " + reply.Body);
            if (expected == HttpStatusCode.InternalServerError)
            {
                Assert.That(reply.Json!["success"]!.GetValue<bool>(), Is.False, path);
                Assert.That(reply.Json!["error"]!["code"]!.GetValue<string>(), Is.EqualTo("INTERNAL_ERROR"), path);
            }
        }
    }

    [TestCase("holy_quran", "/holy-quran")]
    [TestCase("articles", "/articles")]
    public async Task Unreadable_tables_fail_the_surah_list_and_the_old_list(string table, string path)
    {
        await using var run = await GoldenScenario.StartAsync("failure-" + table, set: ContentGolden.Set);
        await run.ExecuteAsync($"revoke select on content.{table} from tsr_app");

        var reply = await run.SendAsync(table == "holy_quran" ? ContentGolden.Member : null, Get, path);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.InternalServerError), reply.Body);
        Assert.That(reply.Body, Does.Contain($"42501: permission denied for table {table}"));
    }

    [Test]
    public async Task A_copy_and_a_load_on_unreadable_data_change_nothing()
    {
        using var files = new ContentTestFiles();
        var changed = ChangedSet(files);
        await using var run = await GoldenScenario.StartAsync("failure-copy-state", set: ContentGolden.Set, settings: Directory(changed));
        await run.ExecuteAsync("revoke select on content.refresh_state from tsr_app");
        var before = await StoredAsync(run);

        await FailsAsync("42501", () => ContentGolden.TickAsync(run.Services, changed, ContentGolden.ClockAfter(5)));
        await FailsAsync("42501", () => ContentModule.LoadContentAsync(run.Services, CancellationToken.None));

        Assert.That(await StoredAsync(run), Is.EqualTo(before));
    }

    [Test]
    public async Task A_copy_that_fails_part_way_keeps_the_last_set()
    {
        using var files = new ContentTestFiles();
        var changed = ChangedSet(files);
        await using var run = await GoldenScenario.StartAsync("failure-copy-midway", set: ContentGolden.Set, settings: Directory(changed));
        await run.ExecuteAsync(
            """
            create function content.fail_state() returns trigger language plpgsql as
            $$ begin raise exception 'state unavailable (test)'; end $$;
            create trigger fail_state before update on content.refresh_state for each row execute function content.fail_state();
            """);
        var before = await StoredAsync(run);

        await FailsAsync("P0001", () => ContentGolden.TickAsync(run.Services, changed, ContentGolden.ClockAfter(5)));
        Assert.That(await StoredAsync(run), Is.EqualTo(before), "after the tick");
        await FailsAsync("P0001", () => ContentModule.LoadContentAsync(run.Services, CancellationToken.None));
        Assert.That(await StoredAsync(run), Is.EqualTo(before), "after the load");
    }

    // Entity Framework threw when its update of the state row changed no row; the SQL that replaced it must too, or a copy would commit a set with no state behind it.
    [Test]
    public async Task A_state_write_that_changes_no_row_fails_and_keeps_the_last_set()
    {
        using var files = new ContentTestFiles();
        var changed = ChangedSet(files);
        await using var run = await GoldenScenario.StartAsync("failure-copy-state-no-row", set: ContentGolden.Set, settings: Directory(changed));
        await run.ExecuteAsync(
            """
            create function content.skip_state() returns trigger language plpgsql as
            $$ begin return null; end $$;
            create trigger skip_state before update on content.refresh_state for each row execute function content.skip_state();
            """);
        var before = await StoredAsync(run);

        _ = await Assert.CatchAsync(async () => await ContentGolden.TickAsync(run.Services, changed, ContentGolden.ClockAfter(5)), "a store must throw");
        _ = await Assert.CatchAsync(async () => await ContentGolden.TickAsync(run.Services, directory: null, ContentGolden.ClockAfter(6)), "a keep must throw");

        Assert.That(await StoredAsync(run), Is.EqualTo(before));
    }

    private static async Task<List<string>> StoredAsync(GoldenScenario run)
    {
        var rows = await run.QueryAsync("select row_to_json(t)::text from content.published_articles t order by t.slug collate \"C\"");
        rows.AddRange(await run.QueryAsync("select row_to_json(t)::text from content.refresh_state t"));
        return rows;
    }

    // The synthetic set with one article's title changed: a copy of it is a new set, so a copy that did not throw would write.
    private static string ChangedSet(ContentTestFiles files)
    {
        ContentGolden.CopySyntheticInto(files);
        var path = Path.Combine(files.Root, "articles", "2025-10-20-choosing-a-quiet-hour.md");
        File.WriteAllText(path, File.ReadAllText(path).Replace("title: Choosing a Quiet Hour", "title: Choosing a Quieter Hour", StringComparison.Ordinal));
        return files.Root;
    }

    private static Dictionary<string, string> Directory(string path) => new() { ["TSR_CONTENT_DIR"] = path };

    // The call must throw, with a database error of this SqlState inside the failure; the type of the exception is not asserted.
    private static async Task FailsAsync<T>(string sqlState, Func<Task<T>> call)
    {
        var failure = await Assert.CatchAsync(async () => await call(), "the call must throw");
        var database = ContentGolden.Chain(failure!).OfType<PostgresException>().FirstOrDefault();
        Assert.That(database?.SqlState, Is.EqualTo(sqlState), "threw " + failure!.GetType().Name + " with no database error of that state inside it");
    }
}
