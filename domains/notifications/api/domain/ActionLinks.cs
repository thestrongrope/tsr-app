using System.Text.RegularExpressions;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// PHP's action link rules: <c>MobileNotificationsModel::inAppLink</c> (a pasted website or YouTube link becomes the in-app path the app opens; the host must match exactly)
/// and <c>api_action_link_allowed</c> (only content screens and no query string for a path; an https link as is). Stricter than PHP in one place: <c>\z</c>, not <c>$</c>,
/// so a link with a trailing newline is refused.
/// </summary>
internal static partial class ActionLinks
{
    [GeneratedRegex(@"^https://(?:www\.)?thestrongrope\.com/articles/([A-Za-z0-9_-]+)/?\z", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex Article();

    [GeneratedRegex(@"^https://(?:www\.|m\.)?youtube\.com/watch\?(?:[^ \t\r\n\f\v#]*&)?v=([A-Za-z0-9_-]+)(?:&[^ \t\r\n\f\v#]*)?\z", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex YoutubeWatch();

    [GeneratedRegex(@"^https://youtu\.be/([A-Za-z0-9_-]+)/?(?:\?[^ \t\r\n\f\v#]*)?\z", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex YoutubeShort();

    [GeneratedRegex(@"^/(classes|quizzes|home|articles|videos|notifications)(/[A-Za-z0-9_-]+)*\z")]
    private static partial Regex InAppPath();

    [GeneratedRegex(@"^https://[^ \t\r\n\f\v]+\z", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex Https();

    /// <summary>The in-app path of a pasted article or video link, else the trimmed link unchanged.</summary>
    public static string InApp(string link)
    {
        var trimmed = PhpText.Trim(link);
        var article = Article().Match(trimmed);
        if (article.Success)
        {
            return "/articles/" + article.Groups[1].Value;
        }

        var watch = YoutubeWatch().Match(trimmed);
        if (watch.Success)
        {
            return "/videos/" + watch.Groups[1].Value;
        }

        var shortLink = YoutubeShort().Match(trimmed);
        return shortLink.Success ? "/videos/" + shortLink.Groups[1].Value : trimmed;
    }

    public static bool Allowed(string link) => InAppPath().IsMatch(link) || Https().IsMatch(link);
}
