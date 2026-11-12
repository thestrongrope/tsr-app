namespace Tsr.Search.Api.Domain;

/// <summary>
/// Where Elasticsearch is: <c>TSR_ELASTICSEARCH_URL</c> (PHP's ELASTICSEARCH_URL) and, when it needs one, <c>TSR_ELASTICSEARCH_PASSWORD</c>
/// (PHP's ELASTICSEARCH_PASSWORD, the password of the user "elastic"). Both are optional: without a valid URL the API still starts
/// and every kind reads as unavailable, as PHP does when Elasticsearch is down. The password is never logged.
/// </summary>
internal sealed record SearchSettings(Uri? Url, string Password)
{
    public const string UrlKey = "TSR_ELASTICSEARCH_URL";

    public const string PasswordKey = "TSR_ELASTICSEARCH_PASSWORD";

    public const string User = "elastic";

    public static SearchSettings From(string? url, string? password) =>
        new(Uri.TryCreate(url, UriKind.Absolute, out var uri) && uri.Scheme is "http" or "https" ? uri : null, password ?? string.Empty);
}
