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
    /// The entry points that still take an Entity Framework type: "Type.Method". The list only shrinks: a task that converts a command takes it off, and the test
    /// fails when a listed method no longer takes such a type, or an unlisted one does. Part B of issue 98 empties it.
    /// </summary>
    private static readonly string[] NotConvertedYet =
    [
        "IdentityCommands.ChangeEmailAsync",
        "IdentityCommands.CreateMemberAsync",
        "IdentityCommands.EmailTakenAsync",
        "IMemberErasure.EraseAsync",
        "MembershipCommands.ChangeContactAsync",
        "MembershipCommands.CreateProfileAsync",
        "MembershipCommands.EraseMemberAsync",
        "MembershipCommands.RecordAcceptedRegistrationAsync",
        "NotificationsCommands.AnnounceAsync",
        "NotificationsCommands.AnnounceCountedAsync",
        "NotificationsCommands.LastNudgeAsync",
        "NotificationsErasure.EraseDevicesAsync",
        "NotificationsErasure.EraseEventSettingsAsync",
        "PlatformCommands.ClaimMessagesAsync",
        "PlatformCommands.EraseFeedbackAsync",
        "PlatformCommands.MarkDeadAsync",
        "PlatformCommands.MarkFailedAsync",
        "PlatformCommands.MarkSentAsync",
        "PlatformCommands.QueueMessagesAsync",
        "PlatformCommands.RecordAdminAccessAsync",
        "PlatformCommands.RedactRecipientsAsync",
        "PlatformCommands.ReleaseMessageAsync",
    ];

    [Test]
    public void No_public_domain_method_takes_an_entity_framework_type()
    {
        var found = EfEntryPoints().ToList();

        var added = found.Except(NotConvertedYet).Order().ToList();
        var stale = NotConvertedYet.Except(found).Order().ToList();
        Assert.Multiple(() =>
        {
            Assert.That(added, Is.Empty, "a public domain method takes an Entity Framework type: take a DbTx (the caller's transaction) instead");
            Assert.That(stale, Is.Empty, "this method no longer takes an Entity Framework type: remove it from NotConvertedYet");
        });
    }

    /// <summary>"Type.Method" for every public method, static or not, of every exported type of every module except the module class, that has an Entity Framework parameter.</summary>
    private static IEnumerable<string> EfEntryPoints() =>
        Modules.All.SelectMany(module => module.Assembly.GetExportedTypes()
            .Where(type => type != module.GetType())
            .SelectMany(type => type
                .GetMethods(BindingFlags.Public | BindingFlags.Instance | BindingFlags.Static | BindingFlags.DeclaredOnly)
                .Where(method => !method.IsSpecialName && method.GetParameters().Any(p => TakesEfType(p.ParameterType)))
                .Select(method => type.Name + "." + method.Name)))
            .Distinct();

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
