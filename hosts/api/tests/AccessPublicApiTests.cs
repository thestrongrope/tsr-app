using System.Reflection;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issue 99 (ACC-R3). Other domains call <c>access</c> through its public members only, so the conversion off Entity Framework must not move one:
/// every listed signature must still exist (a new member is allowed, a changed or removed one fails). The list was written from today's assembly and holds parameter names,
/// default values, nullability of reference types, static, property accessors and field types, because a caller compiles against each.
/// Migration classes (<c>Initial</c>) are not part of the interface and are left out.
/// </summary>
public sealed class AccessPublicApiTests
{
    internal const BindingFlags Declared = BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;

    private static readonly string[] Today =
    [
        "AccessEngine..ctor()",
        "AccessScopes..ctor(System.Nullable`1[System.Int32] Gender, System.Collections.Generic.IReadOnlyList`1[System.Int32] Assigned, System.Collections.Generic.IReadOnlyList`1[System.Int32] AssignedGenders, System.Collections.Generic.IReadOnlyList`1[System.Int32] Own, System.Collections.Generic.IReadOnlyList`1[System.Int32] Taught, System.Collections.Generic.IReadOnlyList`1[System.Int32] Enrolled)",
        "AccessScopes.Assigned:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "AccessScopes.AssignedGenders:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "AccessScopes.Enrolled:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "AccessScopes.Gender:System.Nullable`1[System.Int32] get,init",
        "AccessScopes.Own:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "AccessScopes.Taught:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "AccessTarget.ClassId:System.Nullable`1[System.Int32] get,init",
        "AccessTarget.Gender:System.Nullable`1[System.Int32] get,init",
        "AccessTarget.IsNone:System.Boolean get",
        "AccessTarget.TeacherGender:System.Nullable`1[System.Int32] get,init",
        "CatalogFromPhp..ctor()",
        "ClassFacts..ctor(System.Int32 Id, System.Int32 Gender, System.String? City, System.String? Country, System.Nullable`1[System.Int32] LevelId, System.Collections.Generic.IReadOnlyList`1[System.String] Tags, System.String Code = \"\", System.String Name = \"\")",
        "ClassFacts.City:System.String? get,init",
        "ClassFacts.Code:System.String get,init",
        "ClassFacts.Country:System.String? get,init",
        "ClassFacts.Gender:System.Int32 get,init",
        "ClassFacts.Id:System.Int32 get,init",
        "ClassFacts.LevelId:System.Nullable`1[System.Int32] get,init",
        "ClassFacts.Name:System.String get,init",
        "ClassFacts.Tags:System.Collections.Generic.IReadOnlyList`1[System.String] get,init",
        "ClassMemberships..ctor(System.Collections.Generic.IReadOnlyList`1[System.Int32] Taught, System.Collections.Generic.IReadOnlyList`1[System.Int32] McqFlagged, System.Collections.Generic.IReadOnlyList`1[System.Int32] Enrolled)",
        "ClassMemberships.Enrolled:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "ClassMemberships.McqFlagged:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "ClassMemberships.Taught:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "IClassScopes.ActiveClassAsync(System.Int32 classId, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[Tsr.Access.Api.ClassFacts]",
        "IClassScopes.ActiveClassesAsync(System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Collections.Generic.IReadOnlyList`1[Tsr.Access.Api.ClassFacts]]",
        "IClassScopes.MembershipsAsync(System.Int32 token, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[Tsr.Access.Api.ClassMemberships]",
        "Permissions.CanAsync(Tsr.Shared.Api.Caller caller, System.String action, Tsr.Access.Api.AccessTarget target, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Boolean]",
        "Permissions.ForUserAsync(Tsr.Shared.Api.Caller caller, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[Tsr.Access.Api.UserAccess]",
        "Permissions.ReachAsync(Tsr.Shared.Api.Caller caller, System.String action, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[Tsr.Access.Api.Reach]",
        "Permissions.RoleIdAsync(Tsr.Shared.Api.Caller caller, System.Threading.CancellationToken ct):System.Threading.Tasks.Task`1[System.Int32]",
        "Reach..ctor(System.Boolean All, System.Nullable`1[System.Int32] Gender, System.Collections.Generic.IReadOnlyList`1[System.Int32] ClassIds, System.Collections.Generic.IReadOnlyList`1[System.Int32]? AssignedOnlyIds, System.Nullable`1[System.Int32] GenderLock, Tsr.Access.Api.SearchReach Search)",
        "Reach.All:System.Boolean get,init",
        "Reach.AssignedOnlyIds:System.Collections.Generic.IReadOnlyList`1[System.Int32]? get,init",
        "Reach.ClassIds:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "Reach.Gender:System.Nullable`1[System.Int32] get,init",
        "Reach.GenderLock:System.Nullable`1[System.Int32] get,init",
        "Reach.Search:Tsr.Access.Api.SearchReach get,init",
        "SearchReach..ctor(System.Boolean All, System.Nullable`1[System.Int32] Gender, System.Collections.Generic.IReadOnlyList`1[System.Int32] ClassIds, System.Nullable`1[System.Int32] Self)",
        "SearchReach.All:System.Boolean get,init",
        "SearchReach.ClassIds:System.Collections.Generic.IReadOnlyList`1[System.Int32] get,init",
        "SearchReach.Gender:System.Nullable`1[System.Int32] get,init",
        "SearchReach.Self:System.Nullable`1[System.Int32] get,init",
        "TYPE AccessEngine",
        "TYPE AccessModule",
        "TYPE AccessScopes",
        "TYPE AccessTarget",
        "TYPE CatalogFromPhp",
        "TYPE ClassFacts",
        "TYPE ClassMemberships",
        "TYPE IClassScopes",
        "TYPE Permissions",
        "TYPE Reach",
        "TYPE SearchReach",
        "TYPE UserAccess",
        "UserAccess..ctor(System.Collections.Generic.IReadOnlyList`1[System.String] Permissions, Tsr.Access.Api.AccessScopes Scopes)",
        "UserAccess.Permissions:System.Collections.Generic.IReadOnlyList`1[System.String] get,init",
        "UserAccess.Scopes:Tsr.Access.Api.AccessScopes get,init",
        "static AccessModule.AddAccess(Microsoft.Extensions.DependencyInjection.IServiceCollection services):Microsoft.Extensions.DependencyInjection.IServiceCollection",
        "static AccessModule.Dependencies:System.Collections.Generic.IReadOnlyList`1[System.String] field,readonly",
        "static AccessModule.MapAccess(Microsoft.AspNetCore.Routing.IEndpointRouteBuilder routes):Microsoft.AspNetCore.Routing.IEndpointRouteBuilder",
        "static AccessModule.UsePermissionsRevision(Microsoft.AspNetCore.Builder.IApplicationBuilder app):Microsoft.AspNetCore.Builder.IApplicationBuilder",
        "static AccessTarget.ForClass(System.Int32 classId):Tsr.Access.Api.AccessTarget",
        "static AccessTarget.ForGender(System.Int32 gender):Tsr.Access.Api.AccessTarget",
        "static AccessTarget.ForTeacherGender(System.Int32 gender):Tsr.Access.Api.AccessTarget",
        "static AccessTarget.None:Tsr.Access.Api.AccessTarget get",
        "static UserAccess.None:Tsr.Access.Api.UserAccess get",
    ];

    internal static readonly string[] SynthesizedByRecords = ["Equals", "GetHashCode", "ToString", "Deconstruct"];

    private static IEnumerable<string> PublicMembers()
    {
        var nullability = new NullabilityInfoContext();
        return typeof(Tsr.Access.Api.Permissions).Assembly.GetExportedTypes()
            .Where(type => type.Name != "Initial")
            .SelectMany(type => Members(type, nullability));
    }

    // Every entry carries what a caller compiles against: parameter names (named arguments), default values, nullability of reference types, static, and a property's accessors.
    // Nullability of generic arguments (IReadOnlyList<string?>) is not read: no access type has one.
    internal static IEnumerable<string> Members(Type type, NullabilityInfoContext nullability)
    {
        var methods = type.GetMethods(Declared)
            .Where(m => !m.IsSpecialName && !m.Name.StartsWith('<') && !SynthesizedByRecords.Contains(m.Name))
            .Select(m => $"{StaticMark(m.IsStatic)}{type.Name}.{m.Name}({Parameters(m.GetParameters(), nullability)}):{Typed(m.ReturnType, nullability.Create(m.ReturnParameter))}");
        var constructors = type.GetConstructors(Declared)
            .Select(c => $"{type.Name}..ctor({Parameters(c.GetParameters(), nullability)})");
        var properties = type.GetProperties(Declared)
            .Where(p => p.Name != "EqualityContract")
            .Select(p => $"{StaticMark(p.GetMethod?.IsStatic == true)}{type.Name}.{p.Name}:{Typed(p.PropertyType, nullability.Create(p))} {Accessors(p)}");
        var fields = type.GetFields(Declared)
            .Select(f => $"{StaticMark(f.IsStatic)}{type.Name}.{f.Name}:{Typed(f.FieldType, nullability.Create(f))} field{(f.IsInitOnly ? ",readonly" : string.Empty)}{(f.IsLiteral ? ",const" : string.Empty)}");
        return methods.Concat(constructors).Concat(properties).Concat(fields).Append("TYPE " + type.Name);
    }

    internal static string StaticMark(bool isStatic) => isStatic ? "static " : string.Empty;

    internal static string Typed(Type type, NullabilityInfo info) =>
        type.ToString() + (info.ReadState == NullabilityState.Nullable && Nullable.GetUnderlyingType(type) is null && !type.IsValueType ? "?" : string.Empty);

    internal static string Parameters(ParameterInfo[] parameters, NullabilityInfoContext nullability) =>
        string.Join(", ", parameters.Select(p => $"{Typed(p.ParameterType, nullability.Create(p))} {p.Name}{(p.HasDefaultValue ? " = " + DefaultOf(p.RawDefaultValue) : string.Empty)}"));

    internal static string DefaultOf(object? value) => value switch
    {
        null => "null",
        string text => "\"" + text + "\"",
        _ => Convert.ToString(value, System.Globalization.CultureInfo.InvariantCulture)!,
    };

    internal static string Accessors(PropertyInfo property)
    {
        if (property.SetMethod is null)
        {
            return "get";
        }

        var init = property.SetMethod.ReturnParameter.GetRequiredCustomModifiers().Any(m => m.FullName == "System.Runtime.CompilerServices.IsExternalInit");
        return init ? "get,init" : "get,set";
    }

    [Test]
    public void Every_public_member_of_access_keeps_its_signature()
    {
        var actual = PublicMembers().ToHashSet(StringComparer.Ordinal);

        var missing = Today.Where(entry => !actual.Contains(entry)).ToList();

        Assert.That(missing, Is.Empty, "a public member of access changed or went: other domains call it");
    }

    [Test]
    public void The_module_lists_no_dependency_today() =>
        Assert.That(Tsr.Access.Api.AccessModule.Dependencies, Is.Empty, "access lists no other domain (AccessModule.Dependencies)");

    [Test]
    public void The_list_covers_the_exported_types_and_reads_each_kind_of_member()
    {
        Assert.Multiple(() =>
        {
            Assert.That(Today, Does.Contain("TYPE Permissions"));
            Assert.That(Today.Count(entry => entry.StartsWith("TYPE ", StringComparison.Ordinal)), Is.EqualTo(PublicMembers().Count(entry => entry.StartsWith("TYPE ", StringComparison.Ordinal))));
            Assert.That(PublicMembers().Any(entry => entry.Contains("..ctor(")), Is.True, "constructors");
            Assert.That(PublicMembers().Any(entry => entry.StartsWith("Permissions.CanAsync(", StringComparison.Ordinal)), Is.True, "methods");
            Assert.That(PublicMembers().Any(entry => entry.StartsWith("UserAccess.Permissions:", StringComparison.Ordinal)), Is.True, "properties");
        });
    }
}
