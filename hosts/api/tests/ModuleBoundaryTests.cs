using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Hosting.Internal;
using Tsr.Access.Api;
using Tsr.Assessment.Api;
using Tsr.Classes.Api;
using Tsr.Content.Api;
using Tsr.Host.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api;
using Tsr.Notifications.Api;
using Tsr.Platform.Api;
using Tsr.Search.Api;
using Tsr.Shared.Api;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Enforces the plan's module rules in code, not only in review:
/// a module references only shared and the modules it lists, and its services resolve with only
/// those modules registered (so it can later run in a host of its own).
/// </summary>
public sealed class ModuleBoundaryTests
{
    private const string SharedAssembly = "Tsr.Shared.Api";

    public static IEnumerable<string> ModuleNames() => Modules.All.Select(m => m.Name);

    [TestCaseSource(nameof(ModuleNames))]
    public void Module_references_only_shared_and_its_listed_dependencies(string name)
    {
        var module = Modules.All.Single(m => m.Name == name);
        var allowed = module.Dependencies.Select(AssemblyNameOf).Append(SharedAssembly).ToHashSet();

        var referenced = module.Assembly.GetReferencedAssemblies()
            .Select(a => a.Name!)
            .Where(n => n.StartsWith("Tsr.", StringComparison.Ordinal))
            .ToList();

        var undeclared = referenced.Where(r => !allowed.Contains(r)).ToList();
        Assert.That(undeclared, Is.Empty, name + " references undeclared modules");
    }

    [TestCaseSource(nameof(ModuleNames))]
    public void Module_starts_with_only_its_listed_dependencies(string name)
    {
        var module = Modules.All.Single(m => m.Name == name);
        var services = new ServiceCollection();
        services.AddSingleton(new DbSettings("Host=localhost;Database=unused"));
        services.AddSingleton(TimeProvider.System);
        // The host always provides logging and configuration; a module may rely on them (shared plumbing, not a dependency).
        services.AddLogging();
        services.AddSingleton<IConfiguration>(new ConfigurationBuilder().Build());

        Register(services, name);
        foreach (var dependency in module.Dependencies)
        {
            Register(services, dependency);
        }

        var options = new ServiceProviderOptions { ValidateOnBuild = true, ValidateScopes = true };
        using var provider = services.BuildServiceProvider(options);
        Assert.That(provider, Is.Not.Null);
    }

    [Test]
    public void Every_listed_dependency_is_a_known_module()
    {
        var known = Modules.All.Select(m => m.Name).ToHashSet();
        var unknown = Modules.All.SelectMany(m => m.Dependencies).Where(d => !known.Contains(d)).ToList();
        Assert.That(unknown, Is.Empty);
    }

    private static string AssemblyNameOf(string module) =>
        Modules.All.Single(m => m.Name == module).Assembly.GetName().Name!;

    private static void Register(IServiceCollection services, string module)
    {
        switch (module)
        {
            case "identity":
                services.AddIdentity(
                    new HostingEnvironment { EnvironmentName = Environments.Development },
                    IdentityFailsClosedTests.Config("demo-tsr-test", "localhost:9099"));
                break;
            case "access":
                services.AddAccess();
                break;
            case "platform":
                services.AddPlatform();
                break;
            case "membership":
                services.AddMembership();
                break;
            case "content":
                services.AddContent();
                break;
            case "classes":
                services.AddClasses();
                break;
            case "assessment":
                services.AddAssessment();
                break;
            case "search":
                services.AddSearch();
                break;
            case "notifications":
                services.AddNotifications();
                break;
            default:
                throw new InvalidOperationException("Unknown module " + module + ": add it to Register().");
        }
    }
}
