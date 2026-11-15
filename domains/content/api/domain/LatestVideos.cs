using System.Globalization;
using System.Xml;
using System.Xml.Linq;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Tsr.Shared.Api;

namespace Tsr.Content.Api.Domain;

/// <summary>One video as the channel's feed has it. <see cref="PublishedAt"/> is the feed's own text; an absent description, thumbnail or date is empty, absent views 0.</summary>
internal sealed record FeedVideo(string VideoId, string Title, string Description, string Thumbnail, string PublishedAt, long ViewCount);

/// <summary>The one external boundary of the latest videos: the channel's newest videos in the feed's order (newest first), or why they could not be read.</summary>
internal interface IVideoFeed
{
    Task<Result<IReadOnlyList<FeedVideo>>> ReadAsync(CancellationToken ct);
}

/// <summary>
/// Reads the channel's public feed (Atom), with no key: tsr-web's <c>getYouTubeVideos</c> (<c>web/src/lib/markdown.ts</c>), the same fields from the same elements.
/// One difference, on purpose: tsr-web cuts the feed's text apart with patterns and so sends it still XML-escaped ("&amp;amp;"); this reads it as XML, so the text is the text.
/// The channel is <see cref="DefaultChannel"/> unless the setting <c>TSR_YOUTUBE_CHANNEL_ID</c> names another; set to nothing, no feed is asked (every test stack sets it so). The address is the setting
/// <c>TSR_YOUTUBE_FEED_URL</c>, by default YouTube's. One attempt of at most 10 seconds and 2 MB; a redirect is not followed, so only the configured host is ever asked;
/// a document type is refused, so no entity is expanded or fetched. Every failure is a <see cref="Result{T}"/> with a fixed phrase and at most a status or an exception's type name.
/// </summary>
internal sealed class YouTubeFeed(IHttpClientFactory clients, IConfiguration configuration) : IVideoFeed
{
    public const string ClientName = "youtube-feed";

    public const string ChannelSetting = "TSR_YOUTUBE_CHANNEL_ID";

    /// <summary>The Strong Rope's channel, a public id (tsr-web has it in its code too). Read when the setting is absent.</summary>
    public const string DefaultChannel = "UCCbzUJ8KomG2nqBEzVjcBYg";

    /// <summary>The channel to read: the setting when it is present (even empty, which means none), else <see cref="DefaultChannel"/>.</summary>
    public static string Channel(IConfiguration configuration) => configuration[ChannelSetting] ?? DefaultChannel;

    public const string FeedUrlSetting = "TSR_YOUTUBE_FEED_URL";

    public const string NoChannel = "no channel id";

    public const string BadAddress = "feed address not valid";

    /// <summary>tsr-web asks for 50; entries past these are not read.</summary>
    public const int MaxEntries = 50;

    public const int MaxFeedBytes = 2 * 1024 * 1024;

    public const string TooDeep = "feed nested too deep";

    /// <summary>The deepest node a feed may have (the root element is 0). A real entry's text ends at 5.</summary>
    public const int MaxDepth = 32;

    private const string DefaultFeedUrl = "https://www.youtube.com/feeds/videos.xml";

    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(10);

    private static readonly XNamespace Atom = "http://www.w3.org/2005/Atom";

    private static readonly XNamespace Yt = "http://www.youtube.com/xml/schemas/2015";

    private static readonly XNamespace Media = "http://search.yahoo.com/mrss/";

    /// <summary>The bounds of one call. The registration and the tests both use it.</summary>
    public static void Configure(HttpClient client)
    {
        client.Timeout = Timeout;
        client.MaxResponseContentBufferSize = MaxFeedBytes;
    }

    /// <summary>The handler of the named client: a redirect is an answer, never a second request to another host.</summary>
    public static HttpMessageHandler Handler() => new SocketsHttpHandler { AllowAutoRedirect = false, ConnectTimeout = Timeout };

    public async Task<Result<IReadOnlyList<FeedVideo>>> ReadAsync(CancellationToken ct)
    {
        var channel = Channel(configuration);
        if (string.IsNullOrWhiteSpace(channel))
        {
            return Result.Fail<IReadOnlyList<FeedVideo>>(NoChannel);
        }

        var feedUrl = configuration[FeedUrlSetting];
        if (!Uri.TryCreate(string.IsNullOrWhiteSpace(feedUrl) ? DefaultFeedUrl : feedUrl, UriKind.Absolute, out var feed)
            || (feed.Scheme != Uri.UriSchemeHttps && feed.Scheme != Uri.UriSchemeHttp))
        {
            return Result.Fail<IReadOnlyList<FeedVideo>>(BadAddress);
        }

        var address = new UriBuilder(feed) { Query = "channel_id=" + Uri.EscapeDataString(channel) }.Uri;
        try
        {
            using var client = clients.CreateClient(ClientName);
            using var response = await client.GetAsync(address, ct);
            if (!response.IsSuccessStatusCode)
            {
                return Result.Fail<IReadOnlyList<FeedVideo>>(string.Create(CultureInfo.InvariantCulture, $"feed answered {(int)response.StatusCode}"));
            }

            var body = await response.Content.ReadAsByteArrayAsync(ct);
            return IsTooDeep(body) ? Result.Fail<IReadOnlyList<FeedVideo>>(TooDeep) : Result.Ok(Parse(body));
        }
        catch (Exception failure) when (failure is HttpRequestException or XmlException || (failure is OperationCanceledException && !ct.IsCancellationRequested))
        {
            // The type name only: an exception's message can hold the address or text of the feed.
            return Result.Fail<IReadOnlyList<FeedVideo>>("feed not read: " + failure.GetType().Name);
        }
    }

    private static XmlReader Reader(byte[] body) =>
        XmlReader.Create(new MemoryStream(body), new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = MaxFeedBytes });

    /// <summary>
    /// A first pass over the whole feed, node by node (a loop, no tree and no recursion), before anything builds or walks it:
    /// a document nested without end would cost minutes to walk, or the stack, and a stack overflow cannot be caught.
    /// </summary>
    private static bool IsTooDeep(byte[] body)
    {
        using var reader = Reader(body);
        while (reader.Read())
        {
            if (reader.Depth > MaxDepth)
            {
                return true;
            }
        }

        return false;
    }

    private static IReadOnlyList<FeedVideo> Parse(byte[] body)
    {
        using var reader = Reader(body);
        var entries = XDocument.Load(reader).Root?.Elements(Atom + "entry") ?? [];

        // tsr-web: an entry with no video id or no title is passed over and does not count towards the 50.
        return [.. entries.Select(Video).Where(video => video.VideoId.Length > 0 && video.Title.Length > 0).Take(MaxEntries)];
    }

    private static FeedVideo Video(XElement entry) => new(
        entry.Element(Yt + "videoId")?.Value ?? string.Empty,
        entry.Element(Atom + "title")?.Value ?? string.Empty,
        entry.Descendants(Media + "description").FirstOrDefault()?.Value ?? string.Empty,
        entry.Descendants(Media + "thumbnail").FirstOrDefault()?.Attribute("url")?.Value ?? string.Empty,
        entry.Element(Atom + "published")?.Value ?? string.Empty,
        Views(entry.Descendants(Media + "statistics").FirstOrDefault()?.Attribute("views")?.Value));

    /// <summary>tsr-web reads digits only; anything else, or a number no counter holds, is 0.</summary>
    private static long Views(string? text) =>
        long.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out var views) ? views : 0;
}

/// <summary>
/// The latest videos, kept in memory (no table): a port of <c>getCachedVideos</c> (tsr-web <c>api/v1/youtube/route.ts</c>) and of the kept list of <c>getYouTubeVideos</c>, quirks kept.
/// One read of the feed is believed for 30 minutes, whatever it gave:
///   - videos: they are the list, and also the last good list;
///   - no video at all: an empty list (the last good list is not touched);
///   - a failure, or anything the read throws: the last good list, which is empty when nothing was ever read. The answer does not say it is a kept list, and the feed is not asked again for 30 minutes.
/// A caller's cancellation ends only its wait for its turn. A read that has started is not the caller's to stop (the reader bounds it at 10 seconds): it finishes and is kept,
/// so a caller who goes away never costs the next one a second read.
/// One instance for the process. Its state is only read and written while holding <see cref="gate"/>, so requests arriving together make one read of the feed, not one each.
/// </summary>
internal sealed partial class LatestVideos(IVideoFeed feed, TimeProvider clock, ILogger<LatestVideos> log) : IDisposable
{
    private static readonly TimeSpan FreshFor = TimeSpan.FromMinutes(30);

    private readonly SemaphoreSlim gate = new(1, 1);

    private IReadOnlyList<FeedVideo> lastGood = [];

    private Kept? kept;

    /// <summary>The first <paramref name="count"/> videos. <see cref="Taken.FromKept"/> is tsr-web's <c>cacheHit</c>; <see cref="Taken.ReadAt"/> its <c>lastUpdated</c>.</summary>
    internal sealed record Taken(IReadOnlyList<FeedVideo> Videos, bool FromKept, DateTimeOffset ReadAt);

    private sealed record Kept(IReadOnlyList<FeedVideo> Videos, DateTimeOffset ReadAt);

    public async Task<Taken> TakeAsync(int count, CancellationToken ct)
    {
        await gate.WaitAsync(ct);
        try
        {
            var now = clock.GetUtcNow();
            if (kept is not null && now - kept.ReadAt < FreshFor)
            {
                return new Taken([.. kept.Videos.Take(count)], FromKept: true, kept.ReadAt);
            }

            kept = new Kept(await ReadAsync(), now);
            return new Taken([.. kept.Videos.Take(count)], FromKept: false, now);
        }
        finally
        {
            gate.Release();
        }
    }

    public void Dispose() => gate.Dispose();

    private async Task<IReadOnlyList<FeedVideo>> ReadAsync()
    {
        Result<IReadOnlyList<FeedVideo>> read;
        try
        {
            read = await feed.ReadAsync(CancellationToken.None);
        }
        catch (Exception failure)
        {
            // Whatever it is, the route must not fail and the feed must not be asked again at once (tsr-web catches everything too).
            // The type name only: an exception's message can hold the address or text of the feed.
            read = Result.Fail<IReadOnlyList<FeedVideo>>("feed read threw " + failure.GetType().Name);
        }

        if (!read.IsSuccess)
        {
            LogKept(log, read.Error!, lastGood.Count);
            return lastGood;
        }

        IReadOnlyList<FeedVideo> videos = [.. read.Value!.Take(YouTubeFeed.MaxEntries)];
        if (videos.Count > 0)
        {
            lastGood = videos;
        }

        return videos;
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "Latest videos: the feed was not read ({Cause}); serving the last good list of {Count}")]
    private static partial void LogKept(ILogger logger, string cause, int count);
}
