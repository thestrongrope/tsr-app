using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Options;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>The PDF renderer's address is a required setting: like the database and Firebase settings, the API refuses to start without it.</summary>
public sealed class GotenbergSettingTests
{
    private static WebApplicationFactory<Program> Host(string? url) =>
        new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseSetting("TSR_DB", "Host=unused");
            builder.UseSetting("TSR_FIREBASE_PROJECT_ID", "demo-tsr-test");
            builder.UseSetting("TSR_AUTH_EMULATOR_HOST", "localhost:9099");
            if (url is not null)
            {
                builder.UseSetting("TSR_GOTENBERG_URL", url);
            }
        });

    [TestCase(null)]
    [TestCase("not a url")]
    public void The_host_refuses_to_start_without_a_usable_renderer_address(string? url)
    {
        using var host = Host(url);

        var error = Assert.Catch(() => host.CreateClient());

        Assert.That(error, Is.InstanceOf<OptionsValidationException>().Or.With.InnerException.InstanceOf<OptionsValidationException>());
        Assert.That(error!.ToString(), Does.Contain("TSR_GOTENBERG_URL"));
    }

    [Test]
    public void The_host_starts_with_one()
    {
        using var host = Host("http://gotenberg:3000");

        Assert.DoesNotThrow(() => host.CreateClient().Dispose());
    }
}
