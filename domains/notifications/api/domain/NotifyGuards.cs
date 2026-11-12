using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Platform.Api;

namespace Tsr.Notifications.Api.Domain;

/// <summary>Guards and refusals the notification slices share, each PHP's own (api/mobile/lib/response.php and the routers), so a slice reads as one guard chain.</summary>
internal static class NotifyGuards
{
    public const int MaxPage = 200;

    public static IResult NotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to do that");

    public static IResult ClassNotPermitted() => Problem.Detail(StatusCodes.Status403Forbidden, "You do not have permission to send notifications for this class");

    public static IResult ClassNotFound() => Problem.Detail(StatusCodes.Status404NotFound, "Class not found");

    public static IResult TooLarge() => Problem.Detail(StatusCodes.Status422UnprocessableEntity, "The audience is too large for one request");

    /// <summary>PHP's uncaught Firebase exception, as a readable 500 (nothing was sent and nothing was written).</summary>
    public static IResult PushNotConfigured() => Problem.Detail(StatusCodes.Status500InternalServerError, "Push notifications are not configured");

    /// <summary>The path id as PHP's <c>(int)</c> cast, kept inside a 32-bit column (a larger number matches nobody).</summary>
    public static int IdOf(string segment) => (int)Math.Clamp(PhpValue.IntOfText(segment), int.MinValue, int.MaxValue);

    /// <summary>PHP's <c>api_int_param</c>: absent or empty is the default, a whole number (a minus sign allowed) is that number, anything else is null (422 "Invalid name").</summary>
    public static long? IntParam(HttpContext context, string name, long fallback)
    {
        var values = context.Request.Query[name];
        if (values.Count == 0 || string.IsNullOrEmpty(values[^1]))
        {
            return fallback;
        }

        var raw = values[^1]!;
        var digits = raw.StartsWith('-') ? raw[1..] : raw;
        return digits.Length > 0 && digits.All(c => c is >= '0' and <= '9') ? PhpValue.IntOfText(raw) : null;
    }

    /// <summary>The page PHP's model reads: limit at least 1 (and at most <see cref="MaxPage"/>, a cap PHP lacks), offset at least 0.</summary>
    public static (int Limit, int Offset) Page(long limit, long offset) =>
        ((int)Math.Clamp(limit, 1, MaxPage), (int)Math.Clamp(offset, 0, int.MaxValue));

    /// <summary>
    /// PHP's <c>api_require_notification_admin</c>: notifications:broadcast (super administrator) or 403 "Only super administrators can {what}", then the admin audit row
    /// (platform's published command). Null when the caller passes.
    /// </summary>
    public static async Task<IResult?> AdminAsync(HttpContext context, NotificationsContext db, Permissions permissions, Caller caller, string what, CancellationToken ct)
    {
        if (!await permissions.CanAsync(caller, "notifications:broadcast", AccessTarget.None, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "Only super administrators can " + what);
        }

        await PlatformCommands.RecordAdminAccessAsync(db, context, caller.UserId, caller.Token, await permissions.RoleIdAsync(caller, ct), ct);
        return null;
    }

    /// <summary>PHP <c>api_find_class</c>: the active class whose gender, level and teacher rows all exist.</summary>
    public static async Task<bool> ClassExistsAsync(NotificationsContext db, int classId, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<int>($"""
                select c.id as "Value" from classes.v_classes c
                join platform.v_genders g on g.id = c.gender
                join membership.v_members t on t.token = c.teacher
                where c.id = {classId} and c.status = 'A' and c.level_name is not null
                limit 1
                """)
            .ToListAsync(ct);
        return rows.Count > 0;
    }

    /// <summary>The class guard chain of the four class routes: 404 when there is no such class, then 403 unless the caller may send notifications for it. Null when both pass.</summary>
    public static async Task<IResult?> ClassAccessAsync(NotificationsContext db, Permissions permissions, Caller caller, int classId, CancellationToken ct)
    {
        if (!await ClassExistsAsync(db, classId, ct))
        {
            return ClassNotFound();
        }

        return await permissions.CanAsync(caller, "notifications:send", AccessTarget.ForClass(classId), ct) ? null : ClassNotPermitted();
    }

    /// <summary>PHP's wire form of a database date-time: <c>Y-m-d H:i:s</c>, UTC.</summary>
    public static string Stamp(DateTimeOffset value) => value.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);

    /// <summary>PHP's <c>api_cast</c> 'datetime': the same with a T.</summary>
    public static string IsoStamp(DateTimeOffset value) => value.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
}
