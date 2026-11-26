using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issue 100 (CON-R10). The host calls <c>content</c> through the public members of its module only, so the conversion off Entity Framework must not move one:
/// every listed signature must still exist (a new member is allowed, a changed or removed one fails). The list was written from today's assembly, in the form of <see cref="AccessPublicApiTests"/>.
/// </summary>
public sealed class ContentPublicApiTests
{
    private static readonly string[] Today =
    [
        "TYPE ContentModule",
        "static ContentModule.AddContent(Microsoft.Extensions.DependencyInjection.IServiceCollection services):Microsoft.Extensions.DependencyInjection.IServiceCollection",
        "static ContentModule.AddContentWorkers(Microsoft.Extensions.DependencyInjection.IServiceCollection services, System.Collections.Generic.IReadOnlySet`1[System.String] enabled):Microsoft.Extensions.DependencyInjection.IServiceCollection",
        "static ContentModule.Dependencies:System.Collections.Generic.IReadOnlyList`1[System.String] field,readonly",
        "static ContentModule.LoadContentAsync(System.IServiceProvider services, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Boolean]",
        "static ContentModule.MapContent(Microsoft.AspNetCore.Routing.IEndpointRouteBuilder routes):Microsoft.AspNetCore.Routing.IEndpointRouteBuilder",
        "static ContentModule.WorkerNames:System.Collections.Generic.IReadOnlyList`1[System.String] field,readonly",
    ];

    private static IEnumerable<string> PublicMembers()
    {
        var nullability = new System.Reflection.NullabilityInfoContext();
        return typeof(Tsr.Content.Api.ContentModule).Assembly.GetExportedTypes()
            .Where(type => type.Namespace is null || !type.Namespace.EndsWith("Migrations", StringComparison.Ordinal))
            .SelectMany(type => AccessPublicApiTests.Members(type, nullability));
    }

    [Test]
    public void Every_public_member_of_content_keeps_its_signature()
    {
        var actual = PublicMembers().ToHashSet(StringComparer.Ordinal);

        var missing = Today.Where(entry => !actual.Contains(entry)).ToList();

        Assert.That(missing, Is.Empty, "a public member of content changed or went: the host calls it");
    }

    [Test]
    public void The_module_lists_no_dependency_today() =>
        Assert.That(Tsr.Content.Api.ContentModule.Dependencies, Is.Empty, "content lists no other domain (ContentModule.Dependencies)");

    [Test]
    public void The_list_covers_the_exported_types()
    {
        var types = PublicMembers().Where(entry => entry.StartsWith("TYPE ", StringComparison.Ordinal)).ToList();

        Assert.That(types, Is.EquivalentTo(Today.Where(entry => entry.StartsWith("TYPE ", StringComparison.Ordinal))));
    }
}
