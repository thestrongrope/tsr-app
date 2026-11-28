using System.Text.Json;
using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// The guard over <c>db/synthetic/lectures/lectures.ndjson</c>, the invented lectures the test stacks index (plan task 9): every line has the keys of tsr-web's lecture file, in its order and with its types, and every line but one has a
/// 384-number vector. The one without a vector is on purpose (TC-SRCH-R10-03: indexed without error, found by keywords only). The vectors are made by <c>tools/embed-lecture-fixture.sh</c> and committed.
/// </summary>
[TestFixture]
internal sealed partial class LectureFixtureTests
{
    private static readonly string[] Keys =
        ["slug", "title", "url", "excerpt", "content", "search_phrases", "key_points", "tags", "language", "publishedDate", "durationSec", "chapters"];

    private static readonly string[] ChapterKeys = ["start_sec", "title", "summary", "url"];

    [GeneratedRegex(@"^\d{4}-\d{2}-\d{2}T00:00:00Z$")]
    private static partial Regex PublishedDate();

    private static List<JsonElement> Lectures()
    {
        var root = AppContext.BaseDirectory;
        while (!File.Exists(Path.Combine(root, "TsrApp.slnx")))
        {
            root = Path.GetDirectoryName(root) ?? throw new InvalidOperationException("TsrApp.slnx not found above " + AppContext.BaseDirectory);
        }

        var path = Path.Combine(root, "db", "synthetic", "lectures", "lectures.ndjson");
        Assert.That(new FileInfo(path).Length, Is.LessThan(1_000_000), "an invented fixture stays small");
        return [.. File.ReadAllLines(path).Where(line => line.Length > 0).Select(line => JsonElement.Parse(line))];
    }

    [Test]
    public void The_fixture_holds_twelve_lectures_with_distinct_slugs_in_hi_en_and_ar()
    {
        var lectures = Lectures();

        Assert.That(lectures, Has.Count.EqualTo(12));
        Assert.That(lectures.Select(l => l.GetProperty("slug").GetString()), Is.Unique);
        Assert.That(lectures.Select(l => l.GetProperty("language").GetString()).Distinct(), Is.EquivalentTo((string[])["hi", "en", "ar"]));
    }

    [Test]
    public void Every_line_has_the_keys_of_the_websites_lecture_file_in_its_order_and_with_its_types()
    {
        foreach (var lecture in Lectures())
        {
            var slug = lecture.GetProperty("slug").GetString()!;
            var names = lecture.EnumerateObject().Select(p => p.Name).ToArray();
            Assert.That(names.Take(Keys.Length), Is.EqualTo(Keys), slug);
            Assert.That(names.Length, Is.EqualTo(Keys.Length).Or.EqualTo(Keys.Length + 1), slug);
            Assert.That(slug, Has.Length.EqualTo(11), slug);
            Assert.That(lecture.GetProperty("url").GetString(), Is.EqualTo("https://www.youtube.com/watch?v=" + slug), slug);
            Assert.That(lecture.GetProperty("publishedDate").GetString(), Does.Match(PublishedDate().ToString()), slug);
            Assert.That(lecture.GetProperty("durationSec").ValueKind, Is.EqualTo(JsonValueKind.Number), slug);
            foreach (var list in (string[])["search_phrases", "key_points", "tags"])
            {
                Assert.That(lecture.GetProperty(list).EnumerateArray().Select(i => i.ValueKind).Distinct(), Is.EqualTo((JsonValueKind[])[JsonValueKind.String]), slug + " " + list);
            }

            var chapters = lecture.GetProperty("chapters").EnumerateArray().ToList();
            Assert.That(chapters, Is.Not.Empty, slug);
            foreach (var chapter in chapters)
            {
                Assert.That(chapter.EnumerateObject().Select(p => p.Name), Is.EqualTo(ChapterKeys), slug);
                Assert.That(chapter.GetProperty("url").GetString(), Does.StartWith(lecture.GetProperty("url").GetString() + "&t="), slug);
            }
        }
    }

    [Test]
    public void Exactly_one_lecture_has_no_vector_and_every_other_has_a_unit_vector_of_384_numbers()
    {
        var lectures = Lectures();

        var without = lectures.Where(l => !l.TryGetProperty("embedding", out _)).ToList();
        Assert.That(without, Has.Count.EqualTo(1), "one lecture without a vector, on purpose");
        foreach (var lecture in lectures.Except(without))
        {
            var vector = lecture.GetProperty("embedding").EnumerateArray().Select(n => n.GetDouble()).ToArray();
            Assert.That(vector, Has.Length.EqualTo(384), lecture.GetProperty("slug").GetString());
            Assert.That(Math.Sqrt(vector.Sum(x => x * x)), Is.EqualTo(1.0).Within(1e-3), "the model's vectors are normalised");
        }
    }
}
