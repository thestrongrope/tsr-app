using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Guards the case-sensitive comparison bug (docs/specs/initial-build/build-out-findings.md, "Case-sensitive comparisons"). Every string column is <c>citext</c> (MariaDB compared
/// without regard to letter case), but a C# string parameter is sent as <c>text</c>, and <c>citext_column = {value}</c> then compares as text, case-sensitively. A comparison of a column
/// with an interpolated value must say <c>{value}::citext</c> (<c>{values}::citext[]</c> after <c>= any(</c>).
/// Limits, on purpose: it reads a fixed list of column names (<see cref="Columns"/>) that are compared with caller text, not the schema; it sees a comparison only after where, and, or, on, when, not
/// or an opening bracket (a <c>set col = {x}</c> assignment is not a comparison); a value on the left of the operator, a LIKE, and a column compared through a cast or a function are not seen.
/// The geo columns (city, country, zip and the three ICU-collated ones) are not citext and are left out of the list. A name that is a real exception goes on <see cref="Allowed"/> with its reason.
/// </summary>
public sealed partial class SqlCitextCastTests
{
    private const string Columns =
        "code|name|link|email|status|topic|device_id|recipient|title|body|action_link|mcq_code|subject|lesson|mobile|contact_email|dedupe_key|channel|source|event_type|first_name|last_name|provider|firebase_uid|message|client_id";

    /// <summary>File (relative to the repo) and the exact matched text of a comparison known to be safe, with the reason. Empty: no exception was needed.</summary>
    private static readonly (string File, string Match, string Reason)[] Allowed = [];

    [GeneratedRegex(@"\b(where|and|or|on|when|not|\()\s*(?:\w+\.)?(" + Columns + @")\s*(=|<>|!=)\s*(any\(\s*)?\{[^{}]*(?:\[[^\]]*\][^{}]*)*\}(?!\s*::\s*citext)", RegexOptions.IgnoreCase)]
    private static partial Regex Uncast();

    [GeneratedRegex("\"\"\"(.*?)\"\"\"|\"((?:[^\"\\\\\\r\\n]|\\\\.)*)\"", RegexOptions.Singleline)]
    private static partial Regex Literal();

    [GeneratedRegex(@"\b(select|insert|update|delete|from|join|into)\b", RegexOptions.IgnoreCase)]
    private static partial Regex SqlWord();

    [Test]
    public void A_citext_column_compared_with_an_interpolated_value_says_citext()
    {
        var root = RouteCatalog.RepoRoot();
        var directories = Directory.EnumerateDirectories(Path.Combine(root, "domains"))
            .Select(d => Path.Combine(d, "api"))
            .Where(Directory.Exists)
            .Append(Path.Combine(root, "shared", "api"))
            .Append(Path.Combine(root, "hosts"));
        var found = new List<string>();
        foreach (var file in directories.SelectMany(SqlBoundaryTests.Sources))
        {
            var relative = Path.GetRelativePath(root, file).Replace('\\', '/');
            found.AddRange(Violations(File.ReadAllText(file))
                .Where(v => !Allowed.Any(a => a.File == relative && a.Match == v))
                .Select(v => relative + ": " + v));
        }

        Assert.That(found, Is.Empty, "write {value}::citext (or {values}::citext[]) so the comparison ignores letter case, as MariaDB did");
    }

    [TestCase("select 1 from t where link = {link} limit 1")]
    [TestCase("update t set x = 1 where recipient = any({values})")]
    [TestCase("select 1 from t where a = 1 and title = {a.Title} and body = {a.Body}::citext")]
    [TestCase("select 1 from t where name <> {c.Text[\\\"name\\\"]}")]
    public void An_uncast_comparison_is_a_violation(string sql) =>
        Assert.That(Violations("var q = $\"" + sql + "\";"), Has.Count.EqualTo(1));

    [TestCase("select 1 from t where link = {link}::citext limit 1")]
    [TestCase("update t set x = 1 where recipient = any({values}::citext[])")]
    [TestCase("update t set email = {wanted} where token = {token}")]
    [TestCase("select 1 from t where status::text = {status}::text")]
    [TestCase("select 1 from t where id = {id} and name = 'x'")]
    [TestCase("var message = $\"name = {name}\";")]
    public void A_cast_an_assignment_and_non_sql_text_are_allowed(string source) =>
        Assert.That(Violations(source.Contains('"', StringComparison.Ordinal) ? source : "var q = $\"" + source + "\";"), Is.Empty);

    internal static IReadOnlyList<string> Violations(string source)
    {
        var result = new List<string>();
        foreach (Match literal in Literal().Matches(source))
        {
            var text = literal.Groups[1].Success ? literal.Groups[1].Value : literal.Groups[2].Value;
            if (!SqlWord().IsMatch(text))
            {
                continue;
            }

            result.AddRange(Uncast().Matches(text).Select(m => m.Value));
        }

        return result;
    }
}
