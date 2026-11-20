using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using NUnit.Framework;
using Tsr.Content.Site;
using Tsr.Shared.Site;

namespace Tsr.Host.Site.Tests;

/// <summary>
/// The Lectures page (issue 88, LEC-R1 to R7): content/lectures/lectures.ndjson of the repository, read at build time
/// (domains/content/site/Lectures.cs) and shown at /lectures/. Invented lectures only, except the one test over the real file.
/// </summary>
public sealed partial class LecturesTests
{
    private DirectoryInfo folder = null!;

    private const string HiddenAttribute = @"(^|\s)hidden(\s|$|=)";
    private static readonly string[] NewestFirst = ["aaaaaaaaaa3", "bbbbbbbbbb2", "aaaaaaaaaa1"];
    private static readonly string[] Groups = ["ur-hi", "ur-hi", "en", "ar", ""];
    private static readonly string[] Buttons = ["", "en", "ur-hi", "ar"];

    [SetUp]
    public void Start() => folder = Directory.CreateTempSubdirectory("tsr-lectures-");

    [TearDown]
    public void Stop() => folder.Delete(recursive: true);

    private static string Quoted(string text) => JsonSerializer.Serialize(text);

    private static string Line(
        string slug = "abcdefghijk",
        string title = "A title",
        string excerpt = "",
        string tags = "[]",
        string language = "\"en\"",
        string date = "2026-01-02T03:04:05Z",
        string duration = "78",
        string chapters = "[]") =>
        string.Create(CultureInfo.InvariantCulture,
            $$"""{"slug":{{Quoted(slug)}},"title":{{Quoted(title)}},"excerpt":{{Quoted(excerpt)}},"tags":{{tags}},"language":{{language}},"publishedDate":{{Quoted(date)}},"durationSec":{{duration}},"chapters":{{chapters}}}""");

    private string Write(params string[] lines)
    {
        var path = Path.Combine(folder.FullName, "lectures.ndjson");
        File.WriteAllText(path, string.Join('\n', lines) + "\n");
        return path;
    }

    private static async Task<string> RenderAsync(string file) =>
        await SiteBuilder.RenderAsync(Lectures.Page(file), []);

    [GeneratedRegex("""<div[^>]*data-lecture data-language="(?<language>[^"]*)"(?<rest>[^>]*)>""")]
    private static partial Regex Card();

    private static string RepositoryFile()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "content", "lectures", "lectures.ndjson")))
        {
            directory = directory.Parent;
        }

        return Path.Combine((directory ?? throw new InvalidOperationException("no content/lectures/lectures.ndjson above the test folder")).FullName, "content", "lectures", "lectures.ndjson");
    }

    [Test]
    public async Task The_page_lists_every_lecture_newest_first()
    {
        var file = Write(
            Line("aaaaaaaaaa1", "Title Old", date: "2021-05-06T07:08:09Z"),
            Line("bbbbbbbbbb2", "Title Beta", date: "2023-05-06T07:08:09Z"),
            Line("aaaaaaaaaa3", "Title Alpha", date: "2023-05-06T07:08:09Z"));

        var page = Lectures.Page(file);
        var html = await SiteBuilder.RenderAsync(page, []);

        Assert.Multiple(() =>
        {
            Assert.That(page.Path, Is.EqualTo("/lectures/"));
            Assert.That(page.Title, Is.EqualTo("Lectures — The Strong Rope"));
            Assert.That(html.IndexOf("Title Alpha", StringComparison.Ordinal), Is.GreaterThan(0));
            Assert.That(html.IndexOf("Title Alpha", StringComparison.Ordinal), Is.LessThan(html.IndexOf("Title Beta", StringComparison.Ordinal)));
            Assert.That(html.IndexOf("Title Beta", StringComparison.Ordinal), Is.LessThan(html.IndexOf("Title Old", StringComparison.Ordinal)));
            Assert.That(Lectures.Read(file).Select(l => l.Slug), Is.EqualTo(NewestFirst));
        });
    }

    [Test]
    public async Task The_repository_lectures_render_and_the_page_stays_under_eight_megabytes()
    {
        var file = RepositoryFile();
        var expected = File.ReadLines(file).Count(line => line.Length > 0);

        var pages = await SiteBuilder.CollectAsync(SiteModules.All, FakeApi.Healthy(), CancellationToken.None);
        var html = await SiteBuilder.RenderAsync(pages.Single(p => p.Path == "/lectures/"), []);
        var bytes = System.Text.Encoding.UTF8.GetByteCount(html);
        TestContext.Out.WriteLine($"The rendered /lectures/ page is {bytes} bytes for {expected} lectures.");

        Assert.Multiple(() =>
        {
            Assert.That(Card().Matches(html), Has.Count.EqualTo(expected));
            Assert.That(bytes, Is.LessThan(8_000_000));
        });
    }

    [Test]
    public async Task A_card_shows_thumbnail_title_excerpt_duration_and_four_tags()
    {
        var file = Write(Line(
            "abcdefghijk", "A <b> title", "An invented excerpt.", "[\"one\",\"two\",\"three\",\"four\",\"five\",\"six\"]", duration: "4081"));

        var html = await RenderAsync(file);

        Assert.Multiple(() =>
        {
            Assert.That(Regex.Matches(html, @"href=""https://www\.youtube\.com/watch\?v=abcdefghijk"""), Has.Count.EqualTo(2));
            Assert.That(Regex.Matches(html, @"target=""_blank"""), Has.Count.GreaterThanOrEqualTo(2));
            Assert.That(html, Does.Contain("rel=\"noopener noreferrer\""));
            Assert.That(html, Does.Contain("src=\"https://i.ytimg.com/vi/abcdefghijk/mqdefault.jpg\""));
            Assert.That(html, Does.Contain("loading=\"lazy\""));
            Assert.That(html, Does.Contain("1:08:01"));
            Assert.That(html, Does.Contain("An invented excerpt."));
            Assert.That(html, Does.Contain(">four<"));
            Assert.That(html, Does.Not.Contain(">five<"));
            Assert.That(html, Does.Contain("A &lt;b&gt; title"));
            Assert.That(html, Does.Not.Contain("A <b> title"));
        });
    }

    [Test]
    public void Timestamp_writes_minutes_and_hours()
    {
        Assert.Multiple(() =>
        {
            Assert.That(Lectures.Timestamp(0), Is.EqualTo("0:00"));
            Assert.That(Lectures.Timestamp(59), Is.EqualTo("0:59"));
            Assert.That(Lectures.Timestamp(78), Is.EqualTo("1:18"));
            Assert.That(Lectures.Timestamp(3600), Is.EqualTo("1:00:00"));
            Assert.That(Lectures.Timestamp(4081), Is.EqualTo("1:08:01"));
        });
    }

    [Test]
    public async Task Chapters_are_listed_with_their_times_and_link_into_the_video()
    {
        var file = Write(
            Line("aaaaaaaaaa1", "Two chapters", date: "2026-03-01T00:00:00Z", chapters: """[{"start_sec":3,"title":"Start"},{"start_sec":444,"title":"Middle"}]"""),
            Line("bbbbbbbbbb2", "One chapter", date: "2026-02-01T00:00:00Z", chapters: """[{"start_sec":9,"title":"Only"}]"""),
            Line("cccccccccc3", "No chapter", date: "2026-01-01T00:00:00Z"));

        var html = await RenderAsync(file);
        var cards = Regex.Split(html, "<div[^>]*data-lecture data-language").Skip(1).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(cards, Has.Count.EqualTo(3));
            Assert.That(cards[0], Does.Contain("<summary").And.Contain("2 chapters"));
            Assert.That(cards[0], Does.Contain("https://www.youtube.com/watch?v=aaaaaaaaaa1&amp;t=3s"));
            Assert.That(cards[0], Does.Contain("https://www.youtube.com/watch?v=aaaaaaaaaa1&amp;t=444s"));
            Assert.That(cards[0], Does.Contain("0:03").And.Contain("7:24"));
            Assert.That(cards[1], Does.Contain("1 chapter<").And.Not.Contain("1 chapters"));
            Assert.That(cards[2], Does.Not.Contain("<details"));
        });
    }

    [Test]
    public async Task Only_the_first_24_cards_are_shown_without_script()
    {
        var lines = Enumerable.Range(1, 30)
            .Select(i => Line(string.Create(CultureInfo.InvariantCulture, $"lecture{i:D4}"), $"Lecture {i}", date: new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc).AddDays(-i).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture)))
            .ToArray();
        var file = Write(lines);

        var html = await RenderAsync(file);
        var cards = Card().Matches(html);

        Assert.Multiple(() =>
        {
            Assert.That(cards, Has.Count.EqualTo(30));
            Assert.That(cards.Take(24).Select(c => c.Groups["rest"].Value), Has.None.Match(HiddenAttribute));
            Assert.That(cards.Skip(24).Select(c => c.Groups["rest"].Value), Has.All.Match(HiddenAttribute));
            Assert.That(html, Does.Contain("Showing 24 of 30 lectures"));
            Assert.That(html, Does.Match(@"<div[^>]*data-lecture-filter[^>]*\shidden"));
            Assert.That(html, Does.Match(@"<div[^>]*data-lecture-more[^>]*\shidden"));
            Assert.That(html, Does.Contain("data-page-size=\"24\""));
        });
    }

    [Test]
    public async Task Urdu_and_Hindi_lectures_carry_the_same_group()
    {
        var file = Write(
            Line("aaaaaaaaaa1", language: "\"hi\"", date: "2026-05-01T00:00:00Z"),
            Line("aaaaaaaaaa2", language: "\"ur\"", date: "2026-04-01T00:00:00Z"),
            Line("aaaaaaaaaa3", language: "\"en\"", date: "2026-03-01T00:00:00Z"),
            Line("aaaaaaaaaa4", language: "\"ar\"", date: "2026-02-01T00:00:00Z"),
            Line("aaaaaaaaaa5", language: "\"fa\"", date: "2026-01-01T00:00:00Z"));

        var html = await RenderAsync(file);

        Assert.Multiple(() =>
        {
            Assert.That(Card().Matches(html).Select(c => c.Groups["language"].Value), Is.EqualTo(Groups));
            Assert.That(Regex.Matches(html, @"data-lecture-language=""(?<value>[^""]*)""").Select(m => m.Groups["value"].Value), Is.EqualTo(Buttons));
            Assert.That(Lectures.LanguageGroup("hi"), Is.EqualTo("ur-hi"));
            Assert.That(Lectures.LanguageGroup(""), Is.EqualTo(""));
        });
    }

    private static readonly (string Name, string[] Lines, string Expected)[] Faults =
    [
        ("not json", [Line(), "this is not json"], "line 2"),
        ("blank title", [Line(title: "  ")], "title"),
        ("short slug", [Line(slug: "abcdefghij")], "slug"),
        ("bad date", [Line(date: "2026-13-45T00:00:00Z")], "publishedDate"),
        ("date without the Z", [Line(date: "2026-01-02T03:04:05")], "publishedDate"),
        ("negative duration", [Line(duration: "-1")], "durationSec"),
        ("blank chapter title", [Line(chapters: """[{"start_sec":1,"title":" "}]""")], "title"),
        ("negative chapter start", [Line(chapters: """[{"start_sec":-1,"title":"X"}]""")], "start_sec"),
        ("null language", [Line(language: "null")], "language"),
        ("a tag that is not a string", [Line(tags: "[1]")], "tags"),
        ("the same slug twice", [Line(), Line()], "abcdefghijk"),
    ];

    [TestCaseSource(nameof(Faults))]
    public void A_bad_lecture_file_stops_the_build_naming_the_fault((string Name, string[] Lines, string Expected) fault)
    {
        var file = Write(fault.Lines);

        var error = Assert.Throws<SiteBuildException>(() => Lectures.Read(file), fault.Name);

        Assert.That(error!.Message, Does.Contain(fault.Expected).And.EndWith("; the site is not built."), fault.Name);
    }

    [Test]
    public void A_missing_or_empty_lecture_file_stops_the_build()
    {
        var missing = Path.Combine(folder.FullName, "no-such-file.ndjson");
        var empty = Path.Combine(folder.FullName, "empty.ndjson");
        File.WriteAllText(empty, "\n\n");

        Assert.Multiple(() =>
        {
            Assert.That(Assert.Throws<SiteBuildException>(() => Lectures.Read(missing))!.Message, Does.Contain("no-such-file.ndjson").And.EndWith("; the site is not built."));
            Assert.That(Assert.Throws<SiteBuildException>(() => Lectures.Read(empty))!.Message, Does.Contain("no lecture").And.EndWith("; the site is not built."));
        });
    }

    [Test]
    public void A_missing_lecture_file_fails_when_the_pages_are_collected()
    {
        var error = Assert.Throws<SiteBuildException>(() => Lectures.Page(Path.Combine(folder.FullName, "no-such-file.ndjson")));

        Assert.That(error!.Message, Does.EndWith("; the site is not built."));
    }
}
