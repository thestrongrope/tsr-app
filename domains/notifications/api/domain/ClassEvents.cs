using System.Globalization;
using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Access.Api;

namespace Tsr.Notifications.Api.Domain;

/// <summary>A live scheduled event of a class, as the calendar slices read it.</summary>
internal sealed record ClassEventRow(int Id, int ClassId, int CreatedBy, int CreatedByUserId, string Message, string? Description, string? ActionLink, string Weekdays, TimeOnly SendTime, string Tz);

/// <summary>A live timetable slot of a class, from classes' published view.</summary>
internal sealed record ClassSlotRow(int Id, int ClassId, int Day, int Hour, int Minute, string? Timezone);

/// <summary>The calendar items of one class in their wire form.</summary>
internal sealed record ClassCalendarItems(List<Dictionary<string, object?>> Events, List<Dictionary<string, object?>> Slots);

/// <summary>
/// What the calendar and the class event slices share (PHP <c>MobileCalendarModel</c>: <c>requireSender</c>, <c>find</c>, <c>editable</c>, <c>eventPayload</c>, <c>itemsByClass</c>).
/// Managing a class's events needs <c>notifications:send</c> on the class, the permission of sending to it. An event is edited by its owner, or by another sender once the owner has
/// lost that permission (a take-over, which does not move ownership). Other domains are read through published views only.
/// </summary>
internal static class ClassEvents
{
    public const int MaxPerClass = 500;
    public const string NotFoundError = "Scheduled event not found";

    /// <summary>The route guard: null when the caller may send notifications for the class, else PHP's 403. PHP does not look the class up first, so an unknown class is this 403 too.</summary>
    public static async Task<IResult?> ManageRefusalAsync(Permissions permissions, Caller caller, int classId, CancellationToken ct) =>
        await permissions.CanAsync(caller, "notifications:send", AccessTarget.ForClass(classId), ct)
            ? null
            : Problem.Detail(StatusCodes.Status403Forbidden, "You cannot manage events for this class");

    public static IResult NotFound() => Problem.Detail(StatusCodes.Status404NotFound, NotFoundError);

    /// <summary>The live event with this id in THIS class, or null: another class's id and a deleted event are both absent.</summary>
    public static async Task<ClassEventRow?> FindAsync(NpgsqlDataSource source, int classId, int id, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
            select id as "Id", class_id as "ClassId", created_by as "CreatedBy", created_by_user_id as "CreatedByUserId", message as "Message", description as "Description",
                   action_link as "ActionLink", weekdays as "Weekdays", send_time as "SendTime", tz as "Tz"
            from notifications.class_scheduled_events where class_id = {classId} and id = {id} and status = 'active' limit 1
            """,
            ReadEvent,
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    /// <summary>
    /// Whether a caller who may manage the class may change this event: its owner, or anyone once the owner can no longer send for the class.
    /// <paramref name="ownerCanSend"/> remembers the answer per owner for one request, so a list of 500 events asks once per owner.
    /// </summary>
    public static async Task<bool> EditableAsync(Permissions permissions, Caller caller, ClassEventRow row, Dictionary<int, bool> ownerCanSend, CancellationToken ct)
    {
        if (row.CreatedByUserId == caller.UserId)
        {
            return true;
        }

        if (!ownerCanSend.TryGetValue(row.CreatedByUserId, out var can))
        {
            can = row.CreatedByUserId > 0
                && await permissions.CanAsync(new Caller(row.CreatedByUserId, row.CreatedBy), "notifications:send", AccessTarget.ForClass(row.ClassId), ct);
            ownerCanSend[row.CreatedByUserId] = can;
        }

        return !can;
    }

    /// <summary>PHP <c>eventPayload</c>, key order included. <paramref name="editable"/> is false on a member's own calendar, which never edits.</summary>
    public static Dictionary<string, object?> Payload(ClassEventRow row, int callerUserId, bool editable) => new()
    {
        ["key"] = "event:" + row.Id.ToString(CultureInfo.InvariantCulture),
        ["id"] = row.Id,
        ["kind"] = "event",
        ["class_id"] = row.ClassId,
        ["message"] = row.Message,
        ["description"] = row.Description,
        ["action_link"] = row.ActionLink,
        ["weekdays"] = row.Weekdays.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(d => int.Parse(d, CultureInfo.InvariantCulture)).ToList(),
        ["send_time"] = row.SendTime.ToString("HH:mm", CultureInfo.InvariantCulture),
        ["timezone"] = row.Tz,
        ["created_by_user_id"] = row.CreatedByUserId,
        ["editable_by_me"] = editable,
        ["takeover"] = editable && row.CreatedByUserId != callerUserId,
    };

    /// <summary>The wire form of one event for a caller who manages its class.</summary>
    public static async Task<Dictionary<string, object?>> ManagedPayloadAsync(Permissions permissions, Caller caller, ClassEventRow row, CancellationToken ct) =>
        Payload(row, caller.UserId, await EditableAsync(permissions, caller, row, [], ct));

    /// <summary>
    /// PHP <c>itemsByClass</c>: the live events and live timetable slots of several classes, by id, in two queries however many classes. <paramref name="permissions"/> is null for a
    /// member's own calendar (nothing is editable there, and no permission is asked). More than <see cref="MaxPerClass"/> of either in one class is a broken invariant, not a request error.
    /// </summary>
    public static async Task<Dictionary<int, ClassCalendarItems>> ItemsByClassAsync(NpgsqlDataSource source, Permissions? permissions, Caller caller, int[] classIds, CancellationToken ct)
    {
        var items = classIds.ToDictionary(id => id, _ => new ClassCalendarItems([], []));
        if (classIds.Length == 0)
        {
            return items;
        }

        var limit = classIds.Length * (MaxPerClass + 1);
        var ownerCanSend = new Dictionary<int, bool>();
        foreach (var row in await EventsAsync(source, classIds, limit, ct))
        {
            var editable = permissions is not null && await EditableAsync(permissions, caller, row, ownerCanSend, ct);
            items[row.ClassId].Events.Add(Payload(row, caller.UserId, editable));
        }

        foreach (var slot in await SlotsAsync(source, classIds, limit, ct))
        {
            items[slot.ClassId].Slots.Add(SlotPayload(slot));
        }

        if (items.Values.Any(i => i.Events.Count > MaxPerClass || i.Slots.Count > MaxPerClass))
        {
            throw new InvalidOperationException("Calendar exceeds the supported event limit");
        }

        return items;
    }

    private static ClassEventRow ReadEvent(DbRow row) => new(
        row.Int("Id"),
        row.Int("ClassId"),
        row.Int("CreatedBy"),
        row.Int("CreatedByUserId"),
        row.Text("Message"),
        row.TextOrNull("Description"),
        row.TextOrNull("ActionLink"),
        row.Text("Weekdays"),
        row.Time("SendTime"),
        row.Text("Tz"));

    private static Task<List<ClassEventRow>> EventsAsync(NpgsqlDataSource source, int[] classIds, int limit, CancellationToken ct) =>
        source.ListAsync(
            $"""
            select id as "Id", class_id as "ClassId", created_by as "CreatedBy", created_by_user_id as "CreatedByUserId", message as "Message", description as "Description",
                   action_link as "ActionLink", weekdays as "Weekdays", send_time as "SendTime", tz as "Tz"
            from notifications.class_scheduled_events where class_id = any({classIds}) and status = 'active' order by id limit {limit}
            """,
            ReadEvent,
            ct);

    private static Task<List<ClassSlotRow>> SlotsAsync(NpgsqlDataSource source, int[] classIds, int limit, CancellationToken ct) =>
        source.ListAsync(
            $"""
            select id as "Id", class_id as "ClassId", coalesce(day, 0) as "Day", coalesce(hour, 0) as "Hour", coalesce(minute, 0) as "Minute", timezone as "Timezone"
            from classes.v_class_schedules where class_id = any({classIds}) and deleted_at is null order by id limit {limit}
            """,
            row => new ClassSlotRow(row.Int("Id"), row.Int("ClassId"), row.Int("Day"), row.Int("Hour"), row.Int("Minute"), row.TextOrNull("Timezone")),
            ct);

    private static Dictionary<string, object?> SlotPayload(ClassSlotRow slot) => new()
    {
        ["key"] = "slot:" + slot.Id.ToString(CultureInfo.InvariantCulture),
        ["kind"] = "slot",
        ["class_id"] = slot.ClassId,
        ["message"] = "Class timetable",
        ["description"] = null,
        ["action_link"] = "/classes/" + slot.ClassId.ToString(CultureInfo.InvariantCulture) + "/dashboard",
        ["weekdays"] = new List<int> { slot.Day },
        ["send_time"] = slot.Hour.ToString("00", CultureInfo.InvariantCulture) + ":" + slot.Minute.ToString("00", CultureInfo.InvariantCulture),
        ["timezone"] = slot.Timezone,
        ["editable_by_me"] = false,
        ["takeover"] = false,
    };
}
