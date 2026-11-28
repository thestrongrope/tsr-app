using System.Globalization;
using NUnit.Framework;

namespace Tsr.Content.Api.Tests;

/// <summary>The guard over the published content folder (LIB-R27, LIB-R28, LIB-R31), on folders a test writes. Invented text only.</summary>
public sealed class ContentGuardTests
{
    private DirectoryInfo root = null!;

    [SetUp]
    public void Start() => root = Directory.CreateTempSubdirectory("tsr-guard-");

    [TearDown]
    public void Stop() => root.Delete(recursive: true);

    private string Path(string relative) => System.IO.Path.Combine(root.FullName, relative);

    private void Write(string relative, string text)
    {
        var path = Path(relative);
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(path)!);
        File.WriteAllText(path, text);
    }

    private void Article(string slug, string status = "publish", string category = "study-habits") =>
        Write($"articles/{slug}.md", string.Create(CultureInfo.InvariantCulture, $"""
            ---
            title: Title of {slug}
            slug: {slug}
            publishedDate: '2024-01-01T08:00:00.000Z'
            {(status.Length == 0 ? "" : "status: " + status)}
            categories:
              - {category}
            ---
            A short invented paragraph about planning a week of study.
            """));

    private static string LectureLine(string slug, string extra = "") =>
        "{\"slug\":\"" + slug + "\",\"title\":\"A title\",\"excerpt\":\"\",\"tags\":[],\"language\":\"en\",\"publishedDate\":\"2026-01-02T03:04:05Z\",\"durationSec\":78,\"chapters\":[{\"start_sec\":3,\"title\":\"C\"" + extra + "}]}";

    private void GoodFolder()
    {
        Article("first-article");
        Article("second-article");
        Write("categories/study-habits.md", "---\ntitle: Study Habits\nslug: study-habits\n---\n");
        Write("pages/tsr-publications.md", "---\ntitle: Sample\npublications:\n- title: A Booklet\n  file: /downloads/a-booklet.pdf\n---\n");
        Write("README.md", "Invented folder for a test.\n");
        Write("downloads/a-booklet.pdf", "invented bytes");
        Write("lectures/lectures.ndjson", LectureLine("abcdefghijk") + "\n" + LectureLine("bcdefghijkl") + "\n");
    }

    [Test]
    public void A_good_folder_has_no_problem()
    {
        GoodFolder();

        Assert.That(ContentGuard.Problems(root.FullName), Is.Empty);
    }

    [Test]
    public void An_empty_folder_and_an_unexpected_file_are_problems()
    {
        const string NeedsContent = "the folder needs at least one article and one category";
        Assert.That(ContentGuard.Problems(root.FullName), Does.Contain(NeedsContent), "an empty folder");

        GoodFolder();
        File.Delete(Path("articles/first-article.md"));
        File.Delete(Path("articles/second-article.md"));
        Assert.That(ContentGuard.Problems(root.FullName), Does.Contain(NeedsContent), "a category and a page, no article");

        GoodFolder();
        foreach (var (path, named) in new[] { ("articles/x.markdown", "articles/x.markdown"), ("articles/sub/x.md", "articles/sub"), ("pages/other.txt", "pages/other.txt"), ("pages/sub/x.md", "pages/sub"), ("notes.txt", "notes.txt") })
        {
            Write(path, "---\ntitle: X\n---\n");
            var problems = ContentGuard.Problems(root.FullName);

            Assert.That(problems.Count(problem => problem.Contains(named, StringComparison.Ordinal)), Is.GreaterThanOrEqualTo(1), path);

            File.Delete(Path(path));
            if (path.Contains("sub/", StringComparison.Ordinal))
            {
                Directory.Delete(System.IO.Path.GetDirectoryName(Path(path))!);
            }

            Assert.That(ContentGuard.Problems(root.FullName), Is.Empty, "after removing " + path);
        }
    }

    [Test]
    public void A_link_is_a_problem_that_names_the_path()
    {
        if (OperatingSystem.IsWindows())
        {
            Assert.Ignore("A symbolic link needs a privilege on Windows.");
        }

        GoodFolder();
        File.CreateSymbolicLink(Path("articles/linked.md"), Path("articles/first-article.md"));

        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("articles/linked.md"));
    }

    [TestCase("draft")]
    [TestCase("Publish")]
    [TestCase("")]
    public void A_draft_is_a_problem_that_names_the_file(string status)
    {
        GoodFolder();
        Article("not-published", status);

        var problems = ContentGuard.Problems(root.FullName);

        Assert.That(problems, Has.Some.Contain("articles/not-published.md"));
        Assert.That(problems.Where(problem => problem.Contains("first-article", StringComparison.Ordinal) || problem.Contains("second-article", StringComparison.Ordinal)), Is.Empty);
    }

    [Test]
    public void A_category_without_a_file_is_a_problem_that_names_both()
    {
        GoodFolder();
        Article("third-article", category: "no-such-category");

        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("third-article -> no-such-category"));
    }

    [Test]
    public void A_folder_that_does_not_exist_is_a_problem_not_an_exception()
    {
        Assert.That(ContentGuard.Problems(Path("missing")), Has.Some.Contain("missing"));
    }

    [Test]
    public void A_linked_file_the_folder_does_not_hold_is_a_problem_that_names_the_link()
    {
        GoodFolder();
        File.Delete(Path("downloads/a-booklet.pdf"));

        var problems = ContentGuard.Problems(root.FullName);

        Assert.That(problems, Has.Exactly(1).Contain("/downloads/a-booklet.pdf"));
        Assert.That(problems, Has.Count.EqualTo(1));
    }

    [Test]
    public void A_link_that_differs_only_in_case_from_the_file_is_a_problem()
    {
        GoodFolder();
        Write("pages/tsr-publications.md", "---\ntitle: Sample\npublications:\n- title: A Booklet\n  file: /downloads/A-Booklet.pdf\n---\n");

        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("/downloads/A-Booklet.pdf"));
    }

    [Test]
    public void A_file_no_publication_links_is_a_problem_that_names_the_path()
    {
        GoodFolder();
        Write("downloads/extra.pdf", "invented bytes");

        var problems = ContentGuard.Problems(root.FullName);

        Assert.That(problems, Has.Exactly(1).Contain("downloads/extra.pdf"));
        Assert.That(problems, Has.Count.EqualTo(1));
    }

    [Test]
    public void Only_pdf_files_are_allowed_below_downloads()
    {
        GoodFolder();
        Write("downloads/notes.txt", "invented text");
        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("downloads/notes.txt"), "a text file");
        File.Delete(Path("downloads/notes.txt"));

        if (OperatingSystem.IsWindows())
        {
            return;
        }

        File.CreateSymbolicLink(Path("downloads/x.pdf"), Path("downloads/a-booklet.pdf"));
        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("downloads/x.pdf"), "a link");
    }

    [Test]
    public void A_file_below_a_subfolder_of_downloads_is_checked_too()
    {
        GoodFolder();
        Write("downloads/books/inner.pdf", "invented bytes");
        Write("downloads/books/inner.txt", "invented text");

        var problems = ContentGuard.Problems(root.FullName);

        Assert.That(problems, Has.Some.Contain("downloads/books/inner.pdf"), "not linked");
        Assert.That(problems, Has.Some.Contain("downloads/books/inner.txt"), "not a pdf");
    }

    [Test]
    public void A_file_link_outside_downloads_is_a_problem_that_names_the_link()
    {
        GoodFolder();
        Write("pages/tsr-publications.md", "---\ntitle: Sample\npublications:\n- title: A Booklet\n  file: https://example.invalid/a-booklet.pdf\n---\n");

        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("outside /downloads/").And.Contain("https://example.invalid/a-booklet.pdf"));
    }

    [Test]
    public void Any_md_file_may_be_a_page()
    {
        GoodFolder();
        Write("pages/privacy-policy.md", "---\ntitle: Privacy\n---\nInvented page.\n");

        Assert.That(ContentGuard.Problems(root.FullName), Is.Empty);
    }

    [Test]
    public void A_file_a_page_links_is_not_unlinked_and_a_dead_page_link_is_a_problem()
    {
        GoodFolder();
        Write("downloads/books/gift.pdf", "invented bytes");
        Write("pages/gift.md", "---\ntitle: Gift\n---\nRead [the book](/downloads/books/gift.pdf) and [another](/downloads/books/gone.pdf).\n");

        var problems = ContentGuard.Problems(root.FullName);

        Assert.That(problems, Has.Count.EqualTo(1));
        Assert.That(problems, Has.Exactly(1).Contain("/downloads/books/gone.pdf"));
    }

    [Test]
    public void A_folder_without_a_publication_is_a_problem()
    {
        GoodFolder();
        File.Delete(Path("pages/tsr-publications.md"));

        Assert.That(ContentGuard.Problems(root.FullName), Is.Not.Empty);
    }

    private const string FullLecture =
        "{\"slug\":\"abcdefghijk\",\"title\":\"T\",\"url\":\"https://example.invalid/v\",\"excerpt\":\"E\",\"content\":\"words\",\"search_phrases\":[\"p\"],\"key_points\":[\"k\"],\"tags\":[],\"language\":\"en\",\"publishedDate\":\"2026-01-02T03:04:05Z\",\"durationSec\":78,"
        + "\"chapters\":[{\"start_sec\":3,\"title\":\"C\",\"summary\":\"S\",\"url\":\"https://example.invalid/c\"}],\"embedding\":[0.1,1.5E-05]}";

    [Test]
    public void A_lecture_with_the_thirteen_keys_of_the_full_file_is_not_a_problem()
    {
        GoodFolder();
        Write("lectures/lectures.ndjson", FullLecture + "\n" + LectureLine("bcdefghijkl") + "\n");

        Assert.That(ContentGuard.Problems(root.FullName), Is.Empty);
    }

    [Test]
    public void A_lecture_with_a_key_outside_the_thirteen_is_a_problem_that_names_it()
    {
        GoodFolder();
        var good = LectureLine("abcdefghijk");
        var extraKey = good.Replace("\"title\"", "\"secret\":\"words\",\"title\"", StringComparison.Ordinal);
        var chapterKey = LectureLine("cdefghijklm", ",\"note\":\"S\"");

        Write("lectures/lectures.ndjson", good + "\n" + extraKey + "\n");
        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("line 2").And.Contain("abcdefghijk").And.Contain("secret").And.Contain("thirteen"));

        Write("lectures/lectures.ndjson", good + "\n" + chapterKey + "\n");
        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("line 2").And.Contain("cdefghijklm").And.Contain("note"));

        Write("lectures/lectures.ndjson", good + "\nnot json\n");
        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("line 2").And.Contain("not a JSON object"));

        File.Delete(Path("lectures/lectures.ndjson"));
        Assert.That(ContentGuard.Problems(root.FullName), Does.Contain("the folder needs lectures/lectures.ndjson"));

        Write("lectures/lectures.ndjson", good + "\n");
        Write("lectures/other.ndjson", good + "\n");
        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("lectures/other.ndjson"));
    }

    [TestCase("title", "\"title\":\"T\"", "\"title\":\"Call +00 0000 000000 now\"")]
    [TestCase("excerpt", "\"excerpt\":\"E\"", "\"excerpt\":\"Number +00 0000 0000\"")]
    [TestCase("content", "\"content\":\"words\"", "\"content\":\"at 00000 000000 or 000.000.0000\"")]
    [TestCase("search_phrases", "\"search_phrases\":[\"p\"]", "\"search_phrases\":[\"p\",\"(000)000-0000\"]")]
    [TestCase("key_points", "\"key_points\":[\"k\"]", "\"key_points\":[\"0000000000\"]")]
    [TestCase("tags", "\"tags\":[]", "\"tags\":[\"+0000000000000\"]")]
    [TestCase("chapters", "\"title\":\"C\",\"summary\":\"S\"", "\"title\":\"C\",\"summary\":\"+00 000 000000\"")]
    [TestCase("title", "\"title\":\"T\"", "\"title\":\"WhatsApp number is 0000\"")]
    [TestCase("excerpt", "\"excerpt\":\"E\"", "\"excerpt\":\"Contact no. 00 00\"")]
    [TestCase("content", "\"content\":\"words\"", "\"content\":\"The phone number, in words: +00 000. Again, 0000\"")]
    [TestCase("key_points", "\"key_points\":[\"k\"]", "\"key_points\":[\"MOBILE NUMBER 00000\"]")]
    [TestCase("chapters", "\"title\":\"C\",\"summary\":\"S\"", "\"title\":\"C\",\"summary\":\"WhatsApp number, 0000\"")]
    [TestCase("content", "\"content\":\"words\"", "\"content\":\"WhatsApp number 1111, 2222, 3333, 4444, 5555, 6666\"")]
    public void A_phone_like_run_in_a_text_key_is_a_problem_that_names_the_line_the_lecture_and_the_key(string key, string from, string to)
    {
        GoodFolder();
        Write("lectures/lectures.ndjson", FullLecture + "\n" + FullLecture.Replace("abcdefghijk", "bcdefghijkl", StringComparison.Ordinal).Replace(from, to, StringComparison.Ordinal) + "\n");

        var problems = ContentGuard.Problems(root.FullName);

        Assert.That(problems, Has.Some.Contain("line 2").And.Contain("bcdefghijkl").And.Contain(key).And.Contain("phone"));
        Assert.That(problems, Has.None.Contain("000"), "a problem must not repeat the number");
    }

    [Test]
    public void A_masked_run_and_figures_that_are_not_phone_like_are_not_a_problem()
    {
        GoodFolder();
        var line = FullLecture.Replace("\"content\":\"words\"", "\"content\":\"In 2026-11-28, 1445 and 123456789, 1,234,567,890 or 12345678901234. Call [number removed].\"", StringComparison.Ordinal);
        Write("lectures/lectures.ndjson", line + "\n");

        Assert.That(ContentGuard.Problems(root.FullName), Is.Empty);
    }

    [Test]
    public void Short_figures_and_figures_far_from_the_words_are_not_a_problem_after_a_number_word()
    {
        GoodFolder();
        var far = new string('x', 81);
        var gap = new string('y', 100);
        var text = $"WhatsApp number 000 and a 5-minute call {gap} WhatsApp 0000 has no word number {gap} contact number {far} 0000 {gap} phone numbers 0000 {gap} [number removed]";
        var line = FullLecture.Replace("\"content\":\"words\"", $"\"content\":\"{text}\"", StringComparison.Ordinal);
        Write("lectures/lectures.ndjson", line + "\n");

        Assert.That(ContentGuard.Problems(root.FullName), Is.Empty);
    }

    [Test]
    public void A_figure_after_a_masked_run_is_a_problem_when_it_begins_within_80_characters_of_the_mask()
    {
        GoodFolder();
        var near = new string('x', 60);
        var chained = $"WhatsApp number [number removed], {near} [number removed], {near} 1111";
        Write("lectures/lectures.ndjson", FullLecture.Replace("\"content\":\"words\"", $"\"content\":\"{chained}\"", StringComparison.Ordinal) + "\n");

        Assert.That(ContentGuard.Problems(root.FullName), Has.Some.Contain("content").And.Contain("phone"));
    }

    [Test]
    public void A_figure_more_than_80_characters_after_the_last_mask_is_not_a_problem()
    {
        GoodFolder();
        var far = new string('x', 81);
        var text = $"WhatsApp number [number removed], {far} 1111";
        Write("lectures/lectures.ndjson", FullLecture.Replace("\"content\":\"words\"", $"\"content\":\"{text}\"", StringComparison.Ordinal) + "\n");

        Assert.That(ContentGuard.Problems(root.FullName), Is.Empty);
    }

    [Test]
    public void The_embedding_is_not_read_for_phone_like_runs()
    {
        GoodFolder();
        var line = FullLecture.Replace("[0.1,1.5E-05]", "[0.1234567890123,-0.0123456789012,1.2345678901234E-05]", StringComparison.Ordinal);
        Write("lectures/lectures.ndjson", line + "\n");

        Assert.That(ContentGuard.Problems(root.FullName), Is.Empty);
    }
}
