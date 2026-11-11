using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace Tsr.Platform.Api;

/// <summary>
/// The commands platform publishes to other domains (docs/specs/initial-build/fill-phase-design.md D2): public static methods that write platform's tables
/// on the caller's own connection, so another domain never touches a platform table itself. Each is a few lines and takes plain values, not a record.
/// </summary>
public static partial class PlatformCommands
{
    // PHP is_privileged_roleid: ROLE_ADMIN, ROLE_GENTS_ADMIN, ROLE_LADIES_ADMIN, ROLE_CLASS_ADMIN, ROLE_FINANCE.
    private static readonly int[] PrivilegedRoles = [1, 3, 4, 5, 7];

    /// <summary>
    /// PHP <c>api_log_admin_action</c> (lib/audit.php, functions.php log_admin_page_access): one <c>admin_access_log</c> row for a caller whose role is privileged, with the request's
    /// path, method, client address, user agent and referer (cut to the column lengths, as PHP's substr; the session id is null). Fire and forget, as PHP: an audit write that fails is
    /// logged (without the request's values) and never fails the action it records. Call it outside a transaction, right after the permission check: PostgreSQL aborts a transaction
    /// whose statement failed, which PHP's autocommit never did.
    /// </summary>
    public static async Task RecordAdminAccessAsync(DbContext db, HttpContext context, int userId, int token, int roleId, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(context);
        if (!PrivilegedRoles.Contains(roleId))
        {
            return;
        }

        var request = context.Request;
        var path = Cut(request.Path.ToUriComponent(), 255) ?? string.Empty;
        var method = Cut(request.Method, 10) ?? string.Empty;
        var ip = Cut(ClientAddress(context), 45) ?? string.Empty;
        var userAgent = Cut(request.Headers.UserAgent.ToString(), 512);
        var referer = Cut(request.Headers.Referer.ToString(), 512);
        try
        {
            await db.Database.ExecuteSqlAsync(
                $"""
                insert into platform.admin_access_log (user_id, token, roleid, page, method, ip, user_agent, referer, session_id)
                values ({userId}, {token}, {roleId}, {path}, {method}, {ip}, {userAgent}, {referer}, null)
                """,
                ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            var logger = context.RequestServices.GetService<ILoggerFactory>()?.CreateLogger("Tsr.Platform.Api.PlatformCommands");
            if (logger is not null)
            {
                LogAuditFailed(logger, e);
            }
        }
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "The admin access log row could not be written")]
    private static partial void LogAuditFailed(ILogger logger, Exception exception);

    // PHP getRealIpAddr: Client-IP, else X-Forwarded-For (the whole header), else the peer address.
    private static string ClientAddress(HttpContext context)
    {
        var headers = context.Request.Headers;
        var clientIp = headers["Client-IP"].ToString();
        if (clientIp.Length > 0)
        {
            return clientIp;
        }

        var forwarded = headers["X-Forwarded-For"].ToString();
        return forwarded.Length > 0 ? forwarded : context.Connection.RemoteIpAddress?.ToString() ?? string.Empty;
    }

    // PHP substr to the column length; null stays null (an absent header is NULL, as PHP's `$x ? substr : null`).
    private static string? Cut(string? value, int length)
    {
        if (string.IsNullOrEmpty(value))
        {
            return null;
        }

        if (value.Length <= length)
        {
            return value;
        }

        return char.IsHighSurrogate(value[length - 1]) ? value[..(length - 1)] : value[..length];
    }
}
