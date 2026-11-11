using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ClientAddressTests
{
    [TestCase("203.0.113.9", null, "203.0.113.9")]
    [TestCase("203.0.113.9", "198.51.100.1", "203.0.113.9")]
    [TestCase("172.18.0.5", "198.51.100.1", "198.51.100.1")]
    [TestCase("127.0.0.1", "198.51.100.1, 10.0.0.2", "198.51.100.1")]
    [TestCase("10.1.2.3", "198.51.100.1, 192.168.1.1, 10.0.0.2", "198.51.100.1")]
    [TestCase("10.1.2.3", "forged, 198.51.100.7", "198.51.100.7")]
    [TestCase("10.1.2.3", "forged", "10.1.2.3")]
    [TestCase("10.1.2.3", null, "10.1.2.3")]
    [TestCase("::1", "2001:db8::1", "2001:db8::1")]
    [TestCase(null, null, "unknown")]
    public void The_forwarded_address_counts_only_behind_a_trusted_proxy_and_the_last_untrusted_hop_wins(string? remote, string? forwarded, string expected) =>
        Assert.That(ClientAddress.Of(remote, forwarded), Is.EqualTo(expected));
}
