using System.Reflection;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issue 102 (IDN-R12, TC-IDN-R12-01). Other domains call <c>identity</c> through its public members only (membership uses <c>UserDirectory</c>, the host the module), so the conversion off Entity Framework must not move one:
/// every listed signature must still exist (a new member is allowed, a changed or removed one fails). The list was written from today's assembly, in the form of <see cref="AccessPublicApiTests"/>.
/// </summary>
public sealed class IdentityPublicApiTests
{
    private static readonly string[] Today =
    [
        "IMemberErasure.EraseAsync(Tsr.Shared.Api.DbTx tx, System.Int32 token, System.Threading.CancellationToken ct):System.Threading.Tasks.Task",
        "IProfileSink.RecordSignInAsync(System.Int32 userId, System.String? name, System.String? picture, System.Boolean isNewMember, System.Threading.CancellationToken ct):System.Threading.Tasks.Task",
        "TYPE IMemberErasure",
        "TYPE IProfileSink",
        "TYPE IdentityCommands",
        "TYPE IdentityModule",
        "TYPE UserDirectory",
        "TYPE UserRef",
        "UserDirectory.ByIdsAsync(System.Collections.Generic.IReadOnlyCollection`1[System.Int32] ids, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Collections.Generic.IReadOnlyList`1[Tsr.Identity.Api.UserRef]]",
        "UserDirectory.ByTokenAsync(System.Int32 token, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Collections.Generic.IReadOnlyList`1[Tsr.Identity.Api.UserRef]]",
        "UserDirectory.ByTokensAsync(System.Collections.Generic.IReadOnlyCollection`1[System.Int32] tokens, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Collections.Generic.IReadOnlyList`1[Tsr.Identity.Api.UserRef]]",
        "UserRef..ctor(System.Int32 Id, System.Int32 Token, System.String? Email)",
        "UserRef.Email:System.String? get,init",
        "UserRef.Id:System.Int32 get,init",
        "UserRef.Token:System.Int32 get,init",
        "static IdentityCommands.ChangeEmailAsync(Tsr.Shared.Api.DbTx tx, System.Int32 token, System.String email, System.TimeProvider clock, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Boolean]",
        "static IdentityCommands.CreateMemberAsync(Tsr.Shared.Api.DbTx tx, System.TimeProvider clock, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Int32]",
        "static IdentityCommands.EmailTakenAsync(Tsr.Shared.Api.DbTx tx, System.Int32 token, System.String email, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Boolean]",
        "static IdentityModule.AddIdentity(Microsoft.Extensions.DependencyInjection.IServiceCollection services, Microsoft.Extensions.Hosting.IHostEnvironment env, Microsoft.Extensions.Configuration.IConfiguration configuration):Microsoft.Extensions.DependencyInjection.IServiceCollection",
        "static IdentityModule.AddIdentityTables(Microsoft.Extensions.DependencyInjection.IServiceCollection services):Microsoft.Extensions.DependencyInjection.IServiceCollection",
        "static IdentityModule.Dependencies:System.Collections.Generic.IReadOnlyList`1[System.String] field,readonly",
        "static IdentityModule.MapIdentity(Microsoft.AspNetCore.Routing.IEndpointRouteBuilder routes):Microsoft.AspNetCore.Routing.IEndpointRouteBuilder",
        "static IdentityModule.UseIdentity(Microsoft.AspNetCore.Builder.IApplicationBuilder app):Microsoft.AspNetCore.Builder.IApplicationBuilder",
        "static UserDirectory.MaxBatch:System.Int32 field,const",
        "static UserDirectory.MaxMatches:System.Int32 field,const",
        "static UserDirectory.MaxTokenMatches:System.Int32 field,const",
    ];

    private static IEnumerable<string> PublicMembers()
    {
        var nullability = new NullabilityInfoContext();
        return typeof(Tsr.Identity.Api.IdentityModule).Assembly.GetExportedTypes()
            .Where(type => type.BaseType?.Name is not ("Migration" or "ModelSnapshot" or "DbContext"))
            .SelectMany(type => AccessPublicApiTests.Members(type, nullability));
    }

    [Test]
    public void Every_public_member_of_identity_keeps_its_signature()
    {
        var actual = PublicMembers().ToHashSet(StringComparer.Ordinal);

        var missing = Today.Where(entry => !actual.Contains(entry)).ToList();

        Assert.That(missing, Is.Empty, "a public member of identity changed or went: other domains call it");
    }

    [Test]
    public void The_list_covers_the_exported_types_and_the_limits_keep_their_values()
    {
        Assert.Multiple(() =>
        {
            Assert.That(Today.Count(entry => entry.StartsWith("TYPE ", StringComparison.Ordinal)), Is.EqualTo(PublicMembers().Count(entry => entry.StartsWith("TYPE ", StringComparison.Ordinal))));
            Assert.That(Tsr.Identity.Api.UserDirectory.MaxBatch, Is.EqualTo(500));
            Assert.That(Tsr.Identity.Api.UserDirectory.MaxMatches, Is.EqualTo(50));
            Assert.That(Tsr.Identity.Api.UserDirectory.MaxTokenMatches, Is.EqualTo(2000));
        });
    }
}
