using System.Globalization;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Npgsql;
using NUnit.Framework;
using Tsr.Content.Api;
using Tsr.Content.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// The set-up of content's scenarios (issue 100): the template <c>content_golden_template</c>, migrated as production and seeded
/// with the synthetic content set (copied by today's refresh at the fixed instant), three surahs, four stub articles and one member, and the one call of a content copy
/// that the tests make. A scenario is <see cref="GoldenScenario"/> on <see cref="Set"/>.
/// </summary>
internal static class ContentGolden
{
    /// <summary>A member who can sign in to the surah list: token 900001 or more, an email on .invalid.</summary>
    public const int Member = 900001;

    /// <summary>The seeded surah with Arabic marks, one with no Arabic name, and one with a non-ASCII name holding characters JSON may escape.</summary>
    public const string OddSurahName = "Ünï Sûra \"Q\" <b> + &amp;";

    public static GoldenSet Set { get; } = new("content", "content_golden_template", SeedAsync);

    /// <summary>The synthetic content files of the repository (db/synthetic/content).</summary>
    public static string SyntheticDirectory => Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "content");

    /// <summary>
    /// One content copy over <paramref name="directory"/>, as the worker and the deploy job make it: a new scope of <paramref name="services"/>, no log.
    /// This is the one call of the copy in the tests.
    /// </summary>
    public static async Task<RefreshOutcome> TickAsync(IServiceProvider services, string? directory, TimeProvider clock, Func<CancellationToken, Task>? beforeCommit = null)
    {
        await using var scope = services.CreateAsyncScope();
        return await ContentRefresh.TickAsync(
            scope.ServiceProvider.GetRequiredService<NpgsqlDataSource>(), directory, clock, NullLogger.Instance, beforeCommit, CancellationToken.None);
    }

    /// <summary>What a copy answered, as one line of text.</summary>
    public static string Describe(RefreshOutcome outcome) => outcome.Cause is null ? outcome.Result.ToString() : outcome.Result + ": " + outcome.Cause;

    /// <summary>A clock that always reads <paramref name="minutes"/> minutes after the scenarios' fixed instant.</summary>
    public static TimeProvider ClockAfter(int minutes) => new At(DateTimeOffset.Parse(GoldenScenario.Instant, CultureInfo.InvariantCulture).AddMinutes(minutes));

    /// <summary>Copies the synthetic content files into <paramref name="files"/>, so a test can change one.</summary>
    public static void CopySyntheticInto(ContentTestFiles files)
    {
        foreach (var path in Directory.EnumerateFiles(SyntheticDirectory, "*.md", SearchOption.AllDirectories).Order(StringComparer.Ordinal))
        {
            var folder = Path.GetFileName(Path.GetDirectoryName(path))!;
            if (string.Equals(Path.GetDirectoryName(path), SyntheticDirectory, StringComparison.Ordinal))
            {
                continue;
            }

            files.Write(folder, Path.GetFileName(path), File.ReadAllText(path));
        }
    }

    /// <summary>The exception and everything it wraps, outermost first.</summary>
    public static IEnumerable<Exception> Chain(Exception failure)
    {
        for (var next = failure; next is not null; next = next.InnerException)
        {
            yield return next;
        }
    }

    internal const string CopyStoresRows = "copy-stores-rows";
    internal const string CopyKeepPaths = "copy-keep-paths";

    private const string EmptyTables = "truncate content.published_articles, content.categories, content.publications, content.refresh_state";

    /// <summary>The store path: two copies over a run's database, the second of a changed set. Shared with the pool test, which runs it on a pool of one.</summary>
    internal static async Task StoreAndRecordAsync(GoldenScenario run)
    {
        await run.ExecuteAsync(EmptyTables);
        using var files = new ContentTestFiles();

        // The first copy is an insert of the state row, the second an update of it; the clock moves between them, so an unset time shows.
        var first = await TickAsync(run.Services, SyntheticDirectory, ClockAfter(1));

        CopySyntheticInto(files);
        var quiet = Path.Combine(files.Root, "articles", "2025-10-20-choosing-a-quiet-hour.md");
        await File.WriteAllTextAsync(quiet, (await File.ReadAllTextAsync(quiet)).Replace("title: Choosing a Quiet Hour", "title: Choosing a Quieter Hour", StringComparison.Ordinal));
        var second = await TickAsync(run.Services, files.Root, ClockAfter(6));

        Assert.That(first.Result, Is.EqualTo(RefreshResult.Refreshed));
        Assert.That(second.Result, Is.EqualTo(RefreshResult.Refreshed));
    }

    /// <summary>The keep and unchanged paths over a run's database, each step with the outcome it must have. Shared with the pool test.</summary>
    internal static async Task KeepAndRecordAsync(GoldenScenario run)
    {
        await run.ExecuteAsync(EmptyTables);
        using var files = new ContentTestFiles();
        var minute = 0;

        async Task StepAsync(string expected, string? directory)
        {
            minute++;
            var outcome = await TickAsync(run.Services, directory, ClockAfter(minute));
            Assert.That(Describe(outcome), Is.EqualTo(expected), "step " + minute);
        }

        await StepAsync("Kept: no content directory", null);
        foreach (var slug in (string[])["one", "two", "three", "four"])
        {
            files.Article(slug);
        }

        files.Category("shared-category", "title: Shared\norder: 1");
        await StepAsync("Refreshed", files.Root);
        await StepAsync("Unchanged", files.Root);
        files.Write("articles", "broken.md", "---\ntitle: [never closed\nstatus: publish\n---\nBody\n");
        await StepAsync("Kept: cannot parse file: broken.md", files.Root);
        files.Delete("articles", "broken.md");
        files.Write("articles", "big.md", "---\ntitle: Big\nslug: big\npublishedDate: '2024-01-01T08:00:00.000Z'\nstatus: publish\n---\n" + new string('x', (int)ContentFiles.MaxFileBytes));
        await StepAsync("Kept: file too large: big.md", files.Root);
        files.Delete("articles", "big.md");
        foreach (var slug in (string[])["one", "two", "three", "four"])
        {
            files.Article(slug, status: "draft");
        }

        await StepAsync("Kept: too few articles", files.Root);
        files.Article("one");
        foreach (var slug in (string[])["two", "three", "four"])
        {
            files.Delete("articles", slug + ".md");
        }

        await StepAsync("Kept: too few articles", files.Root);
    }

    private static async Task SeedAsync(string ownerConnection)
    {
        var sql = new StringBuilder();
        sql.Append(CultureInfo.InvariantCulture, $"insert into identity.users (token, email, firebase_uid) values ({Member}, '{MembershipTestKit.EmailOf(Member)}', 'uid-{Member}'); ");
        sql.Append(CultureInfo.InvariantCulture, $"insert into membership.member_profiles (user_id, name, gender) select id, 'Gold Reader', '1' from identity.users where token = {Member}; ");
        sql.Append("delete from content.holy_quran; ");
        sql.Append("insert into content.holy_quran (id, surah, arabic, verses) values ");
        sql.Append("(1, 'Al-Fatiha', 'ٱلْفَاتِحَة', 7), (2, 'Al-Baqara', null, 286), ");
        sql.Append(CultureInfo.InvariantCulture, $"(3, {MembershipTestKit.Quote(OddSurahName)}, 'آلِ عِمْرَان', 200); ");
        // Two published at the same instant (the id breaks the tie), one not yet, one never: the rule of the old list is in its query.
        sql.Append("delete from content.articles; ");
        sql.Append("insert into content.articles (slug, title, body, published_at) values ");
        sql.Append("('stub-old', 'Stub Old', 'Invented body of the old stub.', timestamptz '2025-12-31 23:59:59+00'), ");
        sql.Append("('stub-twin', 'Stub Twin', E'Twin body with <angle brackets>, a plus + and a quote \" and Ünï.', timestamptz '2025-12-31 23:59:59+00'), ");
        sql.Append("('stub-future', 'Stub Future', 'Not yet.', timestamptz '2026-01-01 00:00:01+00'), ");
        sql.Append("('stub-draft', 'Stub Draft', 'Never.', null);");
        await using (var connection = new NpgsqlConnection(ownerConnection))
        {
            await connection.OpenAsync();
            await using var command = new NpgsqlCommand(sql.ToString(), connection);
            await command.ExecuteNonQueryAsync();
        }

        await CopySyntheticSetAsync(ownerConnection);
    }

    // The copy is made by today's refresh, through a host on the template as the limited role. Nothing may stay connected to the template afterwards: "create database ... template" needs it idle.
    private static async Task CopySyntheticSetAsync(string ownerConnection)
    {
        var template = new NpgsqlConnectionStringBuilder(ownerConnection).Database!;
        var app = GoldenScenario.ConnectionTo(template, TestDatabase.AppConnection);
        await using (var factory = TestApi.Create(app))
        {
            _ = factory.Server;
            var outcome = await TickAsync(factory.Services, SyntheticDirectory, GoldenScenario.Clock);
            if (outcome.Result != RefreshResult.Refreshed)
            {
                throw new InvalidOperationException("The synthetic content set was not copied into the template: " + Describe(outcome));
            }
        }

        NpgsqlConnection.ClearAllPools();
    }

    private sealed class At(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
