using Tsr.Platform.Api.Domain;
using NUnit.Framework;

namespace Tsr.Platform.Api.Tests.Domain;

public sealed class ClientIdTests
{
    [TestCase("3f2b8c1e-9a4d-4e6f-8b2a-1c3d5e7f9a0b")]
    [TestCase("abc123")]
    public void Uuid_like_ids_are_accepted(string raw) => Assert.That(ClientId.Create(raw).IsSuccess, Is.True);

    [TestCase(null)]
    [TestCase("")]
    [TestCase("has space")]
    [TestCase("semi;colon")]
    [TestCase("0123456789012345678901234567890123456")]
    public void Other_ids_are_refused(string? raw)
    {
        var result = ClientId.Create(raw);

        Assert.That(result.IsSuccess, Is.False);
        Assert.That(result.Error, Is.EqualTo("clientId is required"));
    }
}
