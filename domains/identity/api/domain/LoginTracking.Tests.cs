using System.Net;
using Microsoft.AspNetCore.Http;
using NUnit.Framework;

namespace Tsr.Identity.Api.Domain;

[TestFixture]
internal sealed class LoginTrackingTests
{
    private static string? IpOf(string? remote, string? forwarded, string? clientIp)
    {
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = remote is null ? null : IPAddress.Parse(remote);
        if (forwarded is not null)
        {
            context.Request.Headers["X-Forwarded-For"] = forwarded;
        }

        if (clientIp is not null)
        {
            context.Request.Headers["Client-IP"] = clientIp;
        }

        return LoginTracking.From(context.Request).Ip;
    }

    // Decided 11 Nov 2026, stricter than PHP (which believes Client-IP and X-Forwarded-For as sent): a forwarded address counts only when the peer is our own proxy, and Client-IP never.
    [TestCase("172.18.0.5", "198.51.100.7, 203.0.113.9", null, "203.0.113.9", Description = "behind the gateway: the hop the gateway added, not the one the caller sent")]
    [TestCase("172.18.0.5", "203.0.113.9", "198.51.100.7", "203.0.113.9", Description = "a Client-IP header is never believed")]
    [TestCase("203.0.113.50", "198.51.100.7", null, "203.0.113.50", Description = "a peer that is not our proxy: its own address")]
    [TestCase("203.0.113.50", null, "198.51.100.7", "203.0.113.50")]
    [TestCase(null, "198.51.100.7", null, null, Description = "no peer address: nothing is recorded")]
    public void The_sign_in_address_is_the_peer_or_the_hop_our_proxy_added(string? remote, string? forwarded, string? clientIp, string? expected) =>
        Assert.That(IpOf(remote, forwarded, clientIp), Is.EqualTo(expected));
}
