using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issue 99 (ACC-R12). Registration order is migration order: a domain's migrations may refer to tables an earlier domain owns.
/// Moving <c>access</c> off Entity Framework at run time changes how it is registered, so the order of the migrate job is pinned here.
/// </summary>
public sealed class MigrationOrderTests
{
    // search registers no context (it reads through its own feed), so eight schemas migrate, not nine.
    private static readonly string[] TodaysOrder = ["identity", "access", "platform", "membership", "content", "classes", "assessment", "notifications"];

    [Test]
    public void The_migrate_mode_registers_the_domains_in_todays_order()
    {
        var schemas = MigrationSchemas(RunMode.Migrate);

        Assert.That(schemas, Is.EqualTo(TodaysOrder));
    }

    [TestCase(RunMode.Api)]
    [TestCase(RunMode.Workers)]
    [TestCase(RunMode.LoadContent)]
    public void The_api_mode_registers_no_access_context(RunMode mode)
    {
        var services = Register(mode);

        var accessTypes = services
            .Select(descriptor => descriptor.ServiceType)
            .Where(type => type.ToString().Contains("AccessContext", StringComparison.Ordinal))
            .ToList();

        Assert.Multiple(() =>
        {
            Assert.That(accessTypes, Is.Empty, "access reads and writes through the data source: its context is for the migrate job only");
            Assert.That(MigrationSchemas(mode), Does.Not.Contain("access"));
        });
    }

    [Test]
    public void The_migrate_mode_registers_the_access_context()
    {
        var optionTypes = Register(RunMode.Migrate)
            .Select(descriptor => descriptor.ServiceType.ToString())
            .Where(name => name.Contains("DbContextOptions", StringComparison.Ordinal) && name.Contains("AccessContext", StringComparison.Ordinal));

        Assert.That(optionTypes, Is.Not.Empty, "the migrate job applies access's migrations through its context");
    }

    [TestCase(RunMode.Api)]
    [TestCase(RunMode.Workers)]
    [TestCase(RunMode.LoadContent)]
    public void The_api_mode_registers_no_content_context(RunMode mode)
    {
        var services = Register(mode);

        var contentTypes = services
            .Select(descriptor => descriptor.ServiceType)
            .Where(type => type.ToString().Contains("ContentContext", StringComparison.Ordinal))
            .ToList();

        Assert.Multiple(() =>
        {
            Assert.That(contentTypes, Is.Empty, "content reads and writes through the data source: its context is for the migrate job only");
            Assert.That(MigrationSchemas(mode), Does.Not.Contain("content"));
        });
    }

    [Test]
    public void The_migrate_mode_registers_the_content_context()
    {
        var optionTypes = Register(RunMode.Migrate)
            .Select(descriptor => descriptor.ServiceType.ToString())
            .Where(name => name.Contains("DbContextOptions", StringComparison.Ordinal) && name.Contains("ContentContext", StringComparison.Ordinal));

        Assert.That(optionTypes, Is.Not.Empty, "the migrate job applies content's migrations through its context");
    }

    // Issue 102 (IDN-R14, R17): identity is converted too. The migrate job still registers its context, first; no other mode does.
    [TestCase(RunMode.Api)]
    [TestCase(RunMode.Workers)]
    [TestCase(RunMode.LoadContent)]
    public void The_api_mode_registers_no_identity_context(RunMode mode)
    {
        var services = Register(mode);

        var identityTypes = services
            .Select(descriptor => descriptor.ServiceType)
            .Where(type => type.ToString().Contains("IdentityContext", StringComparison.Ordinal))
            .ToList();

        Assert.Multiple(() =>
        {
            Assert.That(identityTypes, Is.Empty, "identity reads and writes through the data source: its context is for the migrate job only");
            Assert.That(MigrationSchemas(mode), Does.Not.Contain("identity"));
        });
    }

    [Test]
    public void The_migrate_mode_registers_the_identity_context()
    {
        var optionTypes = Register(RunMode.Migrate)
            .Select(descriptor => descriptor.ServiceType.ToString())
            .Where(name => name.Contains("DbContextOptions", StringComparison.Ordinal) && name.Contains("IdentityContext", StringComparison.Ordinal));

        Assert.That(optionTypes, Is.Not.Empty, "the migrate job applies identity's migrations through its context");
    }

    // Issue 103: notifications is converted too. The migrate job still registers its context, last; no other mode does.
    [TestCase(RunMode.Api)]
    [TestCase(RunMode.Workers)]
    [TestCase(RunMode.LoadContent)]
    public void The_api_mode_registers_no_notifications_context(RunMode mode)
    {
        var services = Register(mode);

        var notificationsTypes = services
            .Select(descriptor => descriptor.ServiceType)
            .Where(type => type.ToString().Contains("NotificationsContext", StringComparison.Ordinal))
            .ToList();

        Assert.Multiple(() =>
        {
            Assert.That(notificationsTypes, Is.Empty, "notifications reads and writes through the data source: its context is for the migrate job only");
            Assert.That(MigrationSchemas(mode), Does.Not.Contain("notifications"));
        });
    }

    [Test]
    public void The_migrate_mode_registers_the_notifications_context()
    {
        var optionTypes = Register(RunMode.Migrate)
            .Select(descriptor => descriptor.ServiceType.ToString())
            .Where(name => name.Contains("DbContextOptions", StringComparison.Ordinal) && name.Contains("NotificationsContext", StringComparison.Ordinal));

        Assert.That(optionTypes, Is.Not.Empty, "the migrate job applies notifications' migrations through its context");
    }

    // Issue 103: platform, membership, assessment and classes are converted too. The migrate job still registers their contexts; no other mode does.
    [Test]
    public void The_api_modes_register_no_context_of_platform_membership_assessment_or_classes([Values(RunMode.Api, RunMode.Workers, RunMode.LoadContent)] RunMode mode, [Values("platform", "membership", "assessment", "classes")] string domain)
    {
        var contextName = char.ToUpperInvariant(domain[0]) + domain[1..] + "Context";
        var types = Register(mode)
            .Select(descriptor => descriptor.ServiceType)
            .Where(type => type.ToString().Contains(contextName, StringComparison.Ordinal))
            .ToList();

        Assert.Multiple(() =>
        {
            Assert.That(types, Is.Empty, $"{domain} reads and writes through the data source: its context is for the migrate job only");
            Assert.That(MigrationSchemas(mode), Does.Not.Contain(domain));
        });
    }

    [TestCase("Platform")]
    [TestCase("Membership")]
    [TestCase("Assessment")]
    [TestCase("Classes")]
    public void The_migrate_mode_registers_the_context_of_each_remaining_domain(string name)
    {
        var optionTypes = Register(RunMode.Migrate)
            .Select(descriptor => descriptor.ServiceType.ToString())
            .Where(type => type.Contains("DbContextOptions", StringComparison.Ordinal) && type.Contains(name + "Context", StringComparison.Ordinal));

        Assert.That(optionTypes, Is.Not.Empty, $"the migrate job applies {name}'s migrations through its context");
    }

    /// <summary>
    /// Issue 108: the native build leaves Entity Framework out (the switch is off there), so <c>--migrate</c> refuses at once and names the image that migrates,
    /// before any other setting is read. Here the switch is turned off for the one call and restored after.
    /// </summary>
    [Test]
    public async Task Without_entity_framework_the_migrate_mode_refuses_and_names_the_migrate_image()
    {
        var entry = typeof(Program).Assembly.EntryPoint ?? throw new InvalidOperationException("The API assembly has no entry point.");
        string[] args = ["--migrate"];
        AppContext.SetSwitch(HostServices.MigrationsSwitch, false);
        try
        {
            var error = await Assert.ThrowsAsync<System.Reflection.TargetInvocationException>(async () =>
            {
                var result = await Task.Run(() => entry.Invoke(null, [args]));
                if (result is Task task)
                {
                    await task;
                }
            });

            Assert.That(error!.InnerException, Is.InstanceOf<InvalidOperationException>());
            Assert.That(error.InnerException!.Message, Does.Contain("--migrate").And.Contain("target migrate"));
            Assert.That(() => Register(RunMode.Migrate), Throws.InvalidOperationException.With.Message.Contain("target migrate"));
        }
        finally
        {
            AppContext.SetSwitch(HostServices.MigrationsSwitch, true);
        }
    }

    /// <summary>The registrations are read from the container description by name, because the record is internal to shared/api.</summary>
    private static List<string> MigrationSchemas(RunMode mode) =>
        Register(mode)
            .Where(descriptor => descriptor.ServiceType.Name == "MigrationTarget")
            .Select(descriptor => (string)descriptor.ServiceType.GetProperty("Schema")!.GetValue(descriptor.ImplementationInstance)!)
            .ToList();

    private static ServiceCollection Register(RunMode mode)
    {
        var services = new ServiceCollection();
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["TSR_FIREBASE_PROJECT_ID"] = "demo-tsr-test" })
            .Build();
        var environment = new Microsoft.Extensions.Hosting.Internal.HostingEnvironment { EnvironmentName = Environments.Production };
        services.AddSingleton(new DbSettings("Host=localhost;Database=unused"));
        services.AddSingleton(TimeProvider.System);
        services.AddLogging();

        HostServices.AddDomains(services, environment, configuration, mode);

        return services;
    }
}
