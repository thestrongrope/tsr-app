using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using NUnit.Framework;

namespace Tsr.Identity.Api.Tests;

/// <summary>Fail closed: production without a project id, or with the emulator on, never starts.</summary>
public sealed class FirebaseSettingsTests
{
    [TestCase("Production")]
    [TestCase("Development")]
    public void A_missing_project_id_refuses_to_start(string environment)
    {
        var ex = Assert.Throws<InvalidOperationException>(() => Create(environment, null, null));

        Assert.That(ex!.Message, Does.Contain("TSR_FIREBASE_PROJECT_ID"));
    }

    [Test]
    public void Production_with_a_project_id_uses_google_keys()
    {
        var settings = Create("Production", "tsr-real", null);

        Assert.That(settings.ProjectId, Is.EqualTo("tsr-real"));
        Assert.That(settings.UseEmulator, Is.False);
    }

    [TestCase("Production")]
    [TestCase("Staging")]
    public void The_emulator_outside_development_refuses_to_start(string environment)
    {
        var ex = Assert.Throws<InvalidOperationException>(() => Create(environment, "demo-x", "firebase-emulator:9099"));

        Assert.That(ex!.Message, Does.Contain("environment"));
    }

    [Test]
    public void The_emulator_needs_a_demo_project()
    {
        var ex = Assert.Throws<InvalidOperationException>(() => Create("Development", "tsr-real", "firebase-emulator:9099"));

        Assert.That(ex!.Message, Does.Contain("project"));
    }

    [Test]
    public void The_emulator_host_must_be_on_the_allow_list()
    {
        var ex = Assert.Throws<InvalidOperationException>(() => Create("Development", "demo-x", "evil.example:9099"));

        Assert.That(ex!.Message, Does.Contain("host"));
    }

    [TestCase("firebase-emulator:9099")]
    [TestCase("127.0.0.1:9099")]
    [TestCase("localhost:9099")]
    public void The_emulator_runs_in_development_with_a_demo_project_and_an_allowed_host(string host)
    {
        var settings = Create("Development", "demo-x", host);

        Assert.That(settings.UseEmulator, Is.True);
        Assert.That(settings.EmulatorHost, Is.EqualTo(host));
    }

    [Test]
    public void Development_without_the_emulator_uses_google_keys()
    {
        Assert.That(Create("Development", "tsr-real", null).UseEmulator, Is.False);
    }

    private static FirebaseSettings Create(string environment, string? projectId, string? emulatorHost)
    {
        var values = new Dictionary<string, string?>
        {
            ["TSR_FIREBASE_PROJECT_ID"] = projectId,
            ["TSR_AUTH_EMULATOR_HOST"] = emulatorHost,
        };
        var config = new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        return FirebaseSettings.Create(config, new HostingEnvironment { EnvironmentName = environment });
    }
}
