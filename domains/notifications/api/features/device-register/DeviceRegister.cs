using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.DeviceRegister;

// Slice: POST /devices {fcmToken | fcm_token} -> 201 {ok: true}: register the caller's push address. Contract: spec/api.yaml.
// PHP: routes/devices.php route_devices_register, DevicesModel::Save. Order: devices:manage (403 "You do not have permission to do that"), the token (422 "fcmToken is required").
// Rows are keyed by member and device id: the caller's own row is updated (last_accessed_at) or inserted. A device belongs to whoever registered it LAST: the rows of the same
// token held by any other member are deleted (PHP, #428). Nothing proves the caller owns the token beyond knowing it (flagged in the notes). One transaction, serialised per
// device token by an advisory lock so two registrations cannot leave two owners. Deviations: a token over 500 characters or with a NUL character is a 422 (the column holds 500).
// Limits (owner decision, 12 Nov 2026; PHP has none): 10 registrations an hour per member (429, bucket device_register, counted after the 403 and 422), and at most 20 devices: a NEW device id beyond that deletes the
// member's least recently used rows so 20 remain; a device the caller already holds is never affected.
// Event notifications.device_registered (member, how many other members lost the device); never the token.

internal static class DeviceRegisterSlice
{
    private const int MaxRegistrationsPerHour = 10;
    private const int MaxDevices = 20;

    internal sealed record DeviceRegistered(int Token, int ReassignedFrom);

    public static IEndpointRouteBuilder MapDeviceRegister(this IEndpointRouteBuilder routes)
    {
        routes.MapPost("/devices", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NotificationsContext db, Permissions permissions, MemberRateLimit limiter, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "devices:manage", AccessTarget.None, ct))
        {
            return NotifyGuards.NotPermitted();
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var token = DeviceToken.Parse(body!);
        if (!token.IsSuccess)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, token.Error!);
        }

        if (!limiter.Allow("device_register", caller.Token, MaxRegistrationsPerHour, 3600))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, "Too many device registrations. Please wait a while and try again.");
        }

        await SaveAsync(db, clock, caller.Token, token.Value!, ct);
        return Results.Json(new Dictionary<string, object> { ["ok"] = true }, statusCode: StatusCodes.Status201Created);
    }

    private static async Task SaveAsync(NotificationsContext db, TimeProvider clock, int member, string device, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlAsync($"select pg_advisory_xact_lock(hashtextextended(lower({device}), 0))", ct);
        var touched = await db.Database.ExecuteSqlAsync(
            $"update notifications.user_devices set last_accessed_at = now() where token = {member} and device_id = {device}::citext",
            ct);
        if (touched == 0)
        {
            await db.Database.ExecuteSqlAsync($"insert into notifications.user_devices (token, device_id) values ({member}, {device})", ct);
            await TrimToCapAsync(db, member, ct);
        }

        var moved = await db.Database.ExecuteSqlAsync($"delete from notifications.user_devices where device_id = {device}::citext and token <> {member}", ct);
        await Outbox.WriteAsync(db, "notifications.device_registered", new DeviceRegistered(member, moved), clock, ct);
        await transaction.CommitAsync(ct);
    }

    // A member holds at most MaxDevices: a phone must always be able to register, so the least recently used rows (oldest last_accessed_at, then oldest id) make room.
    private static async Task TrimToCapAsync(NotificationsContext db, int member, CancellationToken ct) =>
        await db.Database.ExecuteSqlAsync($"""
            delete from notifications.user_devices where id in (
                select id from notifications.user_devices where token = {member}
                order by last_accessed_at desc, id desc offset {MaxDevices})
            """, ct);
}
