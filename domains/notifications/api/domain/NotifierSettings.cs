using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// Where the notifier (the TypeScript WhatsApp worker) is: the optional setting <c>TSR_NOTIFIER_URL</c> (PHP: <c>NOTIFIER_URL</c>, default http://notifier:3000). When present it must be an absolute
/// http(s) URL without a query or fragment; when absent the API still starts and every WhatsApp route answers as PHP does when the notifier cannot be reached. The address comes only from here.
/// </summary>
internal sealed class NotifierSettings
{
    public const string Key = "TSR_NOTIFIER_URL";

    public string? Url { get; set; }

    /// <summary>The address with a trailing slash so a relative route is added to it; null when the setting is absent.</summary>
    public Uri? BaseUri => string.IsNullOrEmpty(Url) ? null : new Uri(Url.EndsWith('/') ? Url : Url + "/");

    /// <summary>Absent (null or empty) is valid; anything else must be an absolute http(s) URL with a host, no user info, no query, no fragment.</summary>
    public static bool IsValid(string? url)
    {
        if (string.IsNullOrEmpty(url))
        {
            return true;
        }

        return Uri.TryCreate(url, UriKind.Absolute, out var uri)
            && uri.Scheme is "http" or "https"
            && uri.Host.Length > 0
            && uri.UserInfo.Length == 0
            && uri.Query.Length == 0
            && uri.Fragment.Length == 0;
    }

    public static IServiceCollection AddNotifierSettings(IServiceCollection services)
    {
        services.AddOptions<NotifierSettings>()
            .Configure<IConfiguration>((settings, configuration) => settings.Url = configuration[Key])
            .Validate(settings => IsValid(settings.Url), Key + " is not an http(s) URL. Leave it out to run without the notifier.")
            .ValidateOnStart();
        return services;
    }
}
