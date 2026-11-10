using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using Tsr.Identity.Api;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>Sign-in must never start unconfigured, and the emulator must never be active outside Development (fail closed).</summary>
public sealed class IdentityFailsClosedTests
{
    [TestCase("Production")]
    [TestCase("Development")]
    public void Identity_refuses_to_start_without_a_firebase_project(string environment)
    {
        var services = new ServiceCollection();

        Assert.Throws<InvalidOperationException>(() => services.AddIdentity(Env(environment), Config(null, null)));
    }

    [Test]
    public void Identity_refuses_the_emulator_in_production()
    {
        var services = new ServiceCollection();

        Assert.Throws<InvalidOperationException>(
            () => services.AddIdentity(Env("Production"), Config("demo-x", "firebase-emulator:9099")));
    }

    [Test]
    public void Identity_registers_the_verifier_when_configured()
    {
        var services = new ServiceCollection();
        services.AddIdentity(Env("Production"), Config("tsr-real", null));

        Assert.That(services.Any(d => d.ServiceType.Name == "ICallerVerifier"), Is.True);
    }

    internal static HostingEnvironment Env(string name) => new() { EnvironmentName = name };

    internal static IConfiguration Config(string? projectId, string? emulatorHost) =>
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["TSR_FIREBASE_PROJECT_ID"] = projectId,
            ["TSR_AUTH_EMULATOR_HOST"] = emulatorHost,
        }).Build();
}
