using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// The server itself stops reading a request body at a fixed size, whatever the route does. Each write slice already refuses a body over
/// <see cref="RequestBodies.MaxBytes"/> with a 413 and a detail; this is the backstop for a route that forgets to. Production has no proxy
/// of its own that caps the body (the dev and test stacks' gateway does, at nginx's default).
/// </summary>
public sealed class RequestSizeLimitTests
{
    [Test]
    public void The_server_caps_every_request_body()
    {
        using var host = new ApiHost();

        var limit = host.Services.GetRequiredService<IOptions<KestrelServerOptions>>().Value.Limits.MaxRequestBodySize;

        // Twice the slices' own limit: a body between the two still gets the slice's 413 with its detail; the server cuts only what is larger.
        Assert.That(limit, Is.EqualTo(2L * RequestBodies.MaxBytes));
    }
}
