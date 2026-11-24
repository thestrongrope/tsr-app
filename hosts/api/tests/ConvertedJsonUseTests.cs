using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issues 99 and 100 (ACC-R9, CON-R13). The test host runs under JIT, so a reflection write in a converted domain would pass every test and fail only in the native build.
/// A scan of each converted domain's files finds it: every statement that serialises must pass a type info of the domain's source-generated context (<c>AccessJson.</c>, <c>ContentJson.</c>),
/// and <c>Results.Ok(value)</c> and <c>TypedResults.Ok(value)</c> always count, because they take no type info. Tests are not scanned.
/// A domain still being converted lists the files that write by reflection today (its ratchet list): they are not scanned, but each must still hit, so the list can only shrink.
/// </summary>
public sealed partial class ConvertedJsonUseTests
{
    private sealed record Converted(string Domain, string Prefix, string[] Ratchet);

    private static readonly Converted[] ConvertedDomains =
    [
        new("access", "AccessJson.", []),
        new("content", "ContentJson.", []),
        new("search", "SearchJson.", []),
        new("identity", "IdentityJson.", []),
        new("notifications", "NotificationsJson.", []),
        new("platform", "PlatformJson.", []),
        new("membership", "MembershipJson.", []),
        new("assessment", "AssessmentJson.", []),
        new("classes", "ClassesJson.", []),
    ];

    // The call, up to the end of its statement: a statement may run over several lines, and its type info is often on the last.
    [GeneratedRegex(@"(?:Results\.Json|TypedResults\.Json|JsonSerializer\.Serialize|JsonSerializer\.Deserialize|WriteAsJsonAsync|ReadFromJsonAsync)\s*(?:<[^;(]*>)?\s*\([^;]*;")]
    private static partial Regex Serialising();

    // Ok has no type-info overload, so an Ok with an argument is a reflection write whatever else the statement names.
    [GeneratedRegex(@"(?:Results|TypedResults)\.Ok\s*(?:<[^;(]*>)?\s*\(\s*[^)\s][^;]*;")]
    private static partial Regex OkWithValue();

    /// <summary>The serialising statements of a file's text that do not name a type info with the domain's <paramref name="prefix"/>.</summary>
    internal static IReadOnlyList<string> Hits(string text, string prefix) =>
        Serialising().Matches(text).Select(match => match.Value).Where(statement => !statement.Contains(prefix, StringComparison.Ordinal))
            .Concat(OkWithValue().Matches(text).Select(match => match.Value))
            .ToList();

    // The statement that builds the index client's settings, up to its end: the source serializer may be on a later line.
    [GeneratedRegex(@"new\s+ElasticsearchClientSettings\s*\([^;]*;")]
    private static partial Regex IndexClientSettings();

    // A source serializer alone is not enough: one built without the generated context still reads by reflection.
    [GeneratedRegex(@"sourceSerializer:[^;]*SearchJson\.Default")]
    private static partial Regex GeneratedReader();

    /// <summary>The statements of a file's text that build the index client's settings without a <c>sourceSerializer:</c> that is given the generated context.</summary>
    internal static IReadOnlyList<string> IndexClientsWithoutReader(string text) =>
        IndexClientSettings().Matches(text).Select(match => match.Value).Where(statement => !GeneratedReader().IsMatch(statement)).ToList();

    private static IEnumerable<string> Files(Converted domain, string root) =>
        SqlBoundaryTests.Sources(Path.Combine(root, "domains", domain.Domain, "api"))
            .Where(path => !path.Contains("/Migrations/", StringComparison.Ordinal))
            .Select(path => Path.GetRelativePath(root, path).Replace('\\', '/'));

    [Test]
    public void Every_serialising_statement_uses_the_generated_context()
    {
        var root = RouteCatalog.RepoRoot();
        var found = ConvertedDomains.SelectMany(domain => Files(domain, root)
            .Where(relative => !domain.Ratchet.Contains(relative))
            .SelectMany(relative => Hits(File.ReadAllText(Path.Combine(root, relative)), domain.Prefix).Select(statement => $"{relative}: {statement}")));

        Assert.That(found, Is.Empty, "pass a type info of the domain's Json context (for example AccessJson.Answers.<Type>) so the write needs no reflection");
    }

    [Test]
    public void Each_file_on_a_ratchet_list_still_writes_by_reflection()
    {
        var root = RouteCatalog.RepoRoot();
        var stale = ConvertedDomains.SelectMany(domain => domain.Ratchet.Select(relative => (relative, domain.Prefix)))
            .Where(entry => !File.Exists(Path.Combine(root, entry.relative)) || Hits(File.ReadAllText(Path.Combine(root, entry.relative)), entry.Prefix).Count == 0)
            .Select(entry => entry.relative);

        Assert.That(stale, Is.Empty, "a file that no longer writes by reflection (or is gone) comes off the ratchet list, so the list can only shrink");
    }

    [Test]
    public void The_scan_reads_each_converted_domain()
    {
        var root = RouteCatalog.RepoRoot();

        Assert.Multiple(() =>
        {
            Assert.That(Files(ConvertedDomains[0], root), Does.Contain("domains/access/api/Permissions.cs"));
            Assert.That(Files(ConvertedDomains[1], root), Does.Contain("domains/content/api/features/holy-quran/HolyQuran.cs"));
            Assert.That(Files(ConvertedDomains[2], root), Does.Contain("domains/search/api/features/search/Search.cs"));
            Assert.That(Files(ConvertedDomains[3], root), Does.Contain("domains/identity/api/features/deletion-request-get/DeletionRequestGet.cs"));
        });
    }

    [TestCase("return Results.Json(view);")]
    [TestCase("return TypedResults.Json(view);")]
    [TestCase("var s = JsonSerializer.Serialize(view);")]
    [TestCase("var v = JsonSerializer.Deserialize<View>(text);")]
    [TestCase("await context.Response.WriteAsJsonAsync(view, ct);")]
    [TestCase("var v = await request.ReadFromJsonAsync<View>(ct);")]
    [TestCase("return Results.Json(new View(1,\n    2), statusCode: 409);")]
    [TestCase("return Results.Ok(view);")]
    [TestCase("return TypedResults.Ok(view);")]
    [TestCase("return Results.Ok<View>(view);")]
    [TestCase("return Results.Ok(view, AccessJson.Answers.View);")]
    public void The_scan_reports_each_reflection_form(string source) =>
        Assert.That(Hits(source, "AccessJson."), Has.Count.EqualTo(1));

    [TestCase("return Results.Ok();")]
    [TestCase("return TypedResults.Ok();")]
    [TestCase("return Results.Json(view, AccessJson.Answers.GrantMemberView);")]
    [TestCase("return Results.Json(new View(1,\n    2), AccessJson.Answers.View, statusCode: 409);")]
    [TestCase("var s = JsonSerializer.Serialize(view, AccessJson.Default.PermissionGranted);")]
    [TestCase("return x is null ? Problem.Detail(404, \"no\") : Results.Json(view, AccessJson.Answers.GrantMemberView);")]
    public void The_scan_passes_a_statement_with_an_access_type_info(string source) =>
        Assert.That(Hits(source, "AccessJson."), Is.Empty);

    [Test]
    public void A_domain_passes_only_its_own_type_info() =>
        Assert.Multiple(() =>
        {
            Assert.That(Hits("return Results.Json(view, ContentJson.Answers.SurahList);", "ContentJson."), Is.Empty);
            Assert.That(Hits("return Results.Json(view, AccessJson.Answers.View);", "ContentJson."), Has.Count.EqualTo(1));
        });

    // Issue 101 (SRCH-R6). Without the generated reader the client reads a found document by reflection: a document type missing from SearchJson then passes every test under JIT and answers "unavailable" for every kind in the native build (measured in the issue's native spike).
    [Test]
    public void Every_index_client_is_built_with_the_generated_document_reader()
    {
        var root = RouteCatalog.RepoRoot();
        var files = SqlBoundaryTests.Sources(Path.Combine(root, "domains"))
            .Select(path => (Relative: Path.GetRelativePath(root, path).Replace('\\', '/'), Text: File.ReadAllText(path)))
            .ToList();

        var built = files.SelectMany(file => IndexClientSettings().Matches(file.Text)).Count();
        var without = files.SelectMany(file => IndexClientsWithoutReader(file.Text).Select(statement => $"{file.Relative}: {statement}"));

        Assert.Multiple(() =>
        {
            Assert.That(built, Is.GreaterThan(0), "the scan must find the index client's settings");
            Assert.That(without, Is.Empty, "pass sourceSerializer: with the generated context (SearchJson.Default) so a found document is read without reflection");
        });
    }

    [TestCase("var s = new ElasticsearchClientSettings(url).RequestTimeout(t);", 1)]
    [TestCase("var s = new ElasticsearchClientSettings(new SingleNodePool(url))\n    .RequestTimeout(t);", 1)]
    [TestCase("var s = new ElasticsearchClientSettings(new SingleNodePool(url), sourceSerializer: (_, s) => new DefaultSourceSerializer(s, SearchJson.Default, _ => { }))\n    .RequestTimeout(t);", 0)]
    [TestCase("var s = new ElasticsearchClientSettings(\n    new SingleNodePool(url),\n    sourceSerializer: (_, s) => new DefaultSourceSerializer(s, SearchJson.Default, _ => { }));", 0)]
    [TestCase("var s = new ElasticsearchClientSettings(new SingleNodePool(url), sourceSerializer: (_, s) => new DefaultSourceSerializer(s));", 1)]
    [TestCase("var s = 1;", 0)]
    public void The_index_client_scan_reads_each_form(string source, int withoutReader) =>
        Assert.That(IndexClientsWithoutReader(source), Has.Count.EqualTo(withoutReader));
}
