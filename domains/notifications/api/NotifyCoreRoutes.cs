using Microsoft.AspNetCore.Routing;
using Tsr.Notifications.Api.Features.ClassScheduledCreate;
using Tsr.Notifications.Api.Features.ClassScheduledDelete;
using Tsr.Notifications.Api.Features.ClassScheduledList;
using Tsr.Notifications.Api.Features.DeviceRegister;
using Tsr.Notifications.Api.Features.DeviceRemove;
using Tsr.Notifications.Api.Features.UserNotificationRead;
using Tsr.Notifications.Api.Features.UserNotifications;
using Tsr.Notifications.Api.Features.UserNotificationsReadAll;
using Tsr.Notifications.Api.Features.UserNotificationsUnreadCount;

namespace Tsr.Notifications.Api;

/// <summary>The routes of lane notify-core: devices, the member's inbox, announcements and the class notifications.</summary>
internal static class NotifyCoreRoutes
{
    public static IEndpointRouteBuilder MapNotifyCore(this IEndpointRouteBuilder routes)
    {
        routes.MapDeviceRegister();
        routes.MapDeviceRemove();
        routes.MapUserNotifications();
        routes.MapUserNotificationsUnreadCount();
        routes.MapUserNotificationsReadAll();
        routes.MapUserNotificationRead();
        routes.MapClassScheduledCreate();
        routes.MapClassScheduledList();
        routes.MapClassScheduledDelete();
        return routes;
    }
}
