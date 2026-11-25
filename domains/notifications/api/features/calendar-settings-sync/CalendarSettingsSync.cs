using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.CalendarSettingsSync;

// Slice: PUT /me/calendar/settings {device_key, changes: [{event_key, offset_minutes?, muted, deleted, client_updated_at}]} -> {settings: {<event_key>: setting}, rejected: [event_key],
// clock_skew, server_time}: a phone hands in the alert settings the member changed on it and gets back what is now stored for each, which may be another phone's newer change.
// Contract: spec/api.yaml. PHP: routes/calendar.php route_calendar_settings_put, MobileCalendarModel::syncSettings and applySetting. No permission beyond the sign-in: a setting is the
// member's own, and only for an item they can see. Order: the body (422 "Invalid JSON body"), device_key (422), changes a list of at most 200 (422), then each change in turn: an object (422),
// its event_key (422), the item live and in a live class the member is a current student of (if not, the key goes to `rejected` and the change is skipped, with no further check), the offset,
// the two switches, the client time (422 each). One 422 refuses the whole batch: nothing of it is kept.
// The sync rule (domain/CalendarSettings.cs): a change is kept unless the stored one is newer by the phone's own time, or equally new from a device key that is not smaller; a client time
// more than 5 minutes ahead of the server is replaced by the server's and reported (`clock_skew`); `deleted` is a tombstone, never cleared by a later change. Batches of one member run one
// after another (PHP locks the users row; here an advisory lock on the user id, because that row is identity's). Event notifications.event_settings_synced (token, written), only when a
// row was written.

internal static class CalendarSettingsSyncSlice
{
    internal sealed record EventSettingsSynced(int Token, int Written);

    /// <summary>What one batch has done so far.</summary>
    private sealed class Outcome
    {
        public Dictionary<string, object?> Settings { get; } = new(StringComparer.Ordinal);

        public List<string> Rejected { get; } = [];

        public bool Skew { get; set; }

        public int Written { get; set; }
    }

    public static IEndpointRouteBuilder MapCalendarSettingsSync(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/me/calendar/settings", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (body, bodyRefusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (bodyRefusal is not null)
        {
            return bodyRefusal;
        }

        var device = body!.Get("device_key");
        if (!CalendarSettings.IsDeviceKey(device))
        {
            return Unprocessable(CalendarSettings.DeviceKeyError);
        }

        var changes = Changes(body.Get("changes"));
        if (changes is null)
        {
            return Unprocessable(CalendarSettings.BatchError);
        }

        var now = clock.GetUtcNow();
        var outcome = new Outcome();
        await using var tx = await source.BeginAsync(ct);
        await tx.ExecuteAsync($"select pg_advisory_xact_lock(hashtext('notifications.member_event_settings'), {caller.UserId})", ct);
        foreach (var change in changes)
        {
            var error = await ApplyAsync(tx, caller, device.GetString()!, change, now, outcome, ct);
            if (error is not null)
            {
                // The transaction is left uncommitted: the changes before this one are rolled back with it.
                return Unprocessable(error);
            }
        }

        if (outcome.Written > 0)
        {
            await Outbox.WriteAsync(tx, "notifications.event_settings_synced", new EventSettingsSynced(caller.Token, outcome.Written), NotificationsJson.Default.EventSettingsSynced, clock, ct);
        }

        await tx.CommitAsync(ct);
        return Results.Json(new Dictionary<string, object?>
        {
            ["settings"] = outcome.Settings,
            ["rejected"] = outcome.Rejected,
            ["clock_skew"] = outcome.Skew,
            ["server_time"] = CalendarSettings.Iso(now),
        }, NotificationsJson.Answers.Answer);
    }

    private static IResult Unprocessable(string detail) => Problem.Detail(StatusCodes.Status422UnprocessableEntity, detail);

    // PHP's array_is_list: a JSON list, or an empty JSON object (it decodes to the same empty array).
    private static List<JsonElement>? Changes(JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Object && !value.EnumerateObject().Any())
        {
            return [];
        }

        return value.ValueKind == JsonValueKind.Array && value.GetArrayLength() <= CalendarSettings.MaxChanges ? [.. value.EnumerateArray()] : null;
    }

    /// <summary>One change: null when it was kept, lost to a stored one or rejected; else the 422 text that refuses the batch.</summary>
    private static async Task<string?> ApplyAsync(DbTx tx, Caller caller, string device, JsonElement change, DateTimeOffset now, Outcome outcome, CancellationToken ct)
    {
        if (change.ValueKind is not (JsonValueKind.Object or JsonValueKind.Array))
        {
            return CalendarSettings.ChangeNotObjectError;
        }

        var key = CalendarSettings.Key(change);
        if (!key.IsSuccess)
        {
            return key.Error;
        }

        var classId = await ClassOfAsync(tx, caller.Token, key.Value, ct);
        if (classId is null)
        {
            outcome.Rejected.Add(key.Value.Text);
            return null;
        }

        var parsed = CalendarSettings.Change(change);
        if (!parsed.IsSuccess)
        {
            return parsed.Error;
        }

        var (stamp, skew) = CalendarSettings.Stamp(parsed.Value!.ClientTime, now);
        outcome.Skew = outcome.Skew || skew;
        var stored = (await tx.ListAsync(
            $"""
            select id as "Id", user_id as "UserId", class_id as "ClassId", event_key as "EventKey", offset_minutes as "OffsetMinutes", muted as "Muted",
                   deleted_for_me as "DeletedForMe", client_updated_at as "ClientUpdatedAt", server_updated_at as "ServerUpdatedAt", device_key as "DeviceKey"
            from notifications.member_event_settings where user_id = {caller.UserId} and event_key = {key.Value.Text}::citext
            limit 1
            """,
            CalendarSettings.ReadRow,
            ct)).FirstOrDefault();
        if (stored is not null && CalendarSettings.Loses(stamp, device, stored.ClientUpdatedAt, stored.DeviceKey))
        {
            outcome.Settings[key.Value.Text] = CalendarSettings.Payload(stored);
            return null;
        }

        var muted = (short)(parsed.Value.Muted ? 1 : 0);
        var deleted = (short)(parsed.Value.Deleted || (stored?.DeletedForMe ?? 0) != 0 ? 1 : 0);
        var serverStamp = CalendarSettings.Milliseconds(now);
        var offset = parsed.Value.OffsetMinutes;
        var setting = stored is null
            ? await InsertAsync(tx, caller.UserId, key.Value.Text, classId.Value, offset, muted, deleted, stamp, serverStamp, device, ct)
            : await UpdateAsync(tx, stored, classId.Value, offset, muted, deleted, stamp, serverStamp, device, ct);
        outcome.Written++;
        outcome.Settings[key.Value.Text] = CalendarSettings.Payload(setting);
        return null;
    }

    private static async Task<EventSettingRow> InsertAsync(
        DbTx tx, int userId, string eventKey, int classId, int? offset, short muted, short deleted, DateTimeOffset stamp, DateTimeOffset serverStamp, string device, CancellationToken ct)
    {
        var ids = await tx.ListAsync(
            $"""
            insert into notifications.member_event_settings (user_id, event_key, class_id, offset_minutes, muted, deleted_for_me, client_updated_at, server_updated_at, device_key)
            values ({userId}, {eventKey}, {classId}, {offset}, {muted}, {deleted}, {stamp}, {serverStamp}, {device})
            returning id
            """,
            row => row.Int("id"),
            ct);
        return new EventSettingRow(ids.Single(), userId, classId, eventKey, offset, muted, deleted, stamp, serverStamp, device);
    }

    private static async Task<EventSettingRow> UpdateAsync(
        DbTx tx, EventSettingRow stored, int classId, int? offset, short muted, short deleted, DateTimeOffset stamp, DateTimeOffset serverStamp, string device, CancellationToken ct)
    {
        await tx.ExecuteAsync(
            $"""
            update notifications.member_event_settings
            set class_id = {classId}, offset_minutes = {offset}, muted = {muted}, deleted_for_me = {deleted}, client_updated_at = {stamp}, server_updated_at = {serverStamp}, device_key = {device}
            where id = {stored.Id}
            """,
            ct);
        return stored with { ClassId = classId, OffsetMinutes = offset, Muted = muted, DeletedForMe = deleted, ClientUpdatedAt = stamp, ServerUpdatedAt = serverStamp, DeviceKey = device };
    }

    /// <summary>The class of a live event or slot the member can see as a current student of a live class (PHP <c>settingClass</c>), or null.</summary>
    private static async Task<int?> ClassOfAsync(DbTx tx, int token, EventKey key, CancellationToken ct)
    {
        if (token <= 0)
        {
            return null;
        }

        var found = key.IsEvent
            ? await tx.ListAsync(
                $"""
                select e.class_id as "Value" from notifications.class_scheduled_events e
                join classes.v_classes c on c.id = e.class_id join classes.v_enrolments s on s.class_id = c.id
                where e.id = {key.Id} and s.token_no = {token} and s.status = 'A' and s.removed_at is null and c.status = 'A' and e.status = 'active' limit 1
                """,
                row => row.Int("Value"),
                ct)
            : await tx.ListAsync(
                $"""
                select e.class_id as "Value" from classes.v_class_schedules e
                join classes.v_classes c on c.id = e.class_id join classes.v_enrolments s on s.class_id = c.id
                where e.id = {key.Id} and s.token_no = {token} and s.status = 'A' and s.removed_at is null and c.status = 'A' and e.deleted_at is null limit 1
                """,
                row => row.Int("Value"),
                ct);
        return found.Count == 0 ? null : found[0];
    }
}
