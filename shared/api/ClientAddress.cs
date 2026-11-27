using System.Net;
using System.Net.Sockets;
using Microsoft.AspNetCore.Http;

namespace Tsr.Shared.Api;

/// <summary>
/// PHP <c>client_ip()</c> (functions.php): the peer's address, unless the peer is a trusted proxy (loopback, 10/8, 172.16/12, 192.168/16: PHP's default TRUSTED_PROXIES), when it is the last hop of
/// X-Forwarded-For that is a valid address and not itself trusted. "unknown" when there is no peer address. The one reading of a caller's address: the join-preview and quiz-info rate limits (classes, assessment), the sign-in record
/// (identity) and the admin access log (platform). A Client-IP header is never read.
/// </summary>
public static class ClientAddress
{
    public const string Unknown = "unknown";

    /// <summary>The address of the caller of this request (see the class summary).</summary>
    public static string Of(HttpContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        return Of(context.Connection.RemoteIpAddress?.ToString(), context.Request.Headers["X-Forwarded-For"].ToString());
    }

    /// <summary>The caller's address as the integer key <see cref="MemberRateLimit"/> wants (the first four bytes of its SHA-256): the key of a limit that applies to a caller who may not be signed in.</summary>
    public static int RateKey(HttpContext context) => RateKey(Of(context));

    public static int RateKey(string address) => BitConverter.ToInt32(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(address)), 0);

    public static string Of(string? remote, string? forwarded)
    {
        if (string.IsNullOrEmpty(remote))
        {
            return Unknown;
        }

        if (!IsTrusted(remote) || string.IsNullOrEmpty(forwarded))
        {
            return remote;
        }

        foreach (var hop in forwarded.Split(',').Reverse())
        {
            var text = hop.Trim();
            if (IPAddress.TryParse(text, out _) && !IsTrusted(text))
            {
                return text;
            }
        }

        return remote;
    }

    private static bool IsTrusted(string text)
    {
        if (!IPAddress.TryParse(text, out var ip))
        {
            return false;
        }

        if (ip.IsIPv4MappedToIPv6)
        {
            ip = ip.MapToIPv4();
        }

        if (IPAddress.IsLoopback(ip))
        {
            return true;
        }

        if (ip.AddressFamily != AddressFamily.InterNetwork)
        {
            return false;
        }

        var b = ip.GetAddressBytes();
        return b[0] == 10 || (b[0] == 172 && b[1] is >= 16 and <= 31) || (b[0] == 192 && b[1] == 168);
    }
}
