using Microsoft.Extensions.Logging;
using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>The lecture data file of the feed (<c>TSR_LECTURES_FILE</c>): one JSON object a line, passed through as it is. A file that is not set, missing, too big or not whole is an empty source (the feed keeps the index and warns with counts only).</summary>
[TestFixture]
internal sealed class LectureFileTests
{
    private sealed class CaptureLog : ILogger
    {
        public List<(LogLevel Level, string Line)> Lines { get; } = [];

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Add((logLevel, formatter(state, exception)));
    }

    private string directory = null!;

    [SetUp]
    public void Make() => directory = Directory.CreateTempSubdirectory("lecturefile").FullName;

    [TearDown]
    public void Remove() => Directory.Delete(directory, recursive: true);

    private string Write(params string[] lines)
    {
        var path = Path.Combine(directory, "lectures.ndjson");
        File.WriteAllLines(path, lines);
        return path;
    }

    [Test]
    public async Task Each_line_is_a_document_with_its_slug_as_id_and_its_text_unchanged()
    {
        const string first = """{"slug":"a1","title":"A","embedding":[0.123456789012345678,1e-7,-0.5]}""";
        var path = Write(first, "", "  " + """{"slug":"b2","title":"B"}""" + "  ");

        var documents = await LectureFile.ReadAsync(path, new CaptureLog(), CancellationToken.None);

        Assert.That(documents.Select(d => d.Id), Is.EqualTo((string[])["a1", "b2"]));
        Assert.That(documents[0].Json, Is.EqualTo(first), "the vector is not parsed and printed again");
        Assert.That(documents[1].Json, Is.EqualTo("""{"slug":"b2","title":"B"}"""));
    }

    [TestCase(null)]
    [TestCase("")]
    public async Task A_file_that_is_not_set_is_an_empty_source(string? path)
    {
        Assert.That(await LectureFile.ReadAsync(path, new CaptureLog(), CancellationToken.None), Is.Empty);
    }

    [Test]
    public async Task A_missing_file_is_an_empty_source_and_a_warning_without_the_path()
    {
        var log = new CaptureLog();

        var documents = await LectureFile.ReadAsync(Path.Combine(directory, "nope.ndjson"), log, CancellationToken.None);

        Assert.That(documents, Is.Empty);
        Assert.That(log.Lines.Single().Level, Is.EqualTo(LogLevel.Warning));
        Assert.That(log.Lines.Single().Line, Does.Not.Contain(directory));
    }

    [TestCase("not json")]
    [TestCase("[1,2]")]
    [TestCase("""{"title":"no slug"}""")]
    [TestCase("""{"slug":""}""")]
    [TestCase("""{"slug":5}""")]
    public async Task A_line_that_is_not_a_lecture_makes_the_whole_file_an_empty_source(string bad)
    {
        var log = new CaptureLog();
        var path = Write("""{"slug":"a1","title":"A"}""", bad);

        var documents = await LectureFile.ReadAsync(path, log, CancellationToken.None);

        Assert.That(documents, Is.Empty);
        Assert.That(log.Lines.Single().Line, Does.Contain("line 2").And.Not.Contain("no slug"));
    }

    [Test]
    public async Task A_slug_twice_makes_the_file_an_empty_source()
    {
        var path = Write("""{"slug":"a1"}""", """{"slug":"a1"}""");

        Assert.That(await LectureFile.ReadAsync(path, new CaptureLog(), CancellationToken.None), Is.Empty);
    }

    [Test]
    public async Task A_file_over_the_size_limit_is_an_empty_source()
    {
        var path = Path.Combine(directory, "big.ndjson");
        await using (var stream = File.Create(path))
        {
            stream.SetLength(LectureFile.MaxBytes + 1);
        }

        Assert.That(await LectureFile.ReadAsync(path, new CaptureLog(), CancellationToken.None), Is.Empty);
    }

    [Test]
    public async Task More_lectures_than_the_limit_are_an_empty_source()
    {
        var path = Write([.. Enumerable.Range(0, LectureFile.MaxLectures + 1).Select(i => $$"""{"slug":"s{{i}}"}""")]);

        Assert.That(await LectureFile.ReadAsync(path, new CaptureLog(), CancellationToken.None), Is.Empty);
    }

    [Test]
    public async Task The_fixture_of_the_test_stacks_is_read_whole()
    {
        var root = AppContext.BaseDirectory;
        while (!File.Exists(Path.Combine(root, "TsrApp.slnx")))
        {
            root = Path.GetDirectoryName(root)!;
        }

        var documents = await LectureFile.ReadAsync(Path.Combine(root, "db", "synthetic", "lectures", "lectures.ndjson"), new CaptureLog(), CancellationToken.None);

        Assert.That(documents, Has.Count.EqualTo(12));
        Assert.That(documents[0].Id, Is.EqualTo("SYNTHLEC001"));
    }
}
