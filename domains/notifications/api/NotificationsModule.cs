using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Tsr.Notifications.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api;

/// <summary>
/// notifications: push, WhatsApp reminders, devices and scheduled class notifications. Tables, the notify-core slices (devices, the inbox, announcements, class notifications) and
/// placeholder routes (Planned.cs) so far; no public interface yet. Push goes through <c>IPushSender</c> (FCM v1 over HTTP, setting <c>TSR_GOOGLE_SERVICE_ACCOUNT_B64</c>).
/// </summary>
public static class NotificationsModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7): access (permissions), platform (the push queue command and the admin audit row); identity, classes and membership are read through their v_* views.</summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access", "identity", "platform"];

    public static IServiceCollection AddNotifications(this IServiceCollection services)
    {
        services.AddDomainContext<NotificationsContext>(NotificationsContext.SchemaName);
        services.TryAddSingleton<MemberRateLimit>();
        NotifierSettings.AddNotifierSettings(services);
        // The notifier over HTTP: 30 seconds and 1 MB of answer at most per call, no redirects (optional setting TSR_NOTIFIER_URL).
        services.AddHttpClient<INotifier, Notifier>(client =>
            {
                client.Timeout = TimeSpan.FromSeconds(30);
                client.MaxResponseContentBufferSize = 1_000_000;
            })
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        // One request to FCM or Google's token endpoint may take 10 seconds at most.
        services.AddHttpClient(FcmPushSender.HttpClientName, client => client.Timeout = TimeSpan.FromSeconds(10));
        services.TryAddSingleton<IPushSender, FcmPushSender>();
        return services;
    }

    public static IEndpointRouteBuilder MapNotifications(this IEndpointRouteBuilder routes)
    {
        routes.MapWhatsApp();
        routes.MapNotifyCore();
        return routes;
    }
}
