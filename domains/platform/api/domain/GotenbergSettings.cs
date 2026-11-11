using Microsoft.Extensions.DependencyInjection;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// Where the PDF renderer is: the required setting <c>TSR_GOTENBERG_URL</c> (http or https, an absolute URL). Like the database and Firebase settings, the API refuses to START
/// without it (checked when the host starts, so the one-off <c>--migrate</c> job, which never starts the host, needs none).
/// </summary>
internal sealed class GotenbergSettings
{
    public const string Key = "TSR_GOTENBERG_URL";

    public string? Url { get; set; }

    public Uri BaseUri => new(Url!.EndsWith('/') ? Url : Url + "/");

    public static bool IsValid(string? url) =>
        Uri.TryCreate(url, UriKind.Absolute, out var uri) && uri.Scheme is "http" or "https";

    public static IServiceCollection AddGotenbergSettings(IServiceCollection services)
    {
        services.AddOptions<GotenbergSettings>()
            .Configure<Microsoft.Extensions.Configuration.IConfiguration>((settings, configuration) => settings.Url = configuration[Key])
            .Validate(settings => IsValid(settings.Url), Key + " is not set to an http(s) URL. Locally it comes from docker-compose.dev.yml.")
            .ValidateOnStart();
        return services;
    }
}
