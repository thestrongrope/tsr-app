using Xunit;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// A domain library exposes only its module class and its listed public interface. Slices, value
/// objects and plumbing are internal, so another domain cannot call a slice even when it lists the
/// dependency (domains/CLAUDE.md rules 1 and 2). Adding a public type means adding it here, where
/// a reviewer sees it.
/// </summary>
public sealed class PublicSurfaceTests
{
    private static readonly Dictionary<string, string[]> Allowed = new()
    {
        ["identity"] = ["IdentityModule"],
        ["access"] = ["AccessModule", "Permissions"],
        ["platform"] = ["PlatformModule"],
        ["content"] = ["ContentModule"],
    };

    public static TheoryData<string> ModuleNames()
    {
        var data = new TheoryData<string>();
        foreach (var module in Modules.All)
        {
            data.Add(module.Name);
        }

        return data;
    }

    [Theory]
    [MemberData(nameof(ModuleNames))]
    public void Module_exposes_only_its_listed_public_types(string name)
    {
        Assert.True(Allowed.ContainsKey(name), "No public surface listed for " + name + ": add it to Allowed.");
        var module = Modules.All.Single(m => m.Name == name);

        var exposed = module.Assembly.GetExportedTypes().Select(t => t.Name).Order().ToList();

        Assert.Equal(Allowed[name].Order().ToList(), exposed);
    }
}
