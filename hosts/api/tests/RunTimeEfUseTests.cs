using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issue 99 (ACC-R9). A converted domain uses no Entity Framework at run time: the AOT analyzer cannot see the library, so a scan of the domain's own files does.
/// Migrations, tests and the context class itself (the migrate job still uses them) are not scanned. The one allowed line is the registration of the context for the migrate job.
/// <see cref="NotConverted"/> is a ratchet: files of a converted domain that still use the library. A file on it that no longer uses it must be removed from it, so the list only shrinks.
/// </summary>
public sealed partial class RunTimeEfUseTests
{
    private static readonly string[] ConvertedDomains = ["access"];

    private const string AllowedFile = "domains/access/api/AccessModule.cs";
    private const string ContextFile = "domains/access/api/AccessContext.cs";
    private const string ProjectFile = "domains/access/api/Tsr.Access.Api.csproj";
    private const string AllowedLine = "services.AddDomainContext<AccessContext>(AccessContext.SchemaName);";

    /// <summary>The access files not converted yet: the 9 that hold EF calls, the 6 read slices that take the context, and the module. Each conversion task removes its files; task 13 removes the list.</summary>
    private static readonly string[] NotConverted =
    [
        "domains/access/api/domain/AdminMembers.cs",
        "domains/access/api/domain/ClassAccessStore.cs",
        "domains/access/api/domain/MemberLock.cs",
        "domains/access/api/domain/PermissionGrants.cs",
        "domains/access/api/features/admin-permission-grant/AdminPermissionGrant.cs",
        "domains/access/api/features/admin-permission-member/AdminPermissionMember.cs",
        "domains/access/api/features/admin-permission-members/AdminPermissionMembers.cs",
        "domains/access/api/features/admin-permission-revoke/AdminPermissionRevoke.cs",
        "domains/access/api/features/class-access-grant/ClassAccessGrant.cs",
        "domains/access/api/features/class-access-member/ClassAccessMember.cs",
        "domains/access/api/features/class-access-members/ClassAccessMembers.cs",
        "domains/access/api/features/class-access-options/ClassAccessOptions.cs",
        "domains/access/api/features/class-access-preview/ClassAccessPreview.cs",
        "domains/access/api/features/class-access-revoke/ClassAccessRevoke.cs",
    ];

    [GeneratedRegex("""<Using\s[^>]*Include\s*=\s*"[^"]*EntityFramework""")]
    private static partial Regex EfUsing();

    [GeneratedRegex(@"Microsoft\.EntityFrameworkCore|DbContext|\b(?:Access)Context\b|\bEfTransaction\b")]
    private static partial Regex Banned();

    /// <summary>The banned names in a file's text, after the one allowed line is taken out of the allowed file.</summary>
    internal static IReadOnlyList<string> Hits(string relative, string text)
    {
        var lines = text.Split('\n').Where(line => !(relative == AllowedFile && line.Trim() == AllowedLine));
        return Banned().Matches(string.Join('\n', lines)).Select(match => match.Value).Distinct().Order().ToList();
    }

    private static IEnumerable<(string Relative, string Text)> ScannedFiles()
    {
        var root = RouteCatalog.RepoRoot();
        return ConvertedDomains
            .SelectMany(domain => SqlBoundaryTests.Sources(Path.Combine(root, "domains", domain, "api")))
            .Select(path => (Relative: Path.GetRelativePath(root, path).Replace('\\', '/'), Path: path))
            .Where(file => !file.Relative.Contains("/Migrations/", StringComparison.Ordinal) && file.Relative != ContextFile)
            .Select(file => (file.Relative, File.ReadAllText(file.Path)));
    }

    [Test]
    public void A_converted_domain_has_no_entity_framework_at_run_time()
    {
        var found = ScannedFiles()
            .Where(file => !NotConverted.Contains(file.Relative) && Hits(file.Relative, file.Text).Count > 0)
            .Select(file => $"{file.Relative}: {string.Join(", ", Hits(file.Relative, file.Text))}");

        Assert.That(found, Is.Empty, "a converted domain's run-time code must not name Entity Framework: use the data source and DbTx");
    }

    [Test]
    public void Every_file_on_the_not_converted_list_exists_and_still_uses_entity_framework()
    {
        var scanned = ScannedFiles().ToDictionary(file => file.Relative, file => file.Text);

        var stale = NotConverted.Where(file => !scanned.TryGetValue(file, out var text) || Hits(file, text).Count == 0);

        Assert.That(stale, Is.Empty, "the file is converted (or gone): remove it from NotConverted so the check covers it");
    }

    [Test]
    public void The_project_file_adds_no_entity_framework_using()
    {
        var project = File.ReadAllText(Path.Combine(RouteCatalog.RepoRoot(), ProjectFile));

        Assert.That(EfUsing().IsMatch(project), Is.False, "a <Using Include=...> of an Entity Framework namespace gives every file the library without naming it");
    }

    [TestCase("""<Using Include="Microsoft.EntityFrameworkCore" />""", true)]
    [TestCase("""<Using Include="Microsoft.EntityFrameworkCore.Infrastructure" Alias="X" />""", true)]
    [TestCase("""<Using Include = "Npgsql.EntityFrameworkCore.PostgreSQL" />""", true)]
    [TestCase("""<Using Include="System.Text" />""", false)]
    public void The_using_scan_reads_each_form(string xml, bool hit) =>
        Assert.That(EfUsing().IsMatch(xml), Is.EqualTo(hit));

    [TestCase("using Microsoft.EntityFrameworkCore;", "Microsoft.EntityFrameworkCore")]
    [TestCase("class A(TsrDbContext c);", "DbContext")]
    [TestCase("AccessContext db", "AccessContext")]
    [TestCase("var tx = EfTransaction.Join(db);", "EfTransaction")]
    public void The_scan_reports_each_banned_name(string source, string name) =>
        Assert.That(Hits("domains/access/api/X.cs", source), Does.Contain(name));

    [Test]
    public void The_scan_allows_only_the_one_registration_line_and_only_in_the_module()
    {
        var line = "        " + AllowedLine;

        Assert.Multiple(() =>
        {
            Assert.That(Hits(AllowedFile, line), Is.Empty);
            Assert.That(Hits("domains/access/api/Other.cs", line), Is.Not.Empty);
            Assert.That(Hits(AllowedFile, line + "\nusing Microsoft.EntityFrameworkCore;"), Is.Not.Empty);
        });
    }

    [Test]
    public void The_scan_reads_the_access_files_and_skips_migrations_tests_and_the_context()
    {
        var files = ScannedFiles().Select(file => file.Relative).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(files, Does.Contain("domains/access/api/Permissions.cs"));
            Assert.That(files, Has.None.Contain("/Migrations/"));
            Assert.That(files, Has.None.Contain("/tests/"));
            Assert.That(files, Has.None.EndsWith("AccessContext.cs"));
            Assert.That(NotConverted, Has.Length.EqualTo(14));
        });
    }
}
