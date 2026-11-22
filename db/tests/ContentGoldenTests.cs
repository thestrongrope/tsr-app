using NUnit.Framework;
using Tsr.Content.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// Characterisation of the content domain (issue 100): every answer, every stored row and the copy's state are recorded on the code as it was, in db/tests/golden/content,
/// so the conversion off Entity Framework can be compared byte for byte. Nothing here asserts a value written by hand: a golden file is the expectation.
/// </summary>
public sealed class ContentGoldenTests
{
    public static IEnumerable<string> RouteScenarios => ContentGoldenScenarios.Library.Keys.Concat(ContentGoldenScenarios.Others.Keys);

    [TestCaseSource(nameof(RouteScenarios))]
    public async Task Every_content_route_answers_as_recorded(string scenario)
    {
        await using var run = await GoldenScenario.StartAsync(scenario, set: ContentGolden.Set);

        await (ContentGoldenScenarios.Library.TryGetValue(scenario, out var route) ? route(run) : ContentGoldenScenarios.Others[scenario](run));

        GoldenScenario.Check(scenario, run.Transcript, ContentGolden.Set);
    }

    private const string EmptyTables = "truncate content.published_articles, content.categories, content.publications, content.refresh_state";

    [Test]
    public async Task A_copy_stores_the_recorded_rows_and_state()
    {
        await using var run = await GoldenScenario.StartAsync(CopyStoresRows, set: ContentGolden.Set);
        await StoreAndRecordAsync(run);
        GoldenScenario.Check(CopyStoresRows, run.Transcript, ContentGolden.Set);
    }

    internal const string CopyStoresRows = "copy-stores-rows";
    internal const string CopyKeepPaths = "copy-keep-paths";

    /// <summary>The store path: two copies over a run's database, written to its transcript. Shared with the pool test, which runs it on a pool of one.</summary>
    internal static async Task StoreAndRecordAsync(GoldenScenario run)
    {
        await run.ExecuteAsync(EmptyTables);
        using var files = new ContentTestFiles();

        // The first copy is an insert of the state row, the second an update of it; the clock moves between them, so an unset time shows.
        var first = await ContentGolden.TickAsync(run.Services, ContentGolden.SyntheticDirectory, ContentGolden.ClockAfter(1));
        run.Note("copy 1: " + ContentGolden.Describe(first));
        await run.AppendRowsAsync("the first copy");

        ContentGolden.CopySyntheticInto(files);
        var quiet = Path.Combine(files.Root, "articles", "2025-10-20-choosing-a-quiet-hour.md");
        await File.WriteAllTextAsync(quiet, (await File.ReadAllTextAsync(quiet)).Replace("title: Choosing a Quiet Hour", "title: Choosing a Quieter Hour", StringComparison.Ordinal));
        var second = await ContentGolden.TickAsync(run.Services, files.Root, ContentGolden.ClockAfter(6));
        run.Note("copy 2: " + ContentGolden.Describe(second));
        await run.AppendRowsAsync("the second copy");

        Assert.That(first.Result, Is.EqualTo(RefreshResult.Refreshed));
        Assert.That(second.Result, Is.EqualTo(RefreshResult.Refreshed));
    }

    [Test]
    public async Task The_keep_and_unchanged_paths_record_the_recorded_state()
    {
        await using var run = await GoldenScenario.StartAsync(CopyKeepPaths, set: ContentGolden.Set);
        await KeepAndRecordAsync(run);
        GoldenScenario.Check(CopyKeepPaths, run.Transcript, ContentGolden.Set);
    }

    /// <summary>The keep and unchanged paths over a run's database, written to its transcript. Shared with the pool test.</summary>
    internal static async Task KeepAndRecordAsync(GoldenScenario run)
    {
        await run.ExecuteAsync(EmptyTables);
        using var files = new ContentTestFiles();
        var minute = 0;

        async Task StepAsync(string label, string? directory)
        {
            minute++;
            var outcome = await ContentGolden.TickAsync(run.Services, directory, ContentGolden.ClockAfter(minute));
            run.Note("step " + minute + ", " + label + ": " + ContentGolden.Describe(outcome));
            await run.AppendRowsAsync("step " + minute + ", " + label);
        }

        await StepAsync("no directory", null);
        foreach (var slug in (string[])["one", "two", "three", "four"])
        {
            files.Article(slug);
        }

        files.Category("shared-category", "title: Shared\norder: 1");
        await StepAsync("a good set", files.Root);
        await StepAsync("the same set", files.Root);
        files.Write("articles", "broken.md", "---\ntitle: [never closed\nstatus: publish\n---\nBody\n");
        await StepAsync("a malformed file", files.Root);
        files.Delete("articles", "broken.md");
        files.Write("articles", "big.md", "---\ntitle: Big\nslug: big\npublishedDate: '2024-01-01T08:00:00.000Z'\nstatus: publish\n---\n" + new string('x', (int)ContentFiles.MaxFileBytes));
        await StepAsync("a file over the size limit", files.Root);
        files.Delete("articles", "big.md");
        foreach (var slug in (string[])["one", "two", "three", "four"])
        {
            files.Article(slug, status: "draft");
        }

        await StepAsync("no published article", files.Root);
        files.Article("one");
        foreach (var slug in (string[])["two", "three", "four"])
        {
            files.Delete("articles", slug + ".md");
        }

        await StepAsync("one article of the last four", files.Root);
    }
}
