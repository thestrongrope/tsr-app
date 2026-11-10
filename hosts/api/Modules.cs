using System.Reflection;
using Tsr.Access.Api;
using Tsr.Content.Api;
using Tsr.Identity.Api;
using Tsr.Platform.Api;

namespace Tsr.Host.Api;

/// <summary>One domain module as this host sees it: its name, its listed dependencies, its code.</summary>
public sealed record ModuleInfo(string Name, IReadOnlyList<string> Dependencies, Assembly Assembly);

/// <summary>
/// Every domain module this host loads. Adding a domain: add it here and in Program.cs. The
/// boundary tests (tests/) read this list to enforce domains/CLAUDE.md rule 7: a module references only shared
/// and the modules it lists, and starts with only those registered.
/// </summary>
public static class Modules
{
    public static readonly IReadOnlyList<ModuleInfo> All =
    [
        new("identity", IdentityModule.Dependencies, typeof(IdentityModule).Assembly),
        new("access", AccessModule.Dependencies, typeof(AccessModule).Assembly),
        new("platform", PlatformModule.Dependencies, typeof(PlatformModule).Assembly),
        new("content", ContentModule.Dependencies, typeof(ContentModule).Assembly),
    ];
}
