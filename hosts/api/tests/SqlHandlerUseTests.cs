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

    [GeneratedRegex(@"\bAppendLiteral\(|\bAppendFormatted\(|\bnew\s+Sql\s*\(|\bSql\s+\w+\s*=\s*new\s*\(")]
    private static partial Regex ByHand();

    [GeneratedRegex(@"\$\$+""")]
    private static partial Regex RawDollars();

    [TestCase("var q = new Sql(0, 0);")]
    [TestCase("var q = new Sql (0, 0);")]
    [TestCase("Sql q = new(0, 0);")]
    [TestCase("private Sql _q = new (0, 0);")]
    [TestCase("global::Tsr.Shared.Api.Sql q = new(0, 0);")]
    [TestCase("q.AppendLiteral(\"x\" + name);")]
    [TestCase("q.AppendFormatted(name);")]
    public void Building_the_handler_by_hand_is_reported(string source) =>
        Assert.That(ByHand().IsMatch(source), Is.True);

    [TestCase("Sql q = $\"select 1 where id = {id}\";")]
    [TestCase("var s = new SqlQuery();")]
    [TestCase("List<Sql> all = new();")]
    [TestCase("Sql q = Build(new(1));")]
    public void Using_the_handler_through_an_interpolated_string_is_not_reported(string source) =>
        Assert.That(ByHand().IsMatch(source), Is.False);

    [Test]
    public void Only_the_handler_file_builds_the_handler_by_hand()
    {
        var found = ScannedFiles().Where(f => f.Relative != SqlFile && ByHand().IsMatch(File.ReadAllText(f.Path))).Select(f => f.Relative);

        Assert.That(found, Is.Empty, "write the query as an interpolated string ($\"... {value}\") so every value becomes a parameter; never call Sql's constructor or Append methods");
    }


    [GeneratedRegex(@"\.CreateCommand\(|\bnew\s+NpgsqlCommand\(|\bNpgsqlBatch\b|\b(?:ExecuteSqlRaw|ExecuteSqlRawAsync|SqlQueryRaw|FromSqlRaw)\b")]
    private static partial Regex RawCommand();

    /// <summary>Files that run string SQL on purpose, each with the reason. A new file is not on this list, so it fails: write the query as an interpolated string given to <c>Sql</c>.</summary>
    private static readonly (string File, string Reason)[] RawAllowed =
    [
        ("shared/api/Db.cs", "the one place a Sql becomes an NpgsqlCommand, with every value a parameter"),
        ("shared/api/DomainContexts.cs", "the migrate job's role grants: the schema name is checked against a pattern and the role is a constant, identifiers cannot be parameters"),
        ("domains/search/api/domain/SearchFacts.cs", "search's fresh re-check reads on its own connection: fixed SQL over published views, values bound as @parameters (not yet converted)"),
        ("domains/search/api/domain/SearchDocumentSource.cs", "search's feed reads in pages on one connection that holds an advisory lock for the run, fixed SQL over published views with @parameters (not yet converted)"),
    ];

    [TestCase("await using var c = source.CreateCommand(\"select \" + x);")]
    [TestCase("var c = new NpgsqlCommand(sql + x, conn);")]
    [TestCase("var b = new NpgsqlBatch(conn);")]
    [TestCase("db.Database.ExecuteSqlRawAsync(text);")]
    [TestCase("db.Database.SqlQueryRaw<int>(text);")]
    [TestCase("set.FromSqlRaw(text);")]
    public void A_raw_command_is_reported(string source) =>
        Assert.That(RawCommand().IsMatch(source), Is.True);

    [TestCase("var c = new NpgsqlConnection(text);")]
    [TestCase("var s = $\"select {x}\"; await db.ExecuteAsync(s, ct);")]
    [TestCase("var p = new NpgsqlParameter(\"a\", 1);")]
    public void Other_database_code_is_not_a_raw_command(string source) =>
        Assert.That(RawCommand().IsMatch(source), Is.False);

    [Test]
    public void Only_the_listed_files_run_a_raw_command()
    {
        var allowed = RawAllowed.Select(a => a.File).ToHashSet();
        var found = ScannedFiles().Where(f => !allowed.Contains(f.Relative) && RawCommand().IsMatch(File.ReadAllText(f.Path))).Select(f => f.Relative);

        Assert.That(found, Is.Empty, "run SQL as an interpolated string on NpgsqlDataSource or DbTx (Db.cs); no raw NpgsqlCommand or *Raw call outside shared/api/Db.cs");
    }

    [Test]
    public void Every_listed_raw_command_file_exists_and_still_needs_it()
    {
        var root = RouteCatalog.RepoRoot();
        var stale = RawAllowed.Where(a => !File.Exists(System.IO.Path.Combine(root, a.File)) || !RawCommand().IsMatch(File.ReadAllText(System.IO.Path.Combine(root, a.File)))).Select(a => a.File);

        Assert.That(stale, Is.Empty, "remove a file from the list when it no longer runs a raw command");
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
