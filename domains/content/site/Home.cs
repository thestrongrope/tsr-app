using System.Globalization;
using System.Text.RegularExpressions;
using Tsr.Shared.Site;

namespace Tsr.Content.Site;

/// <summary>GET /api/v1/youtube's data (domains/content/spec/api.yaml, V1Video): the fields the home page shows.</summary>
public sealed record VideosData(IReadOnlyList<Video>? Videos);

public sealed record Video(
    string? VideoId, string? Title, string? PublishedDateFormatted, long? Views, string? Description, VideoThumbnail? Thumbnail);

public sealed record VideoThumbnail(string? Url);

/// <summary>One of the latest articles as the home page shows it: its first category's title and its date, each only when known.</summary>
public sealed record HomeArticle(string Slug, string Title, string? Category, string? Date);

/// <summary>One video as the home page shows it. <see cref="Thumbnail"/> is an https address or null.</summary>
public sealed record HomeVideo(string VideoId, string Title, string? Description, string? Date, string? Views, string? Thumbnail);

/// <summary>The rules of the home page's data, as tsr-web's app/page.tsx has them. The page itself only writes what is handed to it.</summary>
public static partial class Home
{
    /// <summary>The home page shows the five newest articles.</summary>
    public const int ArticlesShown = 5;

    /// <summary>The home page shows the six newest videos.</summary>
    public const int VideosShown = 6;

    /// <summary>The address the video route is asked at.</summary>
    public const string VideosPath = "/api/v1/youtube?limit=6";

    /// <summary>The channel the "View Channel" link goes to (page.tsx).</summary>
    public const string ChannelUrl = "https://www.youtube.com/@TheStrongRope";

    private const string NoDate = "Invalid Date";

    /// <summary>A video id as YouTube writes it. It is put into an address, so nothing else is allowed.</summary>
    [GeneratedRegex("^[A-Za-z0-9_-]{1,32}$")]
    private static partial Regex VideoId();

    /// <summary>The first <see cref="ArticlesShown"/> articles of the list, which the route sends newest first.</summary>
    public static IReadOnlyList<HomeArticle> Latest(IReadOnlyList<ArticleSummary> articles, IReadOnlyList<Category> categories)
    {
        ArgumentNullException.ThrowIfNull(articles);
        ArgumentNullException.ThrowIfNull(categories);
        var titles = categories.ToDictionary(c => c.Slug!, c => TitleText.Decode(c.Title), StringComparer.Ordinal);
        return articles.Take(ArticlesShown).Select(article => new HomeArticle(
            article.Slug!,
            TitleText.Decode(article.Title),
            article.Categories!.Count > 0 && titles.TryGetValue(article.Categories[0], out var title) ? title : null,
            ShortDate(article.PublishedDate))).ToList();
    }

    /// <summary>"Nov 10, 2026" (the present site's en-US short date) for a date the file wrote, read as UTC when it has no zone; null when unreadable.</summary>
    public static string? ShortDate(string? written)
    {
        var read = DateTimeOffset.TryParse(written, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var date);
        return read ? date.UtcDateTime.ToString("MMM d, yyyy", CultureInfo.InvariantCulture) : null;
    }

    /// <summary>
    /// The videos for the page. A video without an id of YouTube's form or a title, or with a thumbnail that is not an https address,
    /// stops the build (the id and the thumbnail go into the page's addresses). No video gives an empty list: the page has no section.
    /// </summary>
    public static IReadOnlyList<HomeVideo> Videos(VideosData data, string path)
    {
        ArgumentNullException.ThrowIfNull(data);
        var videos = new List<HomeVideo>();
        foreach (var video in (data.Videos ?? []).Take(VideosShown))
        {
            var thumbnail = video.Thumbnail?.Url;
            var safe = video.VideoId is not null && VideoId().IsMatch(video.VideoId) && !string.IsNullOrWhiteSpace(video.Title)
                && (string.IsNullOrEmpty(thumbnail) || thumbnail.StartsWith("https://", StringComparison.Ordinal));
            if (!safe)
            {
                throw new SiteBuildException($"GET {path} returned a video without a usable id, title or thumbnail; the site is not built.");
            }

            videos.Add(new HomeVideo(
                video.VideoId!,
                video.Title!,
                string.IsNullOrEmpty(video.Description) ? null : video.Description,
                string.IsNullOrEmpty(video.PublishedDateFormatted) || video.PublishedDateFormatted == NoDate ? null : video.PublishedDateFormatted,
                video.Views is > 0 ? video.Views.Value.ToString("N0", CultureInfo.InvariantCulture) + " views" : null,
                string.IsNullOrEmpty(thumbnail) ? null : thumbnail));
        }

        return videos;
    }
}
