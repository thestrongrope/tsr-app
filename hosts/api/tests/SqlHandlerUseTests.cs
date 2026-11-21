using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Guards the <c>Sql</c> interpolated string handler (rule 5). Its constructor and <c>AppendLiteral</c> are public because the compiler calls them, so only this scan stops a
/// developer building one by hand and appending a value as text. Only <c>shared/api/Sql.cs</c> may use them. A <c>$$"""</c> raw string is also refused, because the citext scan reads holes written <c>{x}</c>.
/// </summary>
public sealed partial class SqlHandlerUseTests
{
    private const string SqlFile = "shared/api/Sql.cs";

    [GeneratedRegex(@"\bAppendLiteral\(|\bAppendFormatted\(|\bnew\s+Sql\(")]
    private static partial Regex ByHand();

    [GeneratedRegex(@"\$\$+""")]
    private static partial Regex RawDollars();

    [TestCase("var q = new Sql(0, 0);")]
    [TestCase("q.AppendLiteral(\"x\" + name);")]
    [TestCase("q.AppendFormatted(name);")]
    public void Building_the_handler_by_hand_is_reported(string source) =>
        Assert.That(ByHand().IsMatch(source), Is.True);

    [TestCase("Sql q = $\"select 1 where id = {id}\";")]
    [TestCase("var s = new SqlQuery();")]
    public void Using_the_handler_through_an_interpolated_string_is_not_reported(string source) =>
        Assert.That(ByHand().IsMatch(source), Is.False);

    [Test]
    public void Only_the_handler_file_builds_the_handler_by_hand()
    {
        var found = ScannedFiles().Where(f => f.Relative != SqlFile && ByHand().IsMatch(File.ReadAllText(f.Path))).Select(f => f.Relative);

        Assert.That(found, Is.Empty, "write the query as an interpolated string ($\"... {value}\") so every value becomes a parameter; never call Sql's constructor or Append methods");
    }

    [TestCase("var q = $$\"\"\"select {{x}}\"\"\";")]
    [TestCase("var q = $$$\"\"\"select\"\"\";")]
    public void A_double_dollar_raw_string_is_reported(string source) =>
        Assert.That(RawDollars().IsMatch(source), Is.True);

    [TestCase("var q = $\"\"\"select {x}\"\"\";")]
    [TestCase("var price = \"$5\";")]
    public void A_single_dollar_string_is_not_reported(string source) =>
        Assert.That(RawDollars().IsMatch(source), Is.False);

    [Test]
    public void No_source_uses_a_double_dollar_raw_string()
    {
        var found = ScannedFiles().Where(f => RawDollars().IsMatch(File.ReadAllText(f.Path))).Select(f => f.Relative);

        Assert.That(found, Is.Empty, "SQL must use single-dollar interpolation ($\"...\" or $\"\"\"...\"\"\") so the scans can read its holes");
    }

    private static IEnumerable<(string Path, string Relative)> ScannedFiles()
    {
        var root = RouteCatalog.RepoRoot();
        return SqlCitextCastTests.ScannedDirectories().SelectMany(SqlBoundaryTests.Sources)
            .Select(f => (f, System.IO.Path.GetRelativePath(root, f).Replace('\\', '/')));
    }
}
