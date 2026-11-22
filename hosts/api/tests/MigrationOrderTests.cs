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

    /// <summary>The registrations are read from the container description by name, because the record is internal to shared/api.</summary>
    private static List<string> MigrationSchemas(RunMode mode)
    {
        var services = new ServiceCollection();
        var configuration = new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build();
        var environment = new Microsoft.Extensions.Hosting.Internal.HostingEnvironment { EnvironmentName = Environments.Production };
        services.AddSingleton(new DbSettings("Host=localhost;Database=unused"));
        services.AddSingleton(TimeProvider.System);
        services.AddLogging();

        HostServices.AddDomains(services, environment, configuration, mode);

        return services
            .Where(descriptor => descriptor.ServiceType.Name == "MigrationTarget")
            .Select(descriptor => (string)descriptor.ServiceType.GetProperty("Schema")!.GetValue(descriptor.ImplementationInstance)!)
            .ToList();
    }
}
