using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Tsr.Content.Api.Domain;

namespace Tsr.Content.Api.Features.V1Videos;

// Slice: GET /api/v1/youtube -> the channel's latest videos, newest first as the feed orders them, in the answer shape supported app builds read from today's website (domain/V1.cs).
// Public: no caller, no permission, no database. The videos come from domain/LatestVideos.cs (the feed, kept in memory for 30 minutes, the last good list when the feed fails).
// A port of tsr-web web/src/app/api/v1/youtube/route.ts; that code is the rule, quirks kept:
//   - "limit" 1 to 50 (10), "offset" from 0; at most the 50 newest videos are ever kept.
//   - the totals ("data.meta.total", "pagination.total") are the size of the slice taken (limit + offset, or fewer), not the channel's count, so "hasMore" is never true.
//   - "views" is null when the feed gives none or 0; "intro" is the first 200 characters of the description, trimmed, then "...".
//   - an ETag is sent but never compared: no 304.
// "channelId" is the channel in the code, as in tsr-web, unless the setting TSR_YOUTUBE_CHANNEL_ID names another (empty: none); the channel's name and address are tsr-web's constants.
// Every value is text of the feed sent as JSON text; nothing here is HTML.
// Contract: spec/api.yaml. Behaviour: db/tests/LatestVideosTests.cs (a fake feed); spec/tests/v1-videos.hurl (the test stacks have no channel: the empty list).

internal static class V1VideosSlice
{
    private const int MaxAgeSeconds = 3600;

    private const int StaleWhileRevalidateSeconds = 7200;

    private const int DefaultLimit = 10;

    private const int IntroLength = 200;

    private const string ChannelName = "The Strong Rope";

    private const string ChannelUrl = "https://www.youtube.com/@TheStrongRope";

    public static IEndpointRouteBuilder MapV1Videos(this IEndpointRouteBuilder routes)
    {
        V1.MapGet(routes, "/api/v1/youtube", HandleAsync);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, LatestVideos latest, IConfiguration configuration, CancellationToken ct)
    {
        var limit = V1.Int(context.Request.Query["limit"].FirstOrDefault(), DefaultLimit, min: 1, max: YouTubeFeed.MaxEntries);
        var offset = V1.Int(context.Request.Query["offset"].FirstOrDefault(), fallback: 0, min: 0);
        var end = (long)offset + limit;

        // tsr-web takes the first limit + offset videos and counts those.
        var taken = await latest.TakeAsync((int)Math.Min(end, YouTubeFeed.MaxEntries), ct);
        var total = taken.Videos.Count;
        var page = taken.Videos.Skip(offset).Take(limit).ToList();
        var channelId = YouTubeFeed.Channel(configuration).Trim();

        return V1.OkAlways(
            json => Write(json, page, taken, channelId),
            MaxAgeSeconds,
            StaleWhileRevalidateSeconds,
            new V1.Pagination(total, limit, offset, HasMore: end < total));
    }

    private static void Write(Utf8JsonWriter json, List<FeedVideo> page, LatestVideos.Taken taken, string channelId)
    {
        json.WriteStartObject();
        json.WriteStartArray("videos");
        foreach (var video in page)
        {
            Write(json, video);
        }

        json.WriteEndArray();
        json.WriteStartObject("meta");
        json.WriteNumber("total", taken.Videos.Count);
        json.WriteString("channelId", channelId);
        json.WriteString("channelName", ChannelName);
        json.WriteString("channelUrl", ChannelUrl);
        json.WriteString("lastUpdated", V1.Iso(taken.ReadAt));
        json.WriteBoolean("cacheHit", taken.FromKept);
        json.WriteEndObject();
        json.WriteEndObject();
    }

    private static void Write(Utf8JsonWriter json, FeedVideo video)
    {
        json.WriteStartObject();
        json.WriteString("id", video.VideoId);
        json.WriteString("videoId", video.VideoId);
        json.WriteString("title", video.Title);
        json.WriteString("youtubeLink", "https://www.youtube.com/watch?v=" + video.VideoId);
        json.WriteString("publishedDate", video.PublishedAt);
        json.WriteString("publishedDateFormatted", FormattedDate(video.PublishedAt));
        if (video.ViewCount > 0)
        {
            json.WriteNumber("views", video.ViewCount);
        }
        else
        {
            json.WriteNull("views");
        }

        json.WriteString("intro", Intro(video.Description));
        json.WriteString("description", video.Description);
        json.WriteStartObject("thumbnail");
        json.WriteString("url", video.Thumbnail.Length > 0 ? video.Thumbnail : "https://i.ytimg.com/vi/" + video.VideoId + "/hqdefault.jpg");
        json.WriteNumber("width", 480);
        json.WriteNumber("height", 360);
        json.WriteEndObject();
        json.WriteEndObject();
    }

    /// <summary>
    /// tsr-web: <c>toLocaleDateString('en-US', {year: 'numeric', month: 'short', day: 'numeric'})</c> in its container's zone, UTC: "Oct 5, 2026".
    /// A date that cannot be read is JavaScript's "Invalid Date". (JavaScript reads more date forms than this; the feed writes one.)
    /// </summary>
    private static string FormattedDate(string publishedAt) =>
        DateTimeOffset.TryParse(publishedAt, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var at)
            ? at.UtcDateTime.ToString("MMM d, yyyy", CultureInfo.InvariantCulture)
            : "Invalid Date";

    /// <summary>tsr-web <c>truncateDescription</c>: up to 200 characters as they are; more are cut to 200, trimmed, and end in "...".</summary>
    private static string Intro(string description) =>
        description.Length <= IntroLength ? description : description[..IntroLength].Trim() + "...";
}
