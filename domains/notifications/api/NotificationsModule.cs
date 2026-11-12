using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api;

/// <summary>
/// notifications: push, WhatsApp reminders, devices and scheduled class notifications. Tables, and placeholder routes (Planned.cs) so far; no public interface yet.
/// </summary>
public static class NotificationsModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). platform (the push queue command); identity is read through its v_users view. Other domains' ids are plain integers.</summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access", "identity", "platform"];

    public static IServiceCollection AddNotifications(this IServiceCollection services)
    {
        services.AddDomainContext<NotificationsContext>(NotificationsContext.SchemaName);
        return services;
    }

    public static IEndpointRouteBuilder MapNotifications(this IEndpointRouteBuilder routes)
    {
        routes.MapPlannedRoutes();
        return routes;
    }
}
