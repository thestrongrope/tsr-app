using System.Globalization;
using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;
using Tsr.Content.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// <c>GET /api/v1/youtube</c>, the latest videos, with the API in process over a FAKE feed and a clock the test moves (LIB-R16, LIB-R17, LIB-R18, LIB-R19). No test calls a real feed.
/// The rule is tsr-web's <c>web/src/app/api/v1/youtube/route.ts</c> and <c>getYouTubeVideos</c> (<c>lib/markdown.ts</c>), quirks kept. The feed reader itself: <see cref="YouTubeFeedTests"/>.
/// </summary>
public sealed class LatestVideosTests
{
    private const string Videos = "/api/v1/youtube";

    private static readonly DateTimeOffset Start = new(2026, 11, 2, 9, 30, 0, TimeSpan.Zero);

    private FakeFeed feed = null!;
    private MovableClock clock = null!;
    private WebApplicationFactory<Program> factory = null!;
    private HttpClient client = null!;

    private sealed class MovableClock(DateTimeOffset now) : TimeProvider
    {
        public DateTimeOffset Now { get; set; } = now;

        public override DateTimeOffset GetUtcNow() => Now;
    }

    private sealed class FakeFeed : IVideoFeed
    {
        public const string Down = "feed answered 500";

        public Result<IReadOnlyList<FeedVideo>> Answer { get; set; } = Result.Fail<IReadOnlyList<FeedVideo>>(Down);

        public int Reads { get; private set; }

        /// <summary>When set, a read throws this instead of answering: a failure no reader foresaw.</summary>
        public Exception? Throws { get; set; }

        /// <summary>When set, a read waits for it, and gives up as a real call would when its token is cancelled.</summary>
        public TaskCompletionSource? Slow { get; set; }

        public async Task<Result<IReadOnlyList<FeedVideo>>> ReadAsync(CancellationToken ct)
        {
            Reads++;
            if (Slow is not null)
            {
                await Slow.Task.WaitAsync(ct);
            }

            return Throws is null ? Answer : throw Throws;
        }

        public void Fails() => Answer = Result.Fail<IReadOnlyList<FeedVideo>>(Down);

        public void Has(params FeedVideo[] videos) => Answer = Result.Ok<IReadOnlyList<FeedVideo>>(videos);

        /// <summary><paramref name="count"/> invented videos, newest first: video 1 is of 1 November 2026, each next one a day older.</summary>
        public void HasNewestFirst(int count) => Has([.. Enumerable.Range(1, count).Select(Video)]);
    }

    private sealed class CaptureLog : ILogger<LatestVideos>
    {
        public List<string> Lines { get; } = [];

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull => null;

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Add(formatter(state, exception) + (exception is null ? string.Empty : " " + exception));
    }

    private static FeedVideo Video(int number) => new(
        string.Create(CultureInfo.InvariantCulture, $"vid{number:00}"),
        string.Create(CultureInfo.InvariantCulture, $"Lesson {number}"),
        string.Create(CultureInfo.InvariantCulture, $"Notes for lesson {number}."),
        string.Create(CultureInfo.InvariantCulture, $"https://img.example.invalid/{number}.jpg"),
        new DateTimeOffset(2026, 11, 1, 8, 0, 0, TimeSpan.Zero).AddDays(1 - number).ToString("yyyy-MM-dd'T'HH:mm:ssK", CultureInfo.InvariantCulture),
        number * 10);

    [SetUp]
    public void Start_the_api_over_the_fake_feed()
    {
        feed = new FakeFeed();
        clock = new MovableClock(Start);
        factory = TestApi.Create().WithWebHostBuilder(builder =>
        {
            builder.UseSetting("TSR_YOUTUBE_CHANNEL_ID", "UC-synthetic-channel");
            builder.ConfigureTestServices(services =>
            {
                services.AddSingleton<IVideoFeed>(feed);
                services.AddSingleton<TimeProvider>(clock);
            });
        });
        client = factory.CreateClient();
    }

    [TearDown]
    public void Stop()
    {
        client.Dispose();
        factory.Dispose();
    }

    private async Task<JsonElement> GetAsync(string query = "")
    {
        var response = await client.GetAsync(Videos + query);
        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return document.RootElement.Clone();
    }

    private static List<string?> Ids(JsonElement body) => [.. body.GetProperty("data").GetProperty("videos").EnumerateArray().Select(v => v.GetProperty("videoId").GetString())];

    private static string Id(int number) => string.Create(CultureInfo.InvariantCulture, $"vid{number:00}");

    private static IEnumerable<string> IdRange(int first, int count) => Enumerable.Range(first, count).Select(Id);

    // TC-LIB-R16-01
    [Test]
    public async Task Videos_page_newest_first()
    {
        feed.HasNewestFirst(60);

        var plain = await GetAsync();
        var middle = await GetAsync("?limit=5&offset=8");
        var most = await GetAsync("?limit=99");
        var least = await GetAsync("?limit=0");

        Assert.That(Ids(plain), Is.EqualTo(IdRange(1, 10)));
        Assert.That(Ids(middle), Is.EqualTo(IdRange(9, 5)));
        // Only the 50 newest of the feed are ever kept.
        Assert.That(Ids(most), Is.EqualTo(IdRange(1, 50)));
        Assert.That(Ids(least), Is.EqualTo(IdRange(1, 1)));
        Assert.That(plain.EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])["success", "data", "meta", "pagination"]));
        Assert.That(plain.GetProperty("data").GetProperty("videos")[1].GetRawText(), Is.EqualTo(
            """
            {"id":"vid02","videoId":"vid02","title":"Lesson 2","youtubeLink":"https://www.youtube.com/watch?v=vid02","publishedDate":"2026-10-31T08:00:00+00:00",
            "publishedDateFormatted":"Oct 31, 2026","views":20,"intro":"Notes for lesson 2.","description":"Notes for lesson 2.",
            "thumbnail":{"url":"https://img.example.invalid/2.jpg","width":480,"height":360}}
            """.ReplaceLineEndings(string.Empty)));
        Assert.That(plain.GetProperty("data").GetProperty("meta").GetRawText(), Is.EqualTo(
            """{"total":10,"channelId":"UC-synthetic-channel","channelName":"The Strong Rope","channelUrl":"https://www.youtube.com/@TheStrongRope","lastUpdated":"2026-11-02T09:30:00.000Z","cacheHit":false}"""));
    }

    // tsr-web counts the slice it took (limit + offset, at most what is kept), never the channel: so "hasMore" is never true. The app pages by "got a full page".
    [TestCase("", """{"total":10,"limit":10,"offset":0,"hasMore":false}""", 10)]
    [TestCase("?limit=5&offset=8", """{"total":13,"limit":5,"offset":8,"hasMore":false}""", 5)]
    [TestCase("?limit=10&offset=45", """{"total":50,"limit":10,"offset":45,"hasMore":false}""", 5)]
    [TestCase("?limit=50&offset=60", """{"total":50,"limit":50,"offset":60,"hasMore":false}""", 0)]
    [TestCase("?limit=abc&offset=-4", """{"total":10,"limit":10,"offset":0,"hasMore":false}""", 10)]
    [TestCase("?limit=3&offset=2147483647", """{"total":50,"limit":3,"offset":2147483647,"hasMore":false}""", 0)]
    public async Task The_totals_are_the_size_of_the_slice_taken(string query, string pagination, int videos)
    {
        feed.HasNewestFirst(60);

        var body = await GetAsync(query);

        Assert.That(body.GetProperty("pagination").GetRawText(), Is.EqualTo(pagination));
        Assert.That(Ids(body), Has.Count.EqualTo(videos));
        Assert.That(body.GetProperty("data").GetProperty("meta").GetProperty("total").GetInt32(), Is.EqualTo(body.GetProperty("pagination").GetProperty("total").GetInt32()));
    }

    [Test]
    public async Task The_feed_is_read_once_in_30_minutes_and_a_kept_answer_says_so()
    {
        feed.HasNewestFirst(3);
        await GetAsync();
        feed.HasNewestFirst(5);

        clock.Now = Start.AddMinutes(29).AddSeconds(59);
        var kept = await GetAsync();
        clock.Now = Start.AddMinutes(30);
        var fresh = await GetAsync();

        Assert.That(Ids(kept), Has.Count.EqualTo(3));
        Assert.That(kept.GetProperty("data").GetProperty("meta").GetProperty("cacheHit").GetBoolean(), Is.True);
        Assert.That(kept.GetProperty("data").GetProperty("meta").GetProperty("lastUpdated").GetString(), Is.EqualTo("2026-11-02T09:30:00.000Z"));
        Assert.That(Ids(fresh), Has.Count.EqualTo(5));
        Assert.That(fresh.GetProperty("data").GetProperty("meta").GetProperty("cacheHit").GetBoolean(), Is.False);
        Assert.That(fresh.GetProperty("data").GetProperty("meta").GetProperty("lastUpdated").GetString(), Is.EqualTo("2026-11-02T10:00:00.000Z"));
        Assert.That(feed.Reads, Is.EqualTo(2));
    }

    // TC-LIB-R17-01. tsr-web's quirk, kept: the answer after a failed read does not say it is a kept list ("cacheHit" false, "lastUpdated" the time of the failed read),
    // and the feed is not asked again for 30 minutes.
    [Test]
    public async Task A_failed_feed_serves_the_kept_list()
    {
        feed.HasNewestFirst(12);
        var good = await GetAsync();
        feed.Fails();
        clock.Now = Start.AddMinutes(31);

        var afterFailure = await GetAsync();
        var again = await GetAsync("?limit=50");

        Assert.That(Ids(afterFailure), Is.EqualTo(Ids(good)));
        Assert.That(afterFailure.GetProperty("data").GetProperty("videos").GetRawText(), Is.EqualTo(good.GetProperty("data").GetProperty("videos").GetRawText()));
        Assert.That(afterFailure.GetProperty("data").GetProperty("meta").GetProperty("cacheHit").GetBoolean(), Is.False);
        Assert.That(afterFailure.GetProperty("data").GetProperty("meta").GetProperty("lastUpdated").GetString(), Is.EqualTo("2026-11-02T10:01:00.000Z"));
        Assert.That(Ids(again), Is.EqualTo(IdRange(1, 12)));
        Assert.That(feed.Reads, Is.EqualTo(2));
    }

    // A caller who goes away must not cost a read of the feed each time: the read it started finishes and is kept.
    [Test]
    public async Task A_caller_who_gives_up_during_a_slow_read_does_not_cause_a_second_read()
    {
        feed.HasNewestFirst(3);
        feed.Slow = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var latest = new LatestVideos(feed, clock, NullLogger<LatestVideos>.Instance);
        using var caller = new CancellationTokenSource();

        var abandoned = latest.TakeAsync(10, caller.Token);
        await caller.CancelAsync();
        feed.Slow.SetResult();
        var first = await abandoned;
        clock.Now = Start.AddMinutes(29);
        var next = await latest.TakeAsync(10, CancellationToken.None);

        Assert.That(first.Videos, Has.Count.EqualTo(3));
        Assert.That((next.Videos.Count, next.FromKept), Is.EqualTo((3, true)));
        Assert.That(feed.Reads, Is.EqualTo(1));
    }

    [Test]
    public async Task A_caller_who_has_already_given_up_waits_for_nothing_and_reads_nothing()
    {
        using var latest = new LatestVideos(feed, clock, NullLogger<LatestVideos>.Instance);
        using var caller = new CancellationTokenSource();
        await caller.CancelAsync();

        Assert.That(async () => await latest.TakeAsync(10, caller.Token), Throws.InstanceOf<OperationCanceledException>());
        Assert.That(feed.Reads, Is.Zero);
    }

    // LIB-R17, LIB-R18: whatever the read throws, the route does not fail, the kept list is served, and the feed is left alone for 30 minutes.
    [Test]
    public async Task A_feed_that_throws_anything_serves_the_kept_list_and_is_not_asked_again_for_30_minutes()
    {
        feed.HasNewestFirst(4);
        await GetAsync();
        feed.Throws = new InvalidOperationException("SECRET WORDS of the feed");
        clock.Now = Start.AddMinutes(31);

        var afterFailure = await GetAsync();
        clock.Now = Start.AddMinutes(60);
        var again = await GetAsync();

        Assert.That(Ids(afterFailure), Is.EqualTo(IdRange(1, 4)));
        Assert.That(Ids(again), Is.EqualTo(IdRange(1, 4)));
        Assert.That(again.GetProperty("data").GetProperty("meta").GetProperty("cacheHit").GetBoolean(), Is.True);
        Assert.That(feed.Reads, Is.EqualTo(2));
    }

    [Test]
    public async Task A_feed_that_throws_before_any_read_gives_an_empty_list_and_logs_the_type_name_only()
    {
        feed.Throws = new InvalidOperationException("SECRET WORDS of the feed");
        var log = new CaptureLog();
        using var latest = new LatestVideos(feed, clock, log);

        var taken = await latest.TakeAsync(10, CancellationToken.None);
        var body = await GetAsync();

        Assert.That(taken.Videos, Is.Empty);
        Assert.That(log.Lines, Has.Count.EqualTo(1));
        Assert.That(log.Lines[0], Does.Contain("InvalidOperationException").And.Not.Contain("SECRET"));
        Assert.That(body.GetProperty("data").GetProperty("videos").GetArrayLength(), Is.Zero);
    }

    // TC-LIB-R18-01
    [Test]
    public async Task A_feed_never_read_gives_an_empty_list()
    {
        feed.Fails();

        var body = await GetAsync();

        Assert.That(body.GetProperty("success").GetBoolean(), Is.True);
        Assert.That(body.GetProperty("data").GetProperty("videos").GetRawText(), Is.EqualTo("[]"));
        Assert.That(body.GetProperty("data").GetProperty("meta").GetProperty("total").GetInt32(), Is.Zero);
        Assert.That(body.GetProperty("pagination").GetRawText(), Is.EqualTo("""{"total":0,"limit":10,"offset":0,"hasMore":false}"""));
    }

    // tsr-web's quirk, kept: a feed that answers with no video is believed (an empty list for 30 minutes), but it does not replace the kept list a later failure falls back to.
    [Test]
    public async Task A_feed_with_no_video_is_an_empty_list_and_the_kept_list_survives_it()
    {
        feed.HasNewestFirst(4);
        await GetAsync();
        feed.Has();
        clock.Now = Start.AddMinutes(31);
        var empty = await GetAsync();
        feed.Fails();
        clock.Now = Start.AddMinutes(62);

        var afterFailure = await GetAsync();

        Assert.That(Ids(empty), Is.Empty);
        Assert.That(Ids(afterFailure), Is.EqualTo(IdRange(1, 4)));
    }

    [Test]
    public async Task A_video_s_fields_are_made_as_the_website_makes_them()
    {
        var longText = "  " + new string('a', 197) + " bcdef";
        feed.Has(
            new FeedVideo("zero-views", "No Views", longText, string.Empty, "2026-03-09T23:59:59+00:00", 0),
            new FeedVideo("other-zone", "Another Zone", string.Empty, "https://img.example.invalid/z.jpg", "2026-12-31T22:00:00-05:00", 7),
            new FeedVideo("no-date", "No Date", new string('b', 200), "https://img.example.invalid/n.jpg", string.Empty, 1));

        var videos = (await GetAsync()).GetProperty("data").GetProperty("videos");

        // No views is null, never 0. A missing thumbnail is the video's standard one. The intro is the first 200 characters, trimmed, then "...".
        Assert.That(videos[0].GetProperty("views").ValueKind, Is.EqualTo(JsonValueKind.Null));
        Assert.That(videos[0].GetProperty("thumbnail").GetProperty("url").GetString(), Is.EqualTo("https://i.ytimg.com/vi/zero-views/hqdefault.jpg"));
        Assert.That(videos[0].GetProperty("intro").GetString(), Is.EqualTo(new string('a', 197) + "..."));
        Assert.That(videos[0].GetProperty("description").GetString(), Is.EqualTo(longText));
        Assert.That(videos[0].GetProperty("publishedDateFormatted").GetString(), Is.EqualTo("Mar 9, 2026"));
        // The day is the day in UTC (tsr-web's container runs in UTC); the date itself is sent as the feed wrote it.
        Assert.That(videos[1].GetProperty("publishedDate").GetString(), Is.EqualTo("2026-12-31T22:00:00-05:00"));
        Assert.That(videos[1].GetProperty("publishedDateFormatted").GetString(), Is.EqualTo("Jan 1, 2027"));
        Assert.That((videos[1].GetProperty("intro").GetString(), videos[1].GetProperty("description").GetString()), Is.EqualTo((string.Empty, string.Empty)));
        // Exactly 200 characters is not cut. A date that cannot be read is JavaScript's "Invalid Date".
        Assert.That(videos[2].GetProperty("intro").GetString(), Is.EqualTo(new string('b', 200)));
        Assert.That((videos[2].GetProperty("publishedDate").GetString(), videos[2].GetProperty("publishedDateFormatted").GetString()), Is.EqualTo((string.Empty, "Invalid Date")));
        Assert.That(videos[2].EnumerateObject().Select(p => p.Name), Is.EqualTo((string[])
            ["id", "videoId", "title", "youtubeLink", "publishedDate", "publishedDateFormatted", "views", "intro", "description", "thumbnail"]));
    }

    // tsr-web sends an ETag on this route but never compares it: there is no 304 here.
    [Test]
    public async Task The_videos_send_the_cache_headers_and_never_a_304()
    {
        feed.HasNewestFirst(2);
        // The first answer says "cacheHit" false and the next ones true, so the ETag settles from the second answer on.
        await GetAsync();
        var first = await client.GetAsync(Videos);
        var etag = first.Headers.GetValues("ETag").Single();
        using var request = new HttpRequestMessage(HttpMethod.Get, Videos);
        request.Headers.TryAddWithoutValidation("If-None-Match", etag);

        var second = await client.SendAsync(request);

        Assert.That(first.Headers.GetValues("Cache-Control"), Is.EqualTo((string[])["public, max-age=3600, stale-while-revalidate=7200"]));
        Assert.That(etag, Does.Match("^\"[0-9a-f]{32}\"$"));
        Assert.That(first.Headers.GetValues("Access-Control-Allow-Origin"), Is.EqualTo((string[])["*"]));
        Assert.That(first.Content.Headers.Contains("Last-Modified"), Is.False);
        Assert.That(second.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(second.Headers.GetValues("ETag").Single(), Is.EqualTo(etag));
    }

    [Test]
    public async Task Without_a_channel_the_real_reader_calls_nothing_and_the_list_is_empty()
    {
        // The API as the test stacks run it: the real reader, no channel id. A call to a feed would need the network; the reader refuses before any.
        using var plain = TestApi.Create().WithWebHostBuilder(builder => builder.UseSetting("TSR_YOUTUBE_CHANNEL_ID", string.Empty));
        using var plainClient = plain.CreateClient();

        var response = await plainClient.GetAsync(Videos);
        using var document = JsonDocument.Parse(await response.Content.ReadAsStringAsync());

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(document.RootElement.GetProperty("data").GetProperty("videos").GetArrayLength(), Is.Zero);
        Assert.That(document.RootElement.GetProperty("data").GetProperty("meta").GetProperty("channelId").GetString(), Is.Empty);
        var read = await plain.Services.GetRequiredService<IVideoFeed>().ReadAsync(CancellationToken.None);
        Assert.That(read.Error, Is.EqualTo(YouTubeFeed.NoChannel));
    }
}
