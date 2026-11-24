using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issues 99 and 100 (ACC-R9, CON-R11). A converted domain uses no Entity Framework at run time: the AOT analyzer cannot see the library, so a scan of the domain's own files does.
/// Migrations, tests and the context class itself (the migrate job still uses them) are not scanned. The one allowed line is the registration of the context in the module, which only the migrate job may call.
/// A domain still being converted lists the files that use the library today (its ratchet list): they are not scanned, but each must still use it, so the list can only shrink.
/// </summary>
public sealed partial class RunTimeEfUseTests
{
    private sealed record Converted(string Domain, string? ModuleFile, string? AllowedLine, string? ContextFile, string ProjectFile, string[] Ratchet);

    private static readonly Converted[] ConvertedDomains =
    [
        new("access", "domains/access/api/AccessModule.cs", "services.AddDomainContext<AccessContext>(AccessContext.SchemaName);",
            "domains/access/api/AccessContext.cs", "domains/access/api/Tsr.Access.Api.csproj", []),
        new("content", "domains/content/api/ContentModule.cs", "services.AddDomainContext<ContentContext>(ContentContext.SchemaName);",
            "domains/content/api/ContentContext.cs", "domains/content/api/Tsr.Content.Api.csproj", []),
        // Search owns no table, so it has no context, no migrations and no allowed line: every one of its run-time files is scanned.
        new("search", null, null, null, "domains/search/api/Tsr.Search.Api.csproj", []),
        // Issue 102: identity is being converted. Its ratchet list is the files that use the library today; a file leaves it in the task that removes its last match.
        new("identity", "domains/identity/api/IdentityModule.cs", "services.AddDomainContext<IdentityContext>(IdentityContext.SchemaName);",
            "domains/identity/api/IdentityContext.cs", "domains/identity/api/Tsr.Identity.Api.csproj",
            [
                "domains/identity/api/domain/DeletionRequests.cs",
                "domains/identity/api/features/admin-deletion-complete/AdminDeletionComplete.cs",
                "domains/identity/api/features/admin-deletion-confirmation-sent/AdminDeletionConfirmationSent.cs",
                "domains/identity/api/features/admin-deletion-hold/AdminDeletionHold.cs",
                "domains/identity/api/features/admin-deletion-list/AdminDeletionList.cs",
                "domains/identity/api/features/admin-deletion-raise/AdminDeletionRaise.cs",
                "domains/identity/api/features/deletion-request-cancel/DeletionRequestCancel.cs",
                "domains/identity/api/features/deletion-request-create/DeletionRequestCreate.cs",
                "domains/identity/api/features/deletion-request-get/DeletionRequestGet.cs",
            ]),
    ];

    [GeneratedRegex("""<Using\s[^>]*Include\s*=\s*"[^"]*EntityFramework""")]
    private static partial Regex EfUsing();

    // The context names are listed, never \w+Context, which would hit HttpContext and JsonSerializerContext.
    [GeneratedRegex(@"Microsoft\.EntityFrameworkCore|DbContext|\b(?:AccessContext|ContentContext|IdentityContext)\b|\bEfTransaction\b")]
    private static partial Regex Banned();

    /// <summary>The banned names in a file's text, after each domain's one allowed line is taken out of its own module.</summary>
    internal static IReadOnlyList<string> Hits(string relative, string text)
    {
        var lines = text.Split('\n').Where(line => !ConvertedDomains.Any(domain => relative == domain.ModuleFile && line.Trim() == domain.AllowedLine));
        return Banned().Matches(string.Join('\n', lines)).Select(match => match.Value).Distinct().Order().ToList();
    }

    private static IEnumerable<(string Relative, string Text)> ScannedFiles()
    {
        var root = RouteCatalog.RepoRoot();
        return ConvertedDomains.SelectMany(domain => SqlBoundaryTests.Sources(Path.Combine(root, "domains", domain.Domain, "api"))
            .Select(path => Path.GetRelativePath(root, path).Replace('\\', '/'))
            .Where(relative => !relative.Contains("/Migrations/", StringComparison.Ordinal) && relative != domain.ContextFile && !domain.Ratchet.Contains(relative))
            .Select(relative => (relative, File.ReadAllText(Path.Combine(root, relative)))));
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
    public void Each_file_on_a_ratchet_list_still_uses_entity_framework()
    {
        var root = RouteCatalog.RepoRoot();
        var stale = ConvertedDomains.SelectMany(domain => domain.Ratchet)
            .Where(relative => !File.Exists(Path.Combine(root, relative)) || Hits(relative, File.ReadAllText(Path.Combine(root, relative))).Count == 0);

        Assert.That(stale, Is.Empty, "a file that no longer uses Entity Framework (or is gone) comes off the ratchet list, so the list can only shrink");
    }

    [Test]
    public void The_project_files_add_no_entity_framework_using()
    {
        var root = RouteCatalog.RepoRoot();
        var found = ConvertedDomains.Where(domain => EfUsing().IsMatch(File.ReadAllText(Path.Combine(root, domain.ProjectFile)))).Select(domain => domain.ProjectFile);

        Assert.That(found, Is.Empty, "a <Using Include=...> of an Entity Framework namespace gives every file the library without naming it");
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
    [TestCase("ContentContext db", "ContentContext")]
    [TestCase("IdentityContext db", "IdentityContext")]
    [TestCase("var tx = EfTransaction.Join(db);", "EfTransaction")]
    public void The_scan_reports_each_banned_name(string source, string name) =>
        Assert.That(Hits("domains/access/api/X.cs", source), Does.Contain(name));

    [TestCase("HttpContext context")]
    [TestCase("JsonSerializerContext")]
    public void The_scan_leaves_other_context_names_alone(string source) =>
        Assert.That(Hits("domains/content/api/X.cs", source), Is.Empty);

    [Test]
    public void The_scan_allows_only_each_domains_one_registration_line_and_only_in_its_module()
    {
        Assert.Multiple(() =>
        {
            foreach (var domain in ConvertedDomains.Where(candidate => candidate.ModuleFile is not null && candidate.AllowedLine is not null))
            {
                var module = domain.ModuleFile!;
                var line = "        " + domain.AllowedLine;
                Assert.That(Hits(module, line), Is.Empty, domain.Domain);
                Assert.That(Hits($"domains/{domain.Domain}/api/Other.cs", line), Is.Not.Empty, domain.Domain);
                Assert.That(Hits(module, line + "\nusing Microsoft.EntityFrameworkCore;"), Is.Not.Empty, domain.Domain);
            }

            Assert.That(Hits(ConvertedDomains[0].ModuleFile!, "        " + ConvertedDomains[1].AllowedLine), Is.Not.Empty, "one domain's line is not allowed in another's module");
        });
    }

    [Test]
    public void The_scan_reads_each_converted_domain_and_skips_migrations_tests_the_context_and_the_ratchet_list()
    {
        var files = ScannedFiles().Select(file => file.Relative).ToList();

        Assert.Multiple(() =>
        {
            Assert.That(files, Does.Contain("domains/access/api/Permissions.cs"));
            Assert.That(files, Does.Contain("domains/content/api/domain/ContentFiles.cs"));
            Assert.That(files, Has.None.Contain("/Migrations/"));
            Assert.That(files, Has.None.Contain("/tests/"));
            Assert.That(files, Has.None.EndsWith("AccessContext.cs"));
            Assert.That(files, Has.None.EndsWith("ContentContext.cs"));
            Assert.That(files, Does.Contain("domains/content/api/domain/ContentRefresh.cs"));
            Assert.That(files, Does.Contain("domains/search/api/features/search/Search.cs"));
            Assert.That(files, Does.Contain("domains/identity/api/FirebaseVerifier.cs"));
            Assert.That(files, Has.None.EndsWith("IdentityContext.cs"));
        });
    }
}
