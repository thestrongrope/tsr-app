using Tsr.Platform.Api.Domain;
using Xunit;

namespace Tsr.Platform.Api.Tests.Domain;

public sealed class ClientIdTests
{
    [Theory]
    [InlineData("3f2b8c1e-9a4d-4e6f-8b2a-1c3d5e7f9a0b")]
    [InlineData("abc123")]
    public void Uuid_like_ids_are_accepted(string raw) => Assert.True(ClientId.Create(raw).IsSuccess);

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("has space")]
    [InlineData("semi;colon")]
    [InlineData("0123456789012345678901234567890123456")]
    public void Other_ids_are_refused(string? raw)
    {
        var result = ClientId.Create(raw);

        Assert.False(result.IsSuccess);
        Assert.Equal("clientId is required", result.Error);
    }
}
