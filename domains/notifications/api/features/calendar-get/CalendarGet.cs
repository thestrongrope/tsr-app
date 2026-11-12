using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.CalendarGet;

// Slice: GET /me/calendar -> {server_time, freshness: {max_hours, target_hours}, classes: [{class_id, code, name, events, slots}], settings: {<event_key>: setting}}: the member's calendar as a
// STUDENT: the live events and timetable slots of every live class they are currently enrolled in (enrolment active and not removed), minus the items they deleted for themselves, plus all
// their alert settings (tombstones included, so another phone learns of them). Teaching or administering a class puts nothing here; nothing is editable from here. Contract: spec/api.yaml.
// PHP: routes/calendar.php route_calendar_get, MobileCalendarModel::calendar. No permission beyond the sign-in: the query is scoped to the caller's own enrolments and settings.
// Limits (PHP's): 200 classes, 500 events and 500 slots a class, 10000 settings; past one the request fails (500) rather than answer a cut calendar. Classes and slots come from classes'
// published views.

internal static class CalendarGetSlice
{
    private const int MaxClasses = 200;
    private const int MaxSettings = 10000;

    internal sealed record ClassRow(int ClassId, string? Code, string? Name);

    public static IEndpointRouteBuilder MapCalendarGet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/me/calendar", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NotificationsContext db, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var classes = await ClassesAsync(db, caller.Token, ct);
        var settings = await SettingsAsync(db, caller.UserId, ct);
        var items = await ClassEvents.ItemsByClassAsync(db, null, caller, [.. classes.Select(c => c.ClassId)], ct);
        var hidden = settings.Where(s => s.DeletedForMe != 0).Select(s => s.EventKey).ToHashSet(StringComparer.Ordinal);
        return Results.Json(new Dictionary<string, object>
        {
            ["server_time"] = clock.GetUtcNow().UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture),
            ["freshness"] = new Dictionary<string, object> { ["max_hours"] = 12, ["target_hours"] = 6 },
            ["classes"] = classes.Select(c => ClassPayload(c, items[c.ClassId], hidden)).ToList(),
            ["settings"] = settings.ToDictionary(s => s.EventKey, CalendarSettings.Payload, StringComparer.Ordinal),
        });
    }

    private static Dictionary<string, object?> ClassPayload(ClassRow row, ClassCalendarItems items, HashSet<string> hidden) => new()
    {
        ["class_id"] = row.ClassId,
        ["code"] = row.Code,
        ["name"] = row.Name,
        ["events"] = Visible(items.Events, hidden),
        ["slots"] = Visible(items.Slots, hidden),
    };

    private static List<Dictionary<string, object?>> Visible(List<Dictionary<string, object?>> items, HashSet<string> hidden) =>
        [.. items.Where(i => !hidden.Contains((string)i["key"]!))];

    private static async Task<List<ClassRow>> ClassesAsync(NotificationsContext db, int token, CancellationToken ct)
    {
        if (token <= 0)
        {
            return [];
        }

        var rows = await db.Database
            .SqlQuery<ClassRow>($"""
                select distinct c.id as "ClassId", c.code as "Code", c.name as "Name"
                from classes.v_classes c join classes.v_enrolments s on s.class_id = c.id
                where s.token_no = {token} and s.status = 'A' and s.removed_at is null and c.status = 'A'
                order by c.id limit {MaxClasses + 1}
                """)
            .ToListAsync(ct);
        return rows.Count > MaxClasses ? throw new InvalidOperationException("Calendar exceeds the supported class limit") : rows;
    }

    private static async Task<List<MemberEventSetting>> SettingsAsync(NotificationsContext db, int userId, CancellationToken ct)
    {
        var rows = await db.MemberEventSettings.AsNoTracking().Where(s => s.UserId == userId).OrderBy(s => s.Id).Take(MaxSettings + 1).ToListAsync(ct);
        return rows.Count > MaxSettings ? throw new InvalidOperationException("Calendar exceeds the supported settings limit") : rows;
    }
}
