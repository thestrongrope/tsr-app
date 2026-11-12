using NUnit.Framework;

namespace Tsr.Identity.Api.Tests;

/// <summary>PHP's API_DELETION_ALLOWED: a live deletion request leaves only these routes open.</summary>
public sealed class DeletionGateTests
{
    [TestCase("/health", "GET")]
    [TestCase("/auth/link", "POST")]
    [TestCase("/auth/debug-token", "POST")]
    [TestCase("/me", "GET")]
    [TestCase("/me/deletion-request", "GET")]
    [TestCase("/me/deletion-request", "POST")]
    [TestCase("/me/deletion-request", "DELETE")]
    [TestCase("/devices", "DELETE")]
    [TestCase("/auth/link", "post")]
    public void A_live_request_still_allows_the_listed_routes(string pattern, string method)
    {
        Assert.That(DeletionGate.Allows(pattern, method), Is.True);
    }

    [TestCase("/feedback", "POST")]
    [TestCase("/me", "PATCH")]
    [TestCase("/devices", "POST")]
    [TestCase("/auth/link", "GET")]
    [TestCase("", "GET")]
    public void A_live_request_refuses_everything_else_and_unknown_routes(string pattern, string method)
    {
        Assert.That(DeletionGate.Allows(pattern, method), Is.False);
    }

    [TestCase("pending", true)]
    [TestCase("awaiting_prize_delivery", true)]
    [TestCase("completed", false)]
    [TestCase("cancelled", false)]
    public void Only_pending_and_awaiting_prize_delivery_are_live(string status, bool live)
    {
        Assert.That(DeletionGate.IsLive(status), Is.EqualTo(live));
    }
}
