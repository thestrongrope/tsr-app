using System.Net;
using System.Net.Sockets;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP <c>client_ip()</c> (functions.php): the peer's address, unless the peer is a trusted proxy (loopback, 10/8, 172.16/12, 192.168/16: PHP's default TRUSTED_PROXIES), when it is the last hop of
/// X-Forwarded-For that is a valid address and not itself trusted. "unknown" when there is no peer address.
/// </summary>
internal static class ClientAddress
{
    public static string Of(string? remote, string? forwarded)
    {
        if (string.IsNullOrEmpty(remote))
        {
            return "unknown";
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
