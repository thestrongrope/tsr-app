using NUnit.Framework;

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
        // identity: the module; UserDirectory with the record it returns (UserRef); IProfileSink, the one port it declares (membership supplies it).
        ["identity"] = ["IdentityModule", "UserDirectory", "UserRef", "IProfileSink"],
        // access: the module; Permissions (the interface every domain calls) and the types in its signatures
        // (AccessTarget, Reach, SearchReach, UserAccess, AccessScopes); IClassScopes, the one port classes will supply, with the
        // two records it returns (ClassMemberships, ClassFacts). Nothing else.
        ["access"] =
        [
            "AccessModule", "Permissions", "AccessTarget", "Reach", "SearchReach", "UserAccess", "AccessScopes",
            "IClassScopes", "ClassMemberships", "ClassFacts",
        ],
        // platform: the module; Lookups and Geo (read interfaces) with the two records Geo returns (GeoCountryInfo, GeoPlace); PlatformCommands (published commands: the admin audit row).
        ["platform"] = ["PlatformModule", "Lookups", "Geo", "GeoCountryInfo", "GeoPlace", "PlatformCommands"],
        // membership: the module; MemberNames (read interface); IClassEnrolments, the one port classes will supply; MembershipCommands (published commands).
        ["membership"] = ["MembershipModule", "MemberNames", "IClassEnrolments", "MembershipCommands"],
        ["content"] = ["ContentModule"],
        // Tables and placeholder routes only so far: the module class and nothing else.
        ["classes"] = ["ClassesModule"],
        ["assessment"] = ["AssessmentModule"],
        ["notifications"] = ["NotificationsModule"],
        ["search"] = ["SearchModule"],
    };

    public static IEnumerable<string> ModuleNames() => Modules.All.Select(m => m.Name);

    [TestCaseSource(nameof(ModuleNames))]
    public void Module_exposes_only_its_listed_public_types(string name)
    {
        Assert.That(Allowed.ContainsKey(name), Is.True, "No public surface listed for " + name + ": add it to Allowed.");
        var module = Modules.All.Single(m => m.Name == name);

        var exposed = module.Assembly.GetExportedTypes()
            .Where(t => !IsEfMigration(t))
            .Select(t => t.Name)
            .Order()
            .ToList();

        Assert.That(exposed, Is.EqualTo(Allowed[name].Order().ToList()));
    }

    /// <summary>
    /// EF Core generates migration classes (and may generate the model snapshot) as public, and only
    /// EF uses them, so they are not part of a domain's surface. Matched by base type, not by
    /// namespace, so nothing else can hide in a Migrations folder.
    /// </summary>
    private static bool IsEfMigration(Type type) =>
        type.BaseType?.FullName is "Microsoft.EntityFrameworkCore.Migrations.Migration"
            or "Microsoft.EntityFrameworkCore.Infrastructure.ModelSnapshot";
}
