using System.Diagnostics;
using System.Globalization;
using NUnit.Framework;
using Tsr.Content.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The reader of the content files and the article text helpers, on directories a test writes. No database is read here; the tests sit beside the database tests because content has no unit test project.
/// The rule for how a file is read is tsr-web's <c>web/src/lib/markdown.ts</c>.
/// </summary>
public sealed class ContentFilesTests
{
    private const string Head = "title: T\nslug: s\npublishedDate: '2024-01-01T00:00:00.000Z'\nstatus: publish\n";

    private ContentTestFiles files = null!;

    [SetUp]
    public void Start() => files = new ContentTestFiles();

    [TearDown]
    public void Stop() => files.Dispose();

    private void Raw(string fileName, string frontMatter, string body = "Body\n") => files.Write("articles", fileName, "---\n" + frontMatter + "---\n" + body);

    private static Result<ContentSet> Read(string? directory) => ContentFiles.Read(directory, TimeProvider.System, CancellationToken.None);

    private string? Failure() => Read(files.Root).Error;

    /// <summary>A clock whose stopwatch jumps by <paramref name="step"/> every time it is read.</summary>
    private sealed class JumpingClock(TimeSpan step) : TimeProvider
    {
        private long reads;

        public override long TimestampFrequency => TimeSpan.TicksPerSecond;

        public override long GetTimestamp() => step.Ticks * reads++;
    }

    private sealed class BrokenClock : TimeProvider
    {
        public override long GetTimestamp() => throw new InvalidOperationException("SECRET DETAIL");
    }

    /// <summary>The front matter of one published article with one field set (or replaced).</summary>
    private static string HeadWith(string slug, string field, string value)
    {
        var fields = new Dictionary<string, string> { ["title"] = "T", ["slug"] = slug, ["publishedDate"] = "'2024-01-01T00:00:00.000Z'", ["status"] = "publish" };
        fields[field] = value;
        return string.Concat(fields.Select(f => f.Key + ": " + f.Value + "\n"));
    }

    private ContentSet ReadSet()
    {
        var read = Read(files.Root);
        Assert.That(read.Error, Is.Null);
        return read.Value!;
    }

    [TestCase(null)]
    [TestCase("")]
    [TestCase("   ")]
    public void No_directory_named_is_a_failure(string? directory) =>
        Assert.That(Read(directory).Error, Is.EqualTo("no content directory"));

    [Test]
    public void A_directory_that_does_not_exist_is_a_failure() =>
        Assert.That(Read(Path.Combine(files.Root, "missing")).Error, Is.EqualTo("no content directory"));

    [Test]
    public void An_empty_directory_is_an_empty_set()
    {
        var set = ReadSet();

        Assert.That(set.Articles, Is.Empty);
        Assert.That(set.Categories, Is.Empty);
        Assert.That(set.Publications, Is.Empty);
    }

    [TestCase("publish", 1)]
    [TestCase("published", 1)]
    [TestCase("draft", 0)]
    [TestCase("Publish", 0)]
    [TestCase("", 0)]
    public void Only_publish_and_published_are_kept(string status, int kept)
    {
        Raw("a.md", "title: T\nslug: s\npublishedDate: '2024-01-01T00:00:00.000Z'\nstatus: '" + status + "'\n");

        Assert.That(ReadSet().Articles, Has.Count.EqualTo(kept));
    }

    [Test]
    public void A_file_without_front_matter_or_without_a_status_is_not_an_article()
    {
        files.Write("articles", "plain.md", "Just text\n");
        Raw("no-status.md", "title: T\nslug: s\n");
        files.Write("articles", "notes.txt", "---\n: : :\n---\n");

        Assert.That(ReadSet().Articles, Is.Empty);
    }

    [Test]
    public void The_slug_is_the_front_matter_slug_and_the_decoded_slug_is_percent_decoded()
    {
        Raw("2025-10-20-file-name.md", Head.Replace("slug: s", "slug: '%d9%85%d8%b7-notes%2Da'", StringComparison.Ordinal));

        var article = ReadSet().Articles.Single();

        Assert.That(article.Slug, Is.EqualTo("%d9%85%d8%b7-notes%2Da"));
        Assert.That(article.SlugDecoded, Is.EqualTo("مط-notes-a"));
    }

    [TestCase("'2024-05-10T08:15:00.000Z'", "2024-05-10T08:15:00.000Z", "2024-05-10T08:15:00.0000000+00:00")]
    [TestCase("'2023-06-07T05:10:00.482913'", "2023-06-07T05:10:00.482913", "2023-06-07T05:10:00.4829130+00:00")]
    [TestCase("\"2022-07-25T11:11:11\"", "2022-07-25T11:11:11", "2022-07-25T11:11:11.0000000+00:00")]
    [TestCase("'2024-05-10T08:15:00+05:30'", "2024-05-10T08:15:00+05:30", "2024-05-10T02:45:00.0000000+00:00")]
    public void The_three_date_shapes_are_read_and_one_without_a_zone_is_utc(string written, string text, string instant)
    {
        Raw("a.md", "title: T\nslug: s\npublishedDate: " + written + "\nmodifiedDate: " + written + "\nstatus: publish\n");

        var article = ReadSet().Articles.Single();

        Assert.That(article.PublishedDateText, Is.EqualTo(text));
        Assert.That(article.ModifiedDateText, Is.EqualTo(text));
        Assert.That(article.PublishedAt.ToString("o", CultureInfo.InvariantCulture), Is.EqualTo(instant));
        Assert.That(article.ModifiedAt?.ToString("o", CultureInfo.InvariantCulture), Is.EqualTo(instant));
    }

    [Test]
    public void Optional_fields_take_the_defaults_the_website_gives_them()
    {
        Raw("a.md", Head, "  \nBody after a blank line\n");

        var article = ReadSet().Articles.Single();

        Assert.That(article.LegacyId, Is.Null);
        Assert.That(article.Excerpt, Is.Null);
        Assert.That(article.ModifiedAt, Is.Null);
        Assert.That(article.ModifiedDateText, Is.Null);
        Assert.That(article.Author, Is.EqualTo("admin"));
        Assert.That(article.Language, Is.EqualTo("en"));
        Assert.That(article.Categories, Is.Empty);
        Assert.That(article.Tags, Is.Empty);
        Assert.That(article.BodyMarkdown, Is.EqualTo("  \nBody after a blank line\n"));
        Assert.That(article.BodyHtml, Is.EqualTo("<p>Body after a blank line</p>\n"));
        Assert.That(article.ReadingMinutes, Is.EqualTo(1));
    }

    [Test]
    public void Written_fields_are_read_by_name_whatever_their_quoting()
    {
        Raw("a.md", "\"title\": 2024\n'slug': s\npublishedDate: '2024-01-01T00:00:00.000Z'\nstatus: publish\nid: 7\nauthor: Editor\nlanguage: ur\nexcerpt: ~\ntags: [One, 'Two words']\ncategories:\n- c1\n- c2\n");

        var article = ReadSet().Articles.Single();

        Assert.That(article.Title, Is.EqualTo("2024"));
        Assert.That(article.LegacyId, Is.EqualTo(7));
        Assert.That(article.Author, Is.EqualTo("Editor"));
        Assert.That(article.Language, Is.EqualTo("ur"));
        Assert.That(article.Excerpt, Is.Null);
        Assert.That(article.Tags, Is.EqualTo((string[])["One", "Two words"]));
        Assert.That(article.Categories, Is.EqualTo((string[])["c1", "c2"]));
    }

    [TestCase("title: [never closed\nstatus: publish\n", "cannot parse file: bad.md")]
    [TestCase("title: T\ntitle: again\nstatus: publish\n", "cannot parse file: bad.md")]
    [TestCase("- a\n- list\n", "cannot parse file: bad.md")]
    [TestCase("title: T\npublishedDate: '2024-01-01T00:00:00.000Z'\nstatus: publish\n", "missing slug: bad.md")]
    [TestCase("slug: s\npublishedDate: '2024-01-01T00:00:00.000Z'\nstatus: publish\n", "missing title: bad.md")]
    [TestCase("title: T\nslug: s\nstatus: publish\n", "missing publishedDate: bad.md")]
    [TestCase("title: T\nslug: s\npublishedDate: last Tuesday\nstatus: publish\n", "bad date in publishedDate: bad.md")]
    [TestCase(Head + "modifiedDate: 10/05/2024\n", "bad date in modifiedDate: bad.md")]
    [TestCase(Head + "id: seven\n", "bad number in id: bad.md")]
    [TestCase(Head + "tags: one tag\n", "bad list in tags: bad.md")]
    [TestCase(Head + "categories:\n  - [nested]\n", "bad list in categories: bad.md")]
    [TestCase(Head + "excerpt:\n  a: map\n", "bad value in excerpt: bad.md")]
    [TestCase(Head + "language: a-language-code-far-too-long\n", "value too long in language: bad.md")]
    public void A_published_file_that_cannot_be_read_is_a_failure_naming_the_file_only(string frontMatter, string cause)
    {
        Raw("good.md", Head.Replace("slug: s", "slug: good", StringComparison.Ordinal));
        Raw("bad.md", frontMatter, "SECRET BODY\n");

        Assert.That(Read(files.Root).Error, Is.EqualTo(cause));
    }

    [Test]
    public void A_draft_that_cannot_be_parsed_is_still_a_failure()
    {
        Raw("bad.md", "title: [never closed\nstatus: draft\n");

        Assert.That(Read(files.Root).Error, Is.EqualTo("cannot parse file: bad.md"));
    }

    [TestCase("slug: same", "slug: same")]
    [TestCase("slug: 'a%2Db'", "slug: 'a-b'")]
    public void Two_published_articles_with_one_slug_or_one_decoded_slug_are_a_failure(string first, string second)
    {
        Raw("a.md", Head.Replace("slug: s", first, StringComparison.Ordinal));
        Raw("b.md", Head.Replace("slug: s", second, StringComparison.Ordinal));

        Assert.That(Read(files.Root).Error, Is.EqualTo("duplicate slug: b.md"));
    }

    [Test]
    public void A_draft_may_share_a_slug_with_a_published_article()
    {
        Raw("a.md", Head);
        Raw("b.md", Head.Replace("status: publish", "status: draft", StringComparison.Ordinal));

        Assert.That(ReadSet().Articles, Has.Count.EqualTo(1));
    }

    [Test]
    public void A_file_over_five_megabytes_is_a_failure_not_a_truncation()
    {
        Raw("big.md", Head, new string('x', (int)ContentFiles.MaxFileBytes));

        Assert.That(Read(files.Root).Error, Is.EqualTo("file too large: big.md"));
    }

    [Test]
    public void More_than_twenty_thousand_files_is_a_failure_not_a_truncation()
    {
        Raw("a.md", Head);
        Directory.CreateDirectory(Path.Combine(files.Root, "categories"));
        for (var n = 0; n < ContentFiles.MaxFiles; n++)
        {
            File.WriteAllBytes(Path.Combine(files.Root, "categories", string.Create(CultureInfo.InvariantCulture, $"c{n}.md")), []);
        }

        Assert.That(Read(files.Root).Error, Is.EqualTo("too many files"));
    }

    [Test]
    public void A_category_takes_its_slug_from_the_file_name_and_its_defaults_from_the_website()
    {
        files.Category("file-name", "title: \"Named\"\nslug: \"other-slug\"\ndescription: Words\norder: 4\nparent: \"top\"");
        files.Category("bare", "color: red");
        files.Category("zero", "title: Zero\norder: 0");
        files.Write("categories", "no-front-matter.md", string.Empty);

        var categories = ReadSet().Categories.ToDictionary(c => c.Slug);

        Assert.That(categories.Keys, Is.EquivalentTo((string[])["file-name", "bare", "zero", "no-front-matter"]));
        var named = categories["file-name"];
        Assert.That((named.Title, named.Description, named.SortOrder, named.ParentSlug), Is.EqualTo(("Named", "Words", 4, "top")));
        var bare = categories["bare"];
        Assert.That((bare.Title, bare.Description, bare.SortOrder, bare.ParentSlug), Is.EqualTo(("bare", (string?)null, 999, (string?)null)));
        Assert.That(categories["zero"].SortOrder, Is.EqualTo(999));
        Assert.That(categories["no-front-matter"].Title, Is.EqualTo("no-front-matter"));
    }

    [Test]
    public void A_category_with_an_order_that_is_not_a_number_is_a_failure()
    {
        files.Category("odd", "title: Odd\norder: first");

        Assert.That(Read(files.Root).Error, Is.EqualTo("bad number in order: odd.md"));
    }

    [Test]
    public void Publications_come_from_the_publications_page_in_file_order_without_the_unlinked_ones()
    {
        files.Write("pages", "tsr-publications.md", """
            ---
            title: Page
            publications:
            - title: "With a file"
              type: PDF
              size: 1 MB
              updated: "Jun 26, 2025"
              language: English
              file: /downloads/a.pdf
              summary: Words
              downloadOnly: true
            - title: No link
              summary: Dropped
            - just a string
            - readOnlineUrl: /read-me
              file: ''
              downloadOnly: "true"
            ---
            Page body
            """);
        files.Write("pages", "other.md", "---\npublications:\n- title: Elsewhere\n  file: /x.pdf\n---\n");

        var publications = ReadSet().Publications;

        Assert.That(publications, Has.Count.EqualTo(2));
        var first = publications[0];
        Assert.That(
            (first.Position, first.Title, first.Type, first.Size, first.Updated, first.Language, first.File, first.ReadOnlineUrl, first.Summary, first.DownloadOnly),
            Is.EqualTo((1, "With a file", "PDF", "1 MB", "Jun 26, 2025", "English", "/downloads/a.pdf", (string?)null, "Words", true)));
        var second = publications[1];
        Assert.That(
            (second.Position, second.Title, second.File, second.ReadOnlineUrl, second.DownloadOnly),
            Is.EqualTo((4, "Untitled publication", (string?)null, "/read-me", false)));
    }

    [TestCase("publications: none\n")]
    [TestCase("title: No list\n")]
    public void A_publications_page_without_a_list_gives_none(string frontMatter)
    {
        files.Write("pages", "tsr-publications.md", "---\n" + frontMatter + "---\n");

        Assert.That(ReadSet().Publications, Is.Empty);
    }

    [TestCase("", 1)]
    [TestCase("one", 1)]
    [TestCase(" one", 1)]
    public void Reading_minutes_are_never_under_one(string markdown, int minutes) =>
        Assert.That(ArticleHtml.ReadingMinutes(markdown), Is.EqualTo(minutes));

    [TestCase(200, "", 1)]
    [TestCase(201, "", 2)]
    [TestCase(200, "\n", 2)]
    [TestCase(400, "", 2)]
    [TestCase(401, "", 3)]
    public void Reading_minutes_are_the_pieces_between_white_space_over_200_rounded_up(int words, string ending, int minutes) =>
        Assert.That(ArticleHtml.ReadingMinutes(string.Join(" \n\t", Enumerable.Repeat("word", words)) + ending), Is.EqualTo(minutes));

    [Test]
    public void Markdown_becomes_plain_commonmark_html_without_the_github_extensions()
    {
        var html = ArticleHtml.ToHtml("## Heading\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n~~gone~~\n\n- [x] done\n\nSee https://example.invalid/page now.\n");

        Assert.That(html, Does.Contain("<h2>Heading</h2>"));
        Assert.That(html, Does.Contain("| 1 | 2 |").And.Contain("~~gone~~").And.Contain("<li>[x] done</li>"));
        Assert.That(html, Does.Not.Contain("<table").And.Not.Contain("<del").And.Not.Contain("checkbox").And.Not.Contain("<a "));
    }

    [Test]
    public void Raw_html_is_dropped_and_the_text_around_it_stays()
    {
        var html = ArticleHtml.ToHtml(
            "<div class=\"study-note\" onclick=\"run()\">\n<b>block</b>\n</div>\n\n"
            + "Text with <span onerror=\"run()\">inline</span> html <script>alert(1)</script> and <img src=x onerror=alert(2)>.\n\n"
            + "<script>\nalert(3)\n</script>\n\nAfter.\n");

        Assert.That(html, Is.EqualTo("<p>Text with inline html alert(1) and .</p>\n<p>After.</p>\n"));
    }

    [TestCase("[x](javascript:alert(1))")]
    [TestCase("[x](JaVaScript:alert(1))")]
    [TestCase("[x](<  javascript:alert(1)>)")]
    [TestCase("[x](<java\tscript:alert(1)>)")]
    [TestCase("[x](&#106;avascript:alert(1))")]
    [TestCase("[x](vbscript:run)")]
    [TestCase("[x](data:text/html;base64,AAAA)")]
    [TestCase("[x](file:///etc/hosts)")]
    [TestCase("[x][r]\n\n[r]: javascript:alert(1)")]
    [TestCase("![x](javascript:alert(1))")]
    [TestCase("![x](data:image/svg+xml;base64,AAAA)")]
    public void A_link_or_image_address_with_another_scheme_becomes_empty(string markdown)
    {
        var html = ArticleHtml.ToHtml(markdown);

        Assert.That(html, Does.Match("(href|src)=\"\""));
        Assert.That(html, Does.Not.Contain("script").IgnoreCase.And.Not.Contain("data:").And.Not.Contain("file:"));
    }

    [Test]
    public void A_bare_link_with_another_scheme_keeps_its_text_and_loses_its_address() =>
        Assert.That(ArticleHtml.ToHtml("<javascript:alert(1)>"), Is.EqualTo("<p><a href=\"\">javascript:alert(1)</a></p>\n"));

    [TestCase("[x](https://example.invalid/a?b=1#c)", "<a href=\"https://example.invalid/a?b=1#c\">x</a>")]
    [TestCase("[x](http://example.invalid)", "<a href=\"http://example.invalid\">x</a>")]
    [TestCase("[x](HTTPS://example.invalid)", "<a href=\"HTTPS://example.invalid\">x</a>")]
    [TestCase("[x](mailto:reader@example.invalid)", "<a href=\"mailto:reader@example.invalid\">x</a>")]
    [TestCase("[x](/library/a-page)", "<a href=\"/library/a-page\">x</a>")]
    [TestCase("[x](../other/page.html)", "<a href=\"../other/page.html\">x</a>")]
    [TestCase("[x](notes/10:30-class)", "<a href=\"notes/10:30-class\">x</a>")]
    [TestCase("[x](?page=2)", "<a href=\"?page=2\">x</a>")]
    [TestCase("[x](#part-two)", "<a href=\"#part-two\">x</a>")]
    [TestCase("![alt](/images/a.png)", "<img src=\"/images/a.png\" alt=\"alt\" />")]
    [TestCase("<https://example.invalid/x>", "<a href=\"https://example.invalid/x\">https://example.invalid/x</a>")]
    [TestCase("<reader@example.invalid>", "<a href=\"mailto:reader@example.invalid\">reader@example.invalid</a>")]
    public void An_ordinary_relative_fragment_or_mail_address_is_unchanged(string markdown, string html) =>
        Assert.That(ArticleHtml.ToHtml(markdown), Is.EqualTo("<p>" + html + "</p>\n"));

    [Test]
    public void Right_to_left_text_is_unchanged() =>
        Assert.That(ArticleHtml.ToHtml("## عنوان\n\nیہ ایک فرضی جملہ ہے۔\n"), Is.EqualTo("<h2>عنوان</h2>\n<p>یہ ایک فرضی جملہ ہے۔</p>\n"));

    [Test]
    public void Front_matter_seventeen_deep_is_a_failure()
    {
        Raw("bad.md", Head + "k: " + new string('[', 16) + new string(']', 16) + "\n");

        Assert.That(Failure(), Is.EqualTo("front matter too deep: bad.md"));
    }

    // 60,000 open brackets fit the 64 KB bound. The reader stops at the seventeenth level, so the brackets after it are never read.
    [TestCase("publish")]
    [TestCase("draft")]
    public void Front_matter_nested_past_sixteen_is_a_failure_and_never_a_crash(string status)
    {
        Raw("bad.md", "status: " + status + "\nk: " + new string('[', 60_000) + "\n");

        Assert.That(Failure(), Is.EqualTo("front matter too deep: bad.md"));
    }

    [Test]
    public void Front_matter_nested_by_indentation_past_sixteen_is_a_failure()
    {
        Raw("bad.md", string.Concat(Enumerable.Range(0, 300).Select(level => new string(' ', level) + "k:\n")));

        Assert.That(Failure(), Is.EqualTo("front matter too deep: bad.md"));
    }

    [Test]
    public void Front_matter_sixteen_deep_is_read()
    {
        Raw("a.md", Head + "k: " + new string('[', 15) + new string(']', 15) + "\n");

        Assert.That(ReadSet().Articles, Has.Count.EqualTo(1));
    }

    [TestCase(100_000)]
    [TestCase(70_000)]
    public void Front_matter_over_64_kilobytes_is_a_failure_before_it_is_parsed(int brackets)
    {
        Raw("bad.md", "status: draft\nk: " + new string('[', brackets) + "\n");

        Assert.That(Failure(), Is.EqualTo("front matter too large: bad.md"));
    }

    [Test]
    public void An_article_body_over_100000_characters_is_a_failure_not_a_truncation()
    {
        Raw("big.md", Head, string.Concat(Enumerable.Repeat("[a](", 25_000)) + "x");

        Assert.That(Failure(), Is.EqualTo("body too long: big.md"));
    }

    [Test]
    public void An_article_body_of_100000_characters_is_read()
    {
        Raw("a.md", Head, string.Concat(Enumerable.Repeat("word ", 20_000)));

        Assert.That(ReadSet().Articles.Single().BodyMarkdown, Has.Length.EqualTo(100_000));
    }

    [Test]
    public void A_body_the_renderer_refuses_is_a_failure_naming_the_exception_type_and_the_file_only()
    {
        Raw("a.md", Head.Replace("slug: s", "slug: good", StringComparison.Ordinal));
        Raw("deep.md", Head, new string('>', 50_000) + " SECRET BODY\n");

        Assert.That(Failure(), Is.EqualTo("content read failed: ArgumentException in deep.md"));
    }

    [Test]
    public void An_unexpected_exception_before_any_file_is_a_failure_naming_its_type_only()
    {
        Raw("a.md", Head);

        Assert.That(ContentFiles.Read(files.Root, new BrokenClock(), CancellationToken.None).Error, Is.EqualTo("content read failed: InvalidOperationException"));
    }

    [Test]
    public void A_read_longer_than_two_minutes_stops_between_files()
    {
        foreach (var name in (string[])["a", "b", "c"])
        {
            Raw(name + ".md", Head.Replace("slug: s", "slug: " + name, StringComparison.Ordinal));
        }

        Assert.That(ContentFiles.Read(files.Root, new JumpingClock(TimeSpan.FromSeconds(30)), CancellationToken.None).Error, Is.Null);
        Assert.That(ContentFiles.Read(files.Root, new JumpingClock(TimeSpan.FromSeconds(61)), CancellationToken.None).Error, Is.EqualTo("content read took too long"));
    }

    [Test]
    public void A_cancelled_read_stops_and_is_not_a_failure_cause()
    {
        Raw("a.md", Head);
        using var stopping = new CancellationTokenSource();
        stopping.Cancel();

        Assert.That(() => ContentFiles.Read(files.Root, TimeProvider.System, stopping.Token), Throws.InstanceOf<OperationCanceledException>());
    }

    [Test]
    public void More_than_200_megabytes_in_all_is_a_failure()
    {
        Raw("a.md", Head);
        Directory.CreateDirectory(Path.Combine(files.Root, "categories"));
        for (var n = 0; n < 41; n++)
        {
            // Sparse: a length without the bytes. The bound is checked before any file is read.
            using var file = File.Create(Path.Combine(files.Root, "categories", string.Create(CultureInfo.InvariantCulture, $"c{n}.md")));
            file.SetLength(ContentFiles.MaxFileBytes);
        }

        Assert.That(Failure(), Is.EqualTo("content too large"));
    }

    [TestCase("articles", "linked.md", "symbolic link refused: linked.md")]
    [TestCase("articles", "linked.txt", "symbolic link refused: linked.txt")]
    [TestCase("categories", "linked.md", "symbolic link refused: linked.md")]
    [TestCase("pages", "tsr-publications.md", "symbolic link refused: tsr-publications.md")]
    public void A_symbolic_link_to_a_file_is_refused_not_followed(string folder, string name, string cause)
    {
        Raw("a.md", Head);
        files.Write("elsewhere", "target.md", "---\n" + Head.Replace("slug: s", "slug: linked", StringComparison.Ordinal) + "publications:\n- title: Linked\n  file: /x.pdf\n---\nSECRET BODY\n");
        Directory.CreateDirectory(Path.Combine(files.Root, folder));
        File.CreateSymbolicLink(Path.Combine(files.Root, folder, name), Path.Combine(files.Root, "elsewhere", "target.md"));

        Assert.That(Failure(), Is.EqualTo(cause));
    }

    [TestCase("articles", "symbolic link refused: articles")]
    [TestCase("categories", "symbolic link refused: categories")]
    [TestCase("pages", "symbolic link refused: pages")]
    [TestCase("articles/inner", "symbolic link refused: inner")]
    public void A_symbolic_link_to_a_directory_is_refused_not_followed(string link, string cause)
    {
        files.Write("elsewhere", "target.md", "---\n" + Head + "---\nSECRET BODY\n");
        Directory.CreateDirectory(Path.GetDirectoryName(Path.Combine(files.Root, link))!);
        Directory.CreateSymbolicLink(Path.Combine(files.Root, link), Path.Combine(files.Root, "elsewhere"));

        Assert.That(Failure(), Is.EqualTo(cause));
    }

    [Test]
    public void A_symbolic_link_that_points_nowhere_is_refused_too()
    {
        Directory.CreateDirectory(Path.Combine(files.Root, "pages"));
        File.CreateSymbolicLink(Path.Combine(files.Root, "pages", "tsr-publications.md"), Path.Combine(files.Root, "missing.md"));

        Assert.That(Failure(), Is.EqualTo("symbolic link refused: tsr-publications.md"));
    }

    [TestCase("articles", "---\n" + Head + "---\nBody with a \0 in it\n", "NUL character in file: bad.md")]
    [TestCase("articles", "---\n" + Head + "excerpt: a \0 raw\n---\nBody\n", "NUL character in file: bad.md")]
    [TestCase("articles", "---\n" + Head + "excerpt: \"escaped \\0 here\"\n---\nBody\n", "bad character in excerpt: bad.md")]
    [TestCase("articles", "---\n" + Head + "author: \"escaped \\x00 here\"\n---\nBody\n", "bad character in author: bad.md")]
    [TestCase("articles", "---\n" + Head + "tags:\n  - \"escaped \\0 here\"\n---\nBody\n", "bad character in tags: bad.md")]
    [TestCase("categories", "---\ndescription: \"escaped \\0 here\"\n---\n", "bad character in description: bad.md")]
    public void A_nul_character_in_a_stored_text_is_a_failure_at_read_time(string folder, string text, string cause)
    {
        files.Write(folder, "bad.md", text);

        Assert.That(Failure(), Is.EqualTo(cause));
    }

    [Test]
    public void A_nul_character_in_a_publication_is_a_failure_at_read_time()
    {
        files.Write("pages", "tsr-publications.md", "---\npublications:\n- title: Booklet\n  summary: \"escaped \\0 here\"\n  file: /x.pdf\n---\n");

        Assert.That(Failure(), Is.EqualTo("bad character in summary: tsr-publications.md"));
    }

    [TestCase("title", 500)]
    [TestCase("author", 100)]
    [TestCase("language", 10)]
    public void An_article_value_longer_than_its_column_is_a_failure_at_read_time(string field, int longest)
    {
        Raw("a.md", HeadWith("fits", field, new string('x', longest)));
        Raw("bad.md", HeadWith("s", field, new string('x', longest + 1)));

        Assert.That(Failure(), Is.EqualTo("value too long in " + field + ": bad.md"));
    }

    [TestCase("publishedDate")]
    [TestCase("modifiedDate")]
    public void An_article_date_text_longer_than_its_column_is_a_failure_at_read_time(string field)
    {
        Raw("bad.md", HeadWith("s", field, "'2024-01-01T00:00:00." + new string('0', 30) + "Z'"));

        Assert.That(Failure(), Is.EqualTo("value too long in " + field + ": bad.md"));
    }

    [TestCase("title", 255)]
    [TestCase("parent", 255)]
    public void A_category_value_longer_than_its_column_is_a_failure_at_read_time(string field, int longest)
    {
        files.Category("a-fits", field + ": " + new string('x', longest));
        files.Category("bad", field + ": " + new string('x', longest + 1));

        Assert.That(Failure(), Is.EqualTo("value too long in " + field + ": bad.md"));
    }

    [TestCase("title", 500)]
    [TestCase("type", 50)]
    [TestCase("size", 50)]
    [TestCase("updated", 50)]
    [TestCase("language", 50)]
    [TestCase("file", 500)]
    [TestCase("readOnlineUrl", 500)]
    public void A_publication_value_longer_than_its_column_is_a_failure_at_read_time(string field, int longest)
    {
        // A leading slash, so the two link fields are site-relative.
        files.Write("pages", "tsr-publications.md", "---\npublications:\n- summary: Fits\n  " + field + ": /" + new string('x', longest - 1) + "\n---\n");
        Assert.That(Failure(), Is.Null);
        files.Write("pages", "tsr-publications.md", "---\npublications:\n- summary: Too long\n  " + field + ": /" + new string('x', longest) + "\n---\n");

        Assert.That(Failure(), Is.EqualTo("value too long in " + field + ": tsr-publications.md"));
    }

    // A key that contains itself. YamlDotNet 18.1.0's tree loader (YamlStream.Load) hashes the key and overflows the stack, which ends the process: the reader never builds that tree.
    [TestCase("publish")]
    [TestCase("draft")]
    public void A_key_that_contains_itself_is_a_failure_and_never_a_crash(string status)
    {
        Raw("bad.md", "status: " + status + "\n? &a [*a]\n: v\n");

        Assert.That(Failure(), Is.EqualTo("anchor in front matter: bad.md"));
    }

    // Ten times more nodes a level, used as a key: the tree loader takes 3.3 seconds at 8 levels and about 5 times more for each level after.
    [TestCase(8)]
    [TestCase(30)]
    public void Aliases_multiplied_into_a_key_are_a_failure_at_once(int levels)
    {
        var lines = Enumerable.Range(1, levels - 1).Select(level =>
            string.Create(CultureInfo.InvariantCulture, $"l{level}: &l{level} [{string.Join(", ", Enumerable.Repeat(string.Create(CultureInfo.InvariantCulture, $"*l{level - 1}"), 10))}]\n"));
        var last = string.Create(CultureInfo.InvariantCulture, $"? *l{levels - 1}\n: v\n");
        Raw("bad.md", "status: draft\nl0: &l0 [x, x, x, x, x, x, x, x, x, x]\n" + string.Concat(lines) + last);
        var timer = Stopwatch.StartNew();

        var failure = Failure();

        Assert.That(timer.Elapsed, Is.LessThan(TimeSpan.FromSeconds(2)));
        Assert.That(failure, Is.EqualTo("anchor in front matter: bad.md"));
    }

    [TestCase("k: &a v\n", "anchor in front matter: bad.md")]
    [TestCase("k: &a [v]\n", "anchor in front matter: bad.md")]
    [TestCase("k: &a {b: c}\n", "anchor in front matter: bad.md")]
    [TestCase("&a k: v\n", "anchor in front matter: bad.md")]
    [TestCase("k: *a\n", "alias in front matter: bad.md")]
    [TestCase("k:\n  <<: *a\n", "alias in front matter: bad.md")]
    [TestCase("base: &a {b: c}\nk:\n  <<: *a\n", "anchor in front matter: bad.md")]
    [TestCase("k: !!str x\n", "tag in front matter: bad.md")]
    [TestCase("k: !custom x\n", "tag in front matter: bad.md")]
    [TestCase("k: !custom [x]\n", "tag in front matter: bad.md")]
    [TestCase("k: !!map {b: c}\n", "tag in front matter: bad.md")]
    [TestCase("!!str k: v\n", "tag in front matter: bad.md")]
    [TestCase("? [a, b]\n: v\n", "key is not a text in front matter: bad.md")]
    [TestCase("? {a: b}\n: v\n", "key is not a text in front matter: bad.md")]
    [TestCase("k:\n  - ? [a]\n    : v\n", "key is not a text in front matter: bad.md")]
    [TestCase("k: {[a]: v}\n", "key is not a text in front matter: bad.md")]
    [TestCase("a: b\n...\nc: d\n", "second document in front matter: bad.md")]
    [TestCase("k:\n  a: 1\n  a: 2\n", "cannot parse file: bad.md")]
    [TestCase("just a text\n", "cannot parse file: bad.md")]
    public void Front_matter_of_a_kind_the_content_never_uses_is_a_failure(string frontMatter, string cause)
    {
        Raw("bad.md", "status: draft\n" + frontMatter);

        Assert.That(Failure(), Is.EqualTo(cause));
    }

    [Test]
    public void Plain_quoted_and_multi_line_texts_empty_values_and_lists_are_read()
    {
        Raw("a.md", """
            title: "Double: quoted \u0041"
            slug: 'single-quoted'
            publishedDate: 2024-01-01T00:00:00
            status: publish
            author: Plain words here
            language:
            excerpt: |
              Line one
              Line two
            tags:
              - >
                Folded
                tag
              - 'null'
              - ~
              -
            categories: []
            unused:
              nested: {map: [of, lists]}
            ? explicit
            : key

            """);

        var article = ReadSet().Articles.Single();

        Assert.That(article.Title, Is.EqualTo("Double: quoted A"));
        Assert.That(article.Slug, Is.EqualTo("single-quoted"));
        Assert.That(article.PublishedDateText, Is.EqualTo("2024-01-01T00:00:00"));
        Assert.That(article.Author, Is.EqualTo("Plain words here"));
        Assert.That(article.Language, Is.EqualTo("en"));
        Assert.That(article.Excerpt, Is.EqualTo("Line one\nLine two\n"));
        Assert.That(article.Tags, Is.EqualTo((string[])["Folded tag\n", "null", "~", string.Empty]));
        Assert.That(article.Categories, Is.Empty);
    }

    [TestCase("excerpt: 'null'\n", "null")]
    [TestCase("excerpt: \"~\"\n", "~")]
    [TestCase("excerpt: ''\n", "")]
    [TestCase("excerpt: null\n", null)]
    [TestCase("excerpt: ~\n", null)]
    [TestCase("excerpt:\n", null)]
    [TestCase("tags: ~\n", null)]
    public void Only_an_unquoted_null_is_no_value(string field, string? excerpt)
    {
        Raw("a.md", Head + field);

        var article = ReadSet().Articles.Single();

        Assert.That(article.Excerpt, Is.EqualTo(excerpt));
        Assert.That(article.Tags, Is.Empty);
    }

    [Test]
    public void A_slug_of_255_characters_is_read_and_a_longer_one_is_a_failure()
    {
        Raw("a.md", HeadWith(new string('a', 255), "author", "A"));
        Assert.That(Failure(), Is.Null);
        Raw("bad.md", HeadWith(new string('b', 256), "author", "A"));

        Assert.That(Failure(), Is.EqualTo("value too long in slug: bad.md"));
    }

    [Test]
    public void A_slug_is_measured_as_written_so_a_percent_encoded_one_over_255_is_a_failure()
    {
        Raw("bad.md", HeadWith("'" + string.Concat(Enumerable.Repeat("%d9%85", 43)) + "'", "author", "A"));

        Assert.That(Failure(), Is.EqualTo("value too long in slug: bad.md"));
    }

    [TestCase("tags")]
    [TestCase("categories")]
    public void A_tag_or_category_of_200_characters_is_read_and_a_longer_one_is_a_failure(string field)
    {
        Raw("a.md", HeadWith("fits", field, "[short, " + new string('x', 200) + "]"));
        Assert.That(Failure(), Is.Null);
        Raw("bad.md", HeadWith("s", field, "[short, " + new string('x', 201) + "]"));

        Assert.That(Failure(), Is.EqualTo("value too long in " + field + ": bad.md"));
    }

    [TestCase("tags")]
    [TestCase("categories")]
    public void Fifty_tags_or_categories_are_read_and_one_more_is_a_failure(string field)
    {
        Raw("a.md", HeadWith("fits", field, "[" + string.Join(", ", Enumerable.Range(0, 50).Select(n => "v" + n.ToString(CultureInfo.InvariantCulture))) + "]"));
        Assert.That(Failure(), Is.Null);
        Raw("bad.md", HeadWith("s", field, "[" + string.Join(", ", Enumerable.Range(0, 51).Select(n => "v" + n.ToString(CultureInfo.InvariantCulture))) + "]"));

        Assert.That(Failure(), Is.EqualTo("too many values in " + field + ": bad.md"));
    }

    [TestCase("a%00b")]
    [TestCase("%00")]
    [TestCase("notes-%d9%85%00")]
    public void A_slug_that_decodes_to_a_nul_character_is_a_failure_at_read_time(string slug)
    {
        Raw("bad.md", HeadWith("'" + slug + "'", "author", "A"));

        Assert.That(Failure(), Is.EqualTo("bad character in slug: bad.md"));
    }

    [TestCase("&#0;")]
    [TestCase("&#x0;")]
    [TestCase("[x](/a%00b)")]
    [TestCase("[x](/a&#0;b)")]
    public void A_nul_character_spelled_in_the_body_never_reaches_the_stored_html(string markdown)
    {
        Raw("a.md", Head, "Before " + markdown + " after.\n");

        // Not NUnit's Contain: its culture comparison ignores a NUL character.
        Assert.That(ReadSet().Articles.Single().BodyHtml.Contains('\0', StringComparison.Ordinal), Is.False);
    }

    [TestCase("file", "//host.invalid/a.pdf")]
    [TestCase("file", "/\\host.invalid/a.pdf")]
    [TestCase("file", "a.pdf")]
    [TestCase("file", "' /a.pdf'")]
    [TestCase("file", "ftp://host.invalid/a.pdf")]
    [TestCase("file", "'javascript:alert(1)'")]
    [TestCase("file", "'http:/host.invalid/a.pdf'")]
    [TestCase("file", "'data:text/html;base64,AAAA'")]
    [TestCase("readOnlineUrl", "//host.invalid/read")]
    [TestCase("readOnlineUrl", "read-me")]
    [TestCase("readOnlineUrl", "'javascript:alert(1)'")]
    [TestCase("readOnlineUrl", "'file:///etc/hosts'")]
    public void A_publication_link_that_is_neither_site_relative_nor_http_is_a_failure(string field, string link)
    {
        files.Write("pages", "tsr-publications.md", "---\npublications:\n- title: Booklet\n  " + field + ": " + link + "\n---\n");

        Assert.That(Failure(), Is.EqualTo("bad link in " + field + ": tsr-publications.md"));
    }

    [TestCase("/")]
    [TestCase("/downloads/a.pdf")]
    [TestCase("/downloads//a.pdf")]
    [TestCase("http://host.invalid/a.pdf")]
    [TestCase("https://host.invalid/a.pdf")]
    [TestCase("HTTPS://host.invalid/a.pdf")]
    [TestCase("Http://host.invalid/a.pdf")]
    public void A_site_relative_or_http_publication_link_is_stored_as_written(string link)
    {
        files.Write("pages", "tsr-publications.md", "---\npublications:\n- title: Booklet\n  file: '" + link + "'\n  readOnlineUrl: '" + link + "'\n---\n");

        var publication = ReadSet().Publications.Single();

        Assert.That((publication.File, publication.ReadOnlineUrl), Is.EqualTo((link, link)));
    }

    // YamlDotNet 18.1.0 lets ArgumentOutOfRangeException out for an escape past the last code point; whatever its parser throws is a file that cannot be parsed.
    [TestCase("slug: \"\\UFFFFFFFF\"\n")]
    [TestCase("slug: \"\\UDDDDDDDD\"\n")]
    public void A_scalar_the_yaml_parser_throws_on_is_a_failure_of_the_reader(string frontMatter)
    {
        Raw("bad.md", "status: draft\n" + frontMatter);

        Assert.That(Failure(), Is.EqualTo("cannot parse file: bad.md"));
    }

    // A browser drops a tab or a line break inside an address, so "/\t/host" opens "//host": another site.
    [TestCase("file", "\"/\\t/host.invalid/a.pdf\"")]
    [TestCase("file", "\"/\\r/host.invalid\"")]
    [TestCase("file", "\"/\\n/host.invalid\"")]
    [TestCase("file", "\"/downloads/a.pdf\\n\"")]
    [TestCase("file", "'/downloads/a file.pdf'")]
    [TestCase("file", "\"/downloads/\\u00A0a.pdf\"")]
    [TestCase("file", "\"/downloads/\\x7Fa.pdf\"")]
    [TestCase("file", "\"/downloads/\\x01a.pdf\"")]
    [TestCase("readOnlineUrl", "\"https://host.invalid/\\tread\"")]
    [TestCase("readOnlineUrl", "\"/\\u2028/host.invalid\"")]
    [TestCase("readOnlineUrl", "\"/\\u0085read\"")]
    public void A_publication_link_with_white_space_or_a_control_character_is_a_failure(string field, string link)
    {
        files.Write("pages", "tsr-publications.md", "---\npublications:\n- title: Booklet\n  " + field + ": " + link + "\n---\n");

        Assert.That(Failure(), Is.EqualTo("bad link in " + field + ": tsr-publications.md"));
    }

    [TestCase("'.'")]
    [TestCase("'..'")]
    [TestCase("'%2e%2e'")]
    [TestCase("'%20'")]
    [TestCase("a/b")]
    [TestCase("'../other'")]
    [TestCase("'a%2Fb'")]
    [TestCase("'a\\b'")]
    [TestCase("'a%5Cb'")]
    [TestCase("'a b'")]
    [TestCase("'a%20b'")]
    [TestCase("\"a\\tb\"")]
    [TestCase("'a%0Ab'")]
    [TestCase("\"a\\u00A0b\"")]
    [TestCase("\"a\\x7Fb\"")]
    [TestCase("'a%C2%85b'")]
    public void A_slug_that_is_dots_or_holds_a_slash_white_space_or_a_control_character_is_a_failure(string slug)
    {
        Raw("bad.md", HeadWith(slug, "author", "admin"));

        Assert.That(Failure(), Is.EqualTo("bad slug in slug: bad.md"));
    }

    [TestCase("a-plain-slug")]
    [TestCase("with.dots.and_underscores")]
    [TestCase("'...'")]
    [TestCase("'%d9%85%d8%b7%d8%a7%d9%84%d8%b9%db%81-%d9%86%d9%88%d9%b9%d8%b3'")]
    [TestCase("'ک‌تاب'")]
    public void An_ordinary_slug_in_any_script_is_read(string slug)
    {
        Raw("a.md", HeadWith(slug, "author", "admin"));

        Assert.That(ReadSet().Articles, Has.Count.EqualTo(1));
    }

    [TestCase("..")]
    [TestCase("a b")]
    [TestCase("a%20b")]
    [TestCase("a%2Fb")]
    [TestCase("a\\b")]
    [TestCase("a\tb")]
    public void A_category_file_name_that_is_no_slug_is_a_failure(string name)
    {
        files.Category(name, "title: T");

        Assert.That(Failure(), Is.EqualTo("bad slug in file name: " + name + ".md"));
    }
}
