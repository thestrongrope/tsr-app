using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// domains/CLAUDE.md rule 2 (decision D1): a domain's SQL may name another domain's published views (<c>v_*</c>) and
/// <c>platform.outbox</c>, and no other object of another schema. The scan reads every domain's C# (not tests, not
/// generated designer or snapshot files): the text of each string literal that looks like SQL, and the schema argument of
/// migration builders. <see cref="Frozen"/> lists the foreign keys that applied migrations already created; an applied
/// migration is never edited.
/// </summary>
public sealed partial class SqlBoundaryTests
{
    private static readonly string[] Schemas =
        ["identity", "access", "platform", "membership", "content", "classes", "assessment", "notifications", "search"];

    /// <summary>Applied migrations that name another schema's table (foreign keys). A new entry needs a reason; the list never grows.</summary>
    private static readonly string[] Frozen =
    [
        "domains/access/api/Migrations/20261110072713_Initial.cs",
        "domains/platform/api/Migrations/20261110072727_Initial.cs",
        "domains/platform/api/Migrations/20261110122813_DropIdentityForeignKeys.cs",
    ];

    [GeneratedRegex("""(?<![\w."])"?(identity|access|platform|membership|content|classes|assessment|notifications|search)"?\."?([a-z_][a-z0-9_]*)""", RegexOptions.IgnoreCase)]
    private static partial Regex Qualified();

    [GeneratedRegex(@"\b(select|insert|update|delete|from|join|into|references|alter|create|drop|truncate)\b", RegexOptions.IgnoreCase)]
    private static partial Regex SqlWord();

    [GeneratedRegex("\"\"\"(.*?)\"\"\"|\"((?:[^\"\\\\\\r\\n]|\\\\.)*)\"", RegexOptions.Singleline)]
    private static partial Regex Literal();

    [GeneratedRegex("(?:principalSchema|schema):\\s*\"(\\w+)\"")]
    private static partial Regex SchemaArgument();

    public static IEnumerable<string> DomainNames() => Schemas.Where(s => Directory.Exists(DomainApi(s)));

    [TestCaseSource(nameof(DomainNames))]
    public void A_domains_sql_names_only_its_own_objects_and_published_views(string domain)
    {
        var root = RouteCatalog.RepoRoot();
        var found = new List<string>();
        foreach (var file in SourceFiles(domain))
        {
            var relative = Path.GetRelativePath(root, file).Replace('\\', '/');
            if (Frozen.Contains(relative))
            {
                continue;
            }

            found.AddRange(Violations(domain, File.ReadAllText(file)).Select(v => relative + ": " + v));
        }

        Assert.That(found, Is.Empty, domain + " reads or writes another domain's table (use its v_* view or its published command)");
    }

    [Test]
    public void Shared_and_hosts_sql_names_only_views_and_the_outbox()
    {
        // No exemption was needed: shared/api (Outbox.cs) names platform.outbox, which is allowed, and the hosts hold no SQL.
        var root = RouteCatalog.RepoRoot();
        var found = new List<string>();
        foreach (var file in Sources(Path.Combine(root, "shared", "api")).Concat(Sources(Path.Combine(root, "hosts"))))
        {
            found.AddRange(Violations(string.Empty, File.ReadAllText(file)).Select(v => Path.GetRelativePath(root, file) + ": " + v));
        }

        Assert.That(found, Is.Empty);
    }

    [Test]
    public void Frozen_files_exist()
    {
        var root = RouteCatalog.RepoRoot();
        Assert.That(Frozen.Where(f => !File.Exists(Path.Combine(root, f))), Is.Empty);
    }

    [TestCase("select * from identity.users", "identity.users")]
    [TestCase("insert into membership.member_profiles (user_id) values (1)", "membership.member_profiles")]
    [TestCase("select 1 from identity.users u join identity.v_users v on true", "identity.users")]
    public void A_foreign_table_in_a_sql_literal_is_a_violation(string sql, string expected) =>
        Assert.That(Violations("classes", "var q = \"" + sql + "\";"), Is.EqualTo(new List<string> { expected }));

    [TestCase("select * from identity.v_users")]
    [TestCase("insert into platform.outbox (type) values (1)")]
    [TestCase("select * from classes.classes")]
    [TestCase("\"classes.teacher\"")]
    [TestCase("var x = identity.Name;")]
    public void Published_views_the_outbox_own_tables_and_non_sql_text_are_allowed(string source) =>
        Assert.That(Violations("classes", source.Contains('"', StringComparison.Ordinal) ? source : "var q = \"" + source + "\";"), Is.Empty);

    [TestCase("select * from \\\"identity\\\".\\\"users\\\"")]
    [TestCase("select * from \\\"identity\\\".users")]
    [TestCase("select * from identity.\\\"users\\\"")]
    public void A_quoted_identifier_is_still_a_violation(string sql) =>
        Assert.That(Violations("classes", "var q = \"" + sql + "\";"), Has.Count.EqualTo(1));

    [Test]
    public void Shared_and_hosts_may_name_only_views_and_the_outbox() =>
        Assert.That(Violations(string.Empty, "var q = \"select * from platform.outbox, identity.v_users, identity.users\";"), Is.EqualTo(new List<string> { "identity.users" }));

    [Test]
    public void A_raw_string_literal_is_scanned()
    {
        var source = "var q = \"\"\"\n    select *\n    from access.role_permissions\n    \"\"\";";
        Assert.That(Violations("classes", source), Is.EqualTo(new List<string> { "access.role_permissions" }));
    }

    [Test]
    public void A_migration_builder_schema_argument_naming_another_domain_is_a_violation() =>
        Assert.That(Violations("classes", "migrationBuilder.DropTable(name: \"users\", schema: \"identity\");"), Is.EqualTo(new List<string> { "schema: identity" }));

    // Not caught, by design: a schema-qualified name built from variables or concatenated pieces (a review item, domains/CLAUDE.md rule 2).
    internal static IReadOnlyList<string> Violations(string domain, string source)
    {
        var result = new List<string>();
        foreach (Match literal in Literal().Matches(source))
        {
            var text = (literal.Groups[1].Success ? literal.Groups[1].Value : literal.Groups[2].Value).Replace("\\\"", "\"", StringComparison.Ordinal);
            if (!SqlWord().IsMatch(text))
            {
                continue;
            }

            foreach (Match name in Qualified().Matches(text))
            {
                var schema = name.Groups[1].Value.ToLowerInvariant();
                var obj = name.Groups[2].Value.ToLowerInvariant();
                if (schema != domain && !obj.StartsWith("v_", StringComparison.Ordinal) && !(schema == "platform" && obj == "outbox"))
                {
                    result.Add(schema + "." + obj);
                }
            }
        }

        foreach (Match argument in SchemaArgument().Matches(source))
        {
            var schema = argument.Groups[1].Value;
            if (schema != domain && Schemas.Contains(schema))
            {
                result.Add("schema: " + schema);
            }
        }

        return result;
    }

    private static string DomainApi(string domain) => Path.Combine(RouteCatalog.RepoRoot(), "domains", domain, "api");

    private static IEnumerable<string> SourceFiles(string domain) => Sources(DomainApi(domain));

    internal static IEnumerable<string> Sources(string directory) =>
        Directory.EnumerateFiles(directory, "*.cs", SearchOption.AllDirectories)
            .Where(f => !f.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.Ordinal)
                && !f.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.Ordinal)
                && !f.Contains($"{Path.DirectorySeparatorChar}tests{Path.DirectorySeparatorChar}", StringComparison.Ordinal)
                && !f.EndsWith(".Tests.cs", StringComparison.Ordinal)
                && !f.EndsWith(".Designer.cs", StringComparison.Ordinal)
                && !f.EndsWith("ModelSnapshot.cs", StringComparison.Ordinal));
}
