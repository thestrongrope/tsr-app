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

/// <summary>One video as the home page shows it. <see cref="Thumbnail"/> is an https address on YouTube's image hosts or null.</summary>
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

    /// <summary>The hosts of YouTube's video images: the one the route's own fallback uses (V1Videos), and the numbered ones of the channel feed.</summary>
    private static readonly HashSet<string> ImageHosts = new(StringComparer.OrdinalIgnoreCase)
    {
        "i.ytimg.com", "i1.ytimg.com", "i2.ytimg.com", "i3.ytimg.com", "i4.ytimg.com",
    };

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
    /// The videos for the page. A video without an id of YouTube's form or a title, or whose thumbnail is not an https address on
    /// YouTube's image hosts, is left out and <paramref name="warn"/> is given one line naming the reason (the id and the thumbnail go
    /// into the page's addresses, and one odd entry of an outside feed must not stop the site). No video left gives an empty list:
    /// the page has no section.
    /// </summary>
    public static IReadOnlyList<HomeVideo> Videos(VideosData data, string path, Action<string> warn)
    {
        ArgumentNullException.ThrowIfNull(data);
        ArgumentNullException.ThrowIfNull(warn);
        var videos = new List<HomeVideo>();
        foreach (var video in (data.Videos ?? []).Take(VideosShown))
        {
            var thumbnail = video.Thumbnail?.Url;
            var problem = ProblemWith(video, thumbnail);
            if (problem is not null)
            {
                warn($"site: warning: GET {path} returned a video left out of the home page: {problem}.");
                continue;
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

    private static string? ProblemWith(Video video, string? thumbnail)
    {
        if (video.VideoId is null || !VideoId().IsMatch(video.VideoId))
        {
            return "no usable video id";
        }

        if (string.IsNullOrWhiteSpace(video.Title))
        {
            return "no title";
        }

        return string.IsNullOrEmpty(thumbnail) || IsYouTubeImage(thumbnail) ? null : "a thumbnail that is not an https address on YouTube's image hosts";
    }

    private static bool IsYouTubeImage(string thumbnail) =>
        Uri.TryCreate(thumbnail, UriKind.Absolute, out var uri)
        && uri.Scheme == Uri.UriSchemeHttps
        && uri.UserInfo.Length == 0
        && ImageHosts.Contains(uri.Host);
}
