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
