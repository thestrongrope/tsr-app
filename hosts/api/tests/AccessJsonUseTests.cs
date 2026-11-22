using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Issue 99 (ACC-R9). The test host runs under JIT, so a reflection write in a converted domain would pass every test and fail only in the native build.
/// A scan of the access files finds it: every statement that serialises must pass a type info of the source-generated <c>AccessJson</c> context.
/// Tests are not scanned.
/// </summary>
public sealed partial class AccessJsonUseTests
{
    // The call, up to the end of its statement: a statement may run over several lines, and its type info is often on the last.
    [GeneratedRegex(@"(?:Results\.Json|TypedResults\.Json|JsonSerializer\.Serialize|JsonSerializer\.Deserialize|WriteAsJsonAsync|ReadFromJsonAsync)\s*(?:<[^;(]*>)?\s*\([^;]*;")]
    private static partial Regex Serialising();

    /// <summary>The serialising statements of a file's text that do not name an <c>AccessJson.</c> type info.</summary>
    internal static IReadOnlyList<string> Hits(string text) =>
        Serialising().Matches(text).Select(match => match.Value).Where(statement => !statement.Contains("AccessJson.", StringComparison.Ordinal)).ToList();

    [Test]
    public void Every_serialising_statement_of_access_uses_the_generated_context()
    {
        var root = RouteCatalog.RepoRoot();
        var found = SqlBoundaryTests.Sources(Path.Combine(root, "domains", "access", "api"))
            .Where(path => !path.Contains("/Migrations/", StringComparison.Ordinal))
            .SelectMany(path => Hits(File.ReadAllText(path)).Select(statement => $"{Path.GetRelativePath(root, path)}: {statement}"));

        Assert.That(found, Is.Empty, "pass an AccessJson type info (AccessJson.Answers.<Type>) so the write needs no reflection");
    }

    [Test]
    public void The_scan_reads_the_access_files()
    {
        var files = SqlBoundaryTests.Sources(Path.Combine(RouteCatalog.RepoRoot(), "domains", "access", "api")).ToList();

        Assert.That(files.Any(path => path.EndsWith("ClassAccessStore.cs", StringComparison.Ordinal)), Is.True);
    }

    [TestCase("return Results.Json(view);")]
    [TestCase("return TypedResults.Json(view);")]
    [TestCase("var s = JsonSerializer.Serialize(view);")]
    [TestCase("var v = JsonSerializer.Deserialize<View>(text);")]
    [TestCase("await context.Response.WriteAsJsonAsync(view, ct);")]
    [TestCase("var v = await request.ReadFromJsonAsync<View>(ct);")]
    [TestCase("return Results.Json(new View(1,\n    2), statusCode: 409);")]
    public void The_scan_reports_each_reflection_form(string source) =>
        Assert.That(Hits(source), Has.Count.EqualTo(1));

    [TestCase("return Results.Json(view, AccessJson.Answers.GrantMemberView);")]
    [TestCase("return Results.Json(new View(1,\n    2), AccessJson.Answers.View, statusCode: 409);")]
    [TestCase("var s = JsonSerializer.Serialize(view, AccessJson.Default.PermissionGranted);")]
    [TestCase("return x is null ? Problem.Detail(404, \"no\") : Results.Json(view, AccessJson.Answers.GrantMemberView);")]
    public void The_scan_passes_a_statement_with_an_access_type_info(string source) =>
        Assert.That(Hits(source), Is.Empty);
}
