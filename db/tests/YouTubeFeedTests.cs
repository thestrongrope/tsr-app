using System.Globalization;
using System.Net;
using System.Text;
using Microsoft.Extensions.Configuration;
using NUnit.Framework;
using Tsr.Content.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The reader of the channel's public feed (<see cref="YouTubeFeed"/>) over a stub HTTP handler: no test calls a real feed, and none needs the database.
/// The fields are those tsr-web's <c>getYouTubeVideos</c> takes (<c>lib/markdown.ts</c>); the feed text here is invented.
/// </summary>
public sealed class YouTubeFeedTests
{
    private const string FeedUrl = "https://feed.example.invalid/feeds/videos.xml";

    private const string Open = """<?xml version="1.0" encoding="UTF-8"?><feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/" xmlns="http://www.w3.org/2005/Atom"><title>Invented channel</title>""";

    private const string Close = "</feed>";

    private sealed class StubHandler(Func<HttpRequestMessage, HttpResponseMessage> answer) : HttpMessageHandler
    {
        public List<Uri?> Asked { get; } = [];

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Asked.Add(request.RequestUri);
            return Task.FromResult(answer(request));
        }
    }

    private sealed class StubClients(HttpMessageHandler handler) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.That(name, Is.EqualTo(YouTubeFeed.ClientName));
            var client = new HttpClient(handler, disposeHandler: false);
            YouTubeFeed.Configure(client);
            return client;
        }
    }

    private static string Entry(string id, string title, string extra = "") => string.Create(CultureInfo.InvariantCulture, $"""
        <entry><id>yt:video:{id}</id><yt:videoId>{id}</yt:videoId><yt:channelId>UC-synthetic</yt:channelId><title>{title}</title>
        <link rel="alternate" href="https://www.youtube.com/watch?v={id}"/><published>2026-10-05T14:00:07+00:00</published><updated>2026-10-06T01:02:03+00:00</updated>{extra}</entry>
        """);

    private static string Media(string description, int views) => string.Create(CultureInfo.InvariantCulture, $"""
        <media:group><media:title>Media title, not read</media:title><media:thumbnail url="https://img.example.invalid/a.jpg?x=1&amp;y=2" width="480" height="360"/>
        <media:description>{description}</media:description><media:community><media:statistics views="{views}"/></media:community></media:group>
        """);

    private static HttpResponseMessage Xml(string text, HttpStatusCode status = HttpStatusCode.OK) =>
        new(status) { Content = new StringContent(text, Encoding.UTF8, "text/xml") };

    private static async Task<(Result<IReadOnlyList<FeedVideo>> Read, StubHandler Handler)> ReadAsync(
        Func<HttpRequestMessage, HttpResponseMessage> answer, string? channel = "UC synthetic&1", string? feedUrl = FeedUrl)
    {
        using var handler = new StubHandler(answer);
        var settings = new Dictionary<string, string?> { [YouTubeFeed.ChannelSetting] = channel, [YouTubeFeed.FeedUrlSetting] = feedUrl };
        var feed = new YouTubeFeed(new StubClients(handler), new ConfigurationBuilder().AddInMemoryCollection(settings).Build());
        return (await feed.ReadAsync(CancellationToken.None), handler);
    }

    [Test]
    public async Task The_entries_are_read_in_the_feed_s_order_with_the_text_decoded()
    {
        var body = Open
            + Entry("vidAAA", "Tea &amp; Notes &lt;part 1&gt;", Media("Line one.\nLine two &amp; three.", 1234))
            + Entry("vidBBB", "No media group")
            + Close;

        var (read, handler) = await ReadAsync(_ => Xml(body));

        Assert.That(read.Error, Is.Null);
        Assert.That(read.Value, Is.EqualTo((FeedVideo[])
        [
            new("vidAAA", "Tea & Notes <part 1>", "Line one.\nLine two & three.", "https://img.example.invalid/a.jpg?x=1&y=2", "2026-10-05T14:00:07+00:00", 1234),
            new("vidBBB", "No media group", string.Empty, string.Empty, "2026-10-05T14:00:07+00:00", 0),
        ]));
        // The channel goes into the configured address as one escaped value; nothing else is asked.
        Assert.That(handler.Asked.Select(a => a?.AbsoluteUri), Is.EqualTo((string[])["https://feed.example.invalid/feeds/videos.xml?channel_id=UC%20synthetic%261"]));
    }

    [Test]
    public async Task An_entry_without_an_id_or_a_title_is_left_out_and_only_50_are_kept()
    {
        var entries = string.Concat(Enumerable.Range(1, 60).Select(n => Entry(string.Create(CultureInfo.InvariantCulture, $"v{n:00}"), "T")));
        var body = Open + Entry(string.Empty, "No id") + Entry("no-title", string.Empty) + entries + Close;

        var (read, _) = await ReadAsync(_ => Xml(body));

        Assert.That(read.Value, Has.Count.EqualTo(YouTubeFeed.MaxEntries));
        Assert.That((read.Value![0].VideoId, read.Value[49].VideoId), Is.EqualTo(("v01", "v50")));
    }

    [Test]
    public async Task A_feed_without_entries_is_an_empty_list_not_a_failure()
    {
        var (read, _) = await ReadAsync(_ => Xml(Open + Close));

        Assert.That((read.Error, read.Value), Is.EqualTo(((string?)null, Array.Empty<FeedVideo>())));
    }

    [TestCase(HttpStatusCode.NotFound, "feed answered 404")]
    [TestCase(HttpStatusCode.InternalServerError, "feed answered 500")]
    // A redirect is never followed (the client is set up not to), so it is one more answer that is not the feed.
    [TestCase(HttpStatusCode.Found, "feed answered 302")]
    public async Task An_answer_that_is_not_a_success_is_a_failure(HttpStatusCode status, string cause)
    {
        var (read, handler) = await ReadAsync(_ =>
        {
            var response = Xml(Open + Entry("vidAAA", "T") + Close, status);
            response.Headers.Location = new Uri("https://elsewhere.example.invalid/feed.xml");
            return response;
        });

        Assert.That(read.Error, Is.EqualTo(cause));
        Assert.That(handler.Asked, Has.Count.EqualTo(1));
    }

    [Test]
    public async Task A_feed_that_is_not_xml_is_a_failure_that_names_no_content()
    {
        var (read, _) = await ReadAsync(_ => Xml("<html><body>SECRET WORDS</body>"));

        Assert.That(read.Error, Is.EqualTo("feed not read: XmlException"));
    }

    [Test]
    public async Task A_document_type_is_refused_so_no_entity_is_ever_expanded_or_fetched()
    {
        var body = """<?xml version="1.0"?><!DOCTYPE feed [<!ENTITY leak SYSTEM "file:///etc/hostname"><!ENTITY big "aaaaaaaaaa">]>"""
            + """<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns="http://www.w3.org/2005/Atom">""" + Entry("vidAAA", "&leak;&big;") + Close;

        var (read, _) = await ReadAsync(_ => Xml(body));

        Assert.That(read.Error, Is.EqualTo("feed not read: XmlException"));
    }

    // A document far deeper than any feed is refused while it is read, before anything walks it: a stack overflow cannot be caught.
    [TestCase(1000)]
    [TestCase(200_000)]
    public async Task A_feed_nested_too_deep_is_a_failure(int levels)
    {
        var body = Open + "<entry>" + string.Concat(Enumerable.Repeat("<a>", levels)) + string.Concat(Enumerable.Repeat("</a>", levels)) + "</entry>" + Entry("vidAAA", "T") + Close;

        var (read, _) = await ReadAsync(_ => Xml(body));

        Assert.That(read.Error, Is.EqualTo(YouTubeFeed.TooDeep));
    }

    [Test]
    public async Task A_feed_nested_to_the_bound_is_read()
    {
        // feed is depth 0 and entry depth 1, so these elements end at depth MaxDepth.
        var levels = YouTubeFeed.MaxDepth - 1;
        var body = Open + "<entry>" + string.Concat(Enumerable.Repeat("<a>", levels)) + string.Concat(Enumerable.Repeat("</a>", levels)) + "</entry>" + Entry("vidAAA", "T", Media("Text", 5)) + Close;

        var (read, _) = await ReadAsync(_ => Xml(body));

        Assert.That(read.Error, Is.Null);
        Assert.That(read.Value!.Select(v => v.VideoId), Is.EqualTo((string[])["vidAAA"]));
    }

    [Test]
    public async Task A_feed_larger_than_the_cap_is_a_failure()
    {
        var body = Open + Entry("vidAAA", "T", Media(new string('x', YouTubeFeed.MaxFeedBytes), 1)) + Close;

        var (read, _) = await ReadAsync(_ => Xml(body));

        Assert.That(read.Error, Is.EqualTo("feed not read: HttpRequestException"));
    }

    [Test]
    public async Task A_feed_that_cannot_be_reached_or_takes_too_long_is_a_failure()
    {
        var (unreachable, _) = await ReadAsync(_ => throw new HttpRequestException("no route to feed.example.invalid"));
        var (slow, _) = await ReadAsync(_ => throw new TaskCanceledException("timed out"));

        Assert.That(unreachable.Error, Is.EqualTo("feed not read: HttpRequestException"));
        Assert.That(slow.Error, Is.EqualTo("feed not read: TaskCanceledException"));
    }

    [Test]
    public async Task Without_the_setting_the_project_s_own_channel_is_asked()
    {
        var (read, handler) = await ReadAsync(_ => Xml(Open + Close), channel: null);

        Assert.That(read.IsSuccess, Is.True);
        Assert.That(handler.Asked.Single()!.Query, Is.EqualTo("?channel_id=" + YouTubeFeed.DefaultChannel));
    }

    [TestCase("")]
    [TestCase("   ")]
    public async Task With_the_setting_set_to_nothing_no_feed_is_asked(string channel)
    {
        var (read, handler) = await ReadAsync(_ => Xml(Open + Close), channel);

        Assert.That(read.Error, Is.EqualTo(YouTubeFeed.NoChannel));
        Assert.That(handler.Asked, Is.Empty);
    }

    [TestCase("feeds/videos.xml")]
    [TestCase("file:///etc/hostname")]
    [TestCase("ftp://feed.example.invalid/videos.xml")]
    public async Task A_feed_address_that_is_not_http_is_refused_and_nothing_is_asked(string feedUrl)
    {
        var (read, handler) = await ReadAsync(_ => Xml(Open + Close), feedUrl: feedUrl);

        Assert.That(read.Error, Is.EqualTo(YouTubeFeed.BadAddress));
        Assert.That(handler.Asked, Is.Empty);
    }

    [Test]
    public void The_client_has_a_10_second_timeout_and_the_size_cap()
    {
        using var client = new HttpClient();

        YouTubeFeed.Configure(client);

        Assert.That((client.Timeout, client.MaxResponseContentBufferSize), Is.EqualTo((TimeSpan.FromSeconds(10), (long)YouTubeFeed.MaxFeedBytes)));
    }
}
