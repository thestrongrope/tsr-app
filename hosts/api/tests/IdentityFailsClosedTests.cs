using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using Tsr.Identity.Api;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>The dev verifier must never be active outside Development (fail closed).</summary>
public sealed class IdentityFailsClosedTests
{
    [TestCase("Production")]
    [TestCase("Staging")]
    public void Identity_refuses_to_start_outside_development(string environment)
    {
        var services = new ServiceCollection();
        var env = new HostingEnvironment { EnvironmentName = environment };

        Assert.Throws<InvalidOperationException>(() => services.AddIdentity(env));
    }

    [Test]
    public void Identity_registers_the_dev_verifier_in_development()
    {
        var services = new ServiceCollection();
        services.AddIdentity(new HostingEnvironment { EnvironmentName = Environments.Development });

        Assert.That(services.Any(d => d.ServiceType.Name == "ICallerVerifier"), Is.True);
    }
}
