using System.Reflection;
using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issue 98. A published command or port runs on the caller's transaction (<c>DbTx</c>), never on Entity Framework's context, so a converted domain can call
/// it without the old library (CMD-R10). An unconverted caller reaches a command only through the one bridge, <c>EfTransaction.Join</c> (CMD-R11).
/// </summary>
public sealed partial class PublishedCommandTests
{
    /// <summary>
    /// The entry points that still take an Entity Framework type, by full signature "Type.Method(ParameterType, ...)" (a constructor is "Type..ctor(...)"). The list only shrinks: a task that converts
    /// a command takes it off, and the test fails when a listed entry no longer takes such a type, or an unlisted one does (a new overload of a listed method is a new entry). Part B of issue 98 empties it.
    /// </summary>
    private static readonly string[] NotConvertedYet =
    [
        "IdentityCommands.ChangeEmailAsync(DbContext, Int32, String, TimeProvider, CancellationToken)",
        "IdentityCommands.CreateMemberAsync(DbContext, TimeProvider, CancellationToken)",
        "IdentityCommands.EmailTakenAsync(DbContext, Int32, String, CancellationToken)",
        "IMemberErasure.EraseAsync(DbContext, Int32, CancellationToken)",
        "MembershipCommands.ChangeContactAsync(DbContext, Int32, String, String, TimeProvider, CancellationToken)",
        "MembershipCommands.CreateProfileAsync(DbContext, Int32, String, String, String, TimeProvider, CancellationToken)",
        "MembershipCommands.EraseMemberAsync(DbContext, Int32, CancellationToken)",
        "MembershipCommands.RecordAcceptedRegistrationAsync(DbContext, Int32, Int32, CancellationToken)",
        "PlatformCommands.ClaimMessagesAsync(DbContext, String, Int32, DateTimeOffset, CancellationToken)",
        "PlatformCommands.MarkDeadAsync(DbContext, Int64, Int32, String, CancellationToken)",
        "PlatformCommands.MarkFailedAsync(DbContext, Int64, Int32, String, DateTimeOffset, CancellationToken)",
        "PlatformCommands.MarkSentAsync(DbContext, Int64, Int32, DateTimeOffset, CancellationToken)",
        "PlatformCommands.RecordAdminAccessAsync(DbContext, HttpContext, Int32, Int32, Int32, CancellationToken)",
        "PlatformCommands.ReleaseMessageAsync(DbContext, Int64, Int32, CancellationToken)",
    ];

    [Test]
    public void No_public_domain_method_or_constructor_takes_an_entity_framework_type()
    {
        var found = EfEntryPoints().ToList();

        var added = found.Except(NotConvertedYet).Order().ToList();
        var stale = NotConvertedYet.Except(found).Order().ToList();
        Assert.Multiple(() =>
        {
            Assert.That(string.Join("\n", added), Is.Empty, "a public domain method or constructor takes an Entity Framework type: take a DbTx (the caller's transaction) instead");
            Assert.That(stale, Is.Empty, "this entry no longer takes an Entity Framework type: remove it from NotConvertedYet");
        });
    }

    [Test]
    public void The_list_of_entries_still_allowed_has_14_entries()
    {
        Assert.That(NotConvertedYet, Has.Length.EqualTo(14));
    }

    private const BindingFlags Declared = BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly;

    /// <summary>The signature of every public method and constructor, static or not, of every exported type of every module except the module class, that has an Entity Framework parameter.</summary>
    private static IEnumerable<string> EfEntryPoints() =>
        Modules.All.SelectMany(module => module.Assembly.GetExportedTypes()
            .Where(type => type != module.GetType())
            .SelectMany(type => Entries(type)))
            .Distinct();

    private static IEnumerable<string> Entries(Type type)
    {
        var methods = type.GetMethods(Declared).Where(method => !method.IsSpecialName).Select(method => (method.Name, method.GetParameters()));
        var constructors = type.GetConstructors(Declared).Select(constructor => (constructor.Name, constructor.GetParameters()));
        return methods.Concat(constructors)
            .Where(entry => entry.Item2.Any(p => TakesEfType(p.ParameterType)))
            .Select(entry => Signature(type.Name, entry.Name, entry.Item2.Select(p => p.ParameterType)));
    }

    /// <summary>"Type.Member(ParameterType, ...)": the full signature, so a new overload is a different entry.</summary>
    internal static string Signature(string typeName, string member, IEnumerable<Type> parameterTypes) =>
        $"{typeName}.{member}({string.Join(", ", parameterTypes.Select(TypeName))})";

    private static string TypeName(Type type)
    {
        if (type.IsByRef)
        {
            return TypeName(type.GetElementType()!) + "&";
        }

        if (type.IsArray)
        {
            return TypeName(type.GetElementType()!) + "[]";
        }

        if (!type.IsGenericType)
        {
            return type.Name;
        }

        var name = type.Name[..type.Name.IndexOf('`', StringComparison.Ordinal)];
        return $"{name}<{string.Join(", ", type.GetGenericArguments().Select(TypeName))}>";
    }

    [Test]
    public void A_signature_names_the_type_method_and_every_parameter_type()
    {
        Assert.Multiple(() =>
        {
            Assert.That(Signature("T", "M", [typeof(int), typeof(string)]), Is.EqualTo("T.M(Int32, String)"));
            Assert.That(Signature("T", "M", []), Is.EqualTo("T.M()"));
            Assert.That(Signature("T", ".ctor", [typeof(Microsoft.EntityFrameworkCore.DbContext)]), Is.EqualTo("T..ctor(DbContext)"));
            Assert.That(Signature("T", "M", [typeof(IReadOnlyList<string[]>)]), Is.EqualTo("T.M(IReadOnlyList<String[]>)"));
        });
    }

    [Test]
    public void An_overload_of_a_listed_method_has_a_different_signature()
    {
        var listed = Signature("PlatformCommands", "MarkSentAsync", [typeof(int)]);
        var overload = Signature("PlatformCommands", "MarkSentAsync", [typeof(int), typeof(Microsoft.EntityFrameworkCore.DbContext)]);

        Assert.That(overload, Is.Not.EqualTo(listed));
    }

    private sealed class WithConstructor(Microsoft.EntityFrameworkCore.DbContext context)
    {
        public Microsoft.EntityFrameworkCore.DbContext Context { get; } = context;
    }

    [Test]
    public void A_constructor_with_an_entity_framework_parameter_is_reported()
    {
        var constructor = typeof(WithConstructor).GetConstructors(Declared).Single();

        Assert.That(constructor.GetParameters().Any(p => TakesEfType(p.ParameterType)), Is.True);
    }

    /// <summary>A parameter type that is, wraps (array, reference, generic argument) or derives from a type of an Entity Framework namespace.</summary>
    internal static bool TakesEfType(Type type)
    {
        if (type.HasElementType)
        {
            return TakesEfType(type.GetElementType()!);
        }

        if (type.IsGenericType && type.GetGenericArguments().Any(TakesEfType))
        {
            return true;
        }

        for (var t = type; t is not null; t = t.BaseType)
        {
            if (t.Namespace is { } ns && (ns == "Microsoft.EntityFrameworkCore" || ns.StartsWith("Microsoft.EntityFrameworkCore.", StringComparison.Ordinal)))
            {
                return true;
            }
        }

        return false;
    }

    private sealed class Derived : Microsoft.EntityFrameworkCore.DbContext;

    [Test]
    public void The_type_check_sees_through_wrappers_and_subclasses()
    {
        Assert.Multiple(() =>
        {
            Assert.That(TakesEfType(typeof(Microsoft.EntityFrameworkCore.DbContext)), Is.True);
            Assert.That(TakesEfType(typeof(Derived)), Is.True, "a subclass of DbContext");
            Assert.That(TakesEfType(typeof(Microsoft.EntityFrameworkCore.DbContext[])), Is.True, "an array");
            Assert.That(TakesEfType(typeof(IEnumerable<Microsoft.EntityFrameworkCore.DbContext>)), Is.True, "a generic argument");
            Assert.That(TakesEfType(typeof(Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction)), Is.True, "a nested namespace");
            Assert.That(TakesEfType(typeof(Tsr.Shared.Api.DbTx)), Is.False);
            Assert.That(TakesEfType(typeof(IReadOnlyCollection<string>)), Is.False);
            Assert.That(TakesEfType(typeof(int[])), Is.False);
        });
    }

    [GeneratedRegex(@"\bDbTx\s*\.\s*Join\s*\(")]
    private static partial Regex JoinCall();

    [TestCase("var tx = DbTx.Join(connection, transaction);")]
    [TestCase("var tx = Tsr.Shared.Api.DbTx.Join(c, t);")]
    [TestCase("var tx = DbTx . Join (c, t);")]
    [TestCase("var tx = DbTx\n    .Join(c, t);")]
    public void A_direct_join_is_reported(string source) =>
        Assert.That(JoinCall().IsMatch(source), Is.True);

    [TestCase("var tx = EfTransaction.Join(db);")]
    [TestCase("var tx = await source.BeginAsync(ct);")]
    [TestCase("var path = Path.Join(a, b);")]
    [TestCase("var tx = MyDbTx.Join(a, b);")]
    public void The_bridge_and_other_joins_are_not_reported(string source) =>
        Assert.That(JoinCall().IsMatch(source), Is.False);

    [Test]
    public void Only_the_bridge_calls_DbTx_Join()
    {
        var root = RouteCatalog.RepoRoot();
        var found = SqlCitextCastTests.ScannedDirectories()
            .SelectMany(SqlBoundaryTests.Sources)
            .Select(file => Path.GetRelativePath(root, file).Replace('\\', '/'))
            .Where(relative => relative.StartsWith("domains/", StringComparison.Ordinal) || relative.StartsWith("hosts/", StringComparison.Ordinal))
            .Where(relative => JoinCall().IsMatch(File.ReadAllText(Path.Combine(root, relative))));

        Assert.That(found, Is.Empty, "hand a command the caller's transaction with EfTransaction.Join(db) (unconverted caller) or its own DbTx (converted caller)");
    }
}
