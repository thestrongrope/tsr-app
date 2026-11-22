using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issue 99 (ACC-R9). A converted domain uses no Entity Framework at run time: the AOT analyzer cannot see the library, so a scan of the domain's own files does.
/// Migrations, tests and the context class itself (the migrate job still uses them) are not scanned. The one allowed line is the registration of the context in <c>AddAccessMigrations</c>, which only the migrate job calls.
/// </summary>
public sealed partial class RunTimeEfUseTests
{
    private static readonly string[] ConvertedDomains = ["access"];

    private const string AllowedFile = "domains/access/api/AccessModule.cs";
    private const string ContextFile = "domains/access/api/AccessContext.cs";
    private const string ProjectFile = "domains/access/api/Tsr.Access.Api.csproj";
    private const string AllowedLine = "services.AddDomainContext<AccessContext>(AccessContext.SchemaName);";

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
            .Where(file => Hits(file.Relative, file.Text).Count > 0)
            .Select(file => $"{file.Relative}: {string.Join(", ", Hits(file.Relative, file.Text))}");

        Assert.That(found, Is.Empty, "a converted domain's run-time code must not name Entity Framework: use the data source and DbTx");
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
        });
    }
}
