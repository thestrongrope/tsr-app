using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;

namespace Tsr.Notifications.Api.Features.DeviceRemove;

// Slice: DELETE /devices {fcmToken | fcm_token} -> {ok: true, deleted: n}: forget one of the caller's push addresses. Contract: spec/api.yaml.
// PHP: routes/devices.php route_devices_unregister, DevicesModel::remove (a hard delete). Order as POST /devices: devices:manage (403), the token (422). Only the caller's own row
// goes (member and device id); another member's row of the same token is untouched. Event notifications.device_removed (member) only when a row went; never the token.

internal static class DeviceRemoveSlice
{
    internal sealed record DeviceRemoved(int Token);

    public static IEndpointRouteBuilder MapDeviceRemove(this IEndpointRouteBuilder routes)
    {
        routes.MapDelete("/devices", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
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

        var deleted = await RemoveAsync(source, clock, caller.Token, token.Value!, ct);
        return Results.Json(new Dictionary<string, object?> { ["ok"] = true, ["deleted"] = deleted }, NotificationsJson.Answers.Answer);
    }

    private static async Task<int> RemoveAsync(NpgsqlDataSource source, TimeProvider clock, int member, string device, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        var deleted = await tx.ExecuteAsync($"delete from notifications.user_devices where token = {member} and device_id = {device}::citext", ct);
        if (deleted > 0)
        {
            await Outbox.WriteAsync(tx, "notifications.device_removed", new DeviceRemoved(member), NotificationsJson.Default.DeviceRemoved, clock, ct);
        }

        await tx.CommitAsync(ct);
        return deleted;
    }
}
