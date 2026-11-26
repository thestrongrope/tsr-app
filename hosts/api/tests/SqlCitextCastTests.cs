using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// Guards the case-sensitive comparison bug (docs/specs/initial-build/build-out-findings.md, "Case-sensitive comparisons"). Every string column is <c>citext</c> (MariaDB compared
/// without regard to letter case), but a C# string parameter is sent as <c>text</c>, and <c>citext_column = {value}</c> then compares as text, case-sensitively. A comparison of a column
/// with an interpolated value must say <c>{value}::citext</c> (<c>{values}::citext[]</c> after <c>= any(</c>).
/// Limits, on purpose: it reads a fixed list of column names (<see cref="Columns"/>) that are compared with caller text, not the schema; it sees a comparison only after where, and, or, on, when, not
/// or an opening bracket (a <c>set col = {x}</c> assignment is not a comparison); a value on the left of the operator, a LIKE, and a column compared through a cast or a function are not seen.
/// The list holds every citext column name in the schema (from the model snapshots) except two groups left out on purpose: the geo names city, country and zip (citext in some tables, text in others), and gender (citext text in membership and notifications, an integer in classes). A name that is a real exception goes on <see cref="Allowed"/> with its reason.
/// </summary>
public sealed partial class SqlCitextCastTests
{
    private const string Columns =
        "code|name|link|email|status|topic|device_id|recipient|title|body|action_link|mcq_code|subject|lesson|mobile|contact_email|dedupe_key|channel|source|event_type|first_name|last_name|provider|firebase_uid|message|client_id|action|address|age_range|ahkam_conducted|ahkam_topic|akhlaq_conducted|akhlaq_topic|answer|aqaed_conducted|aqaed_topic|arabic|arabic_conducted|arabic_topic|assignments|author|body_html|body_markdown|class_level|class_number|comments|contact_name|content_hash|correct_response|country_code|description|details|device|device_key|education|error|error_message|event_key|excerpt|extra_students|field|field_of_study_other|field_of_work|file|followup|format|guide|image_url|interests|ip|kind|label|lang|language|last_failure_cause|last_run_key|lastdevice|lastloginip|levels|link_type|linkedin_url|location|message_excerpt|method|modified_date_text|non_conduction_reason|note|notes|occupation_type|operator_note|option1|option2|option3|option4|option5|option_display_order|other_conducted|other_interests|other_topic|page|payload|permission|picture|platform|postal_code_regex|preferred_location|priority|profession|professional_courses_other|proficiency|published_date_text|question|read_online_url|reason|reason_option1|reason_option2|reason_option3|referer|relationship|removed_reason|residence_location|response|revoke_reason|role_level|sendupdates|session_id|settings_snapshot|size|skill|skipped_reason|slug|state|status_reason|subject_name|summary|surah|target_audience_criteria|teacher_mobile|teacher_name|team_request|timezone|type|tz|unsubscribe|updated|url|user_agent|value|version|weekdays|work_location|years_experience";

    /// <summary>File (relative to the repo) and the exact matched text of a comparison known to be safe, with the reason.</summary>
    private static readonly (string File, string Match, string Reason)[] Allowed =
    [
        ("domains/classes/api/domain/ConductionWriter.cs", "where session_id = {sessionId}", "classes.class_attendance.session_id is an integer; only platform's session_id is citext"),
        ("domains/classes/api/domain/ConductionData.cs", "where ca.session_id = {sessionId}", "classes.class_attendance.session_id is an integer; only platform's session_id is citext"),
        ("domains/platform/api/Geo.cs", "where c.name = {wanted}", "platform.geo_countries.name is text with the geo_ci_ai collation (case and accents ignored); a citext cast would stop it ignoring accents"),
    ];

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
        var found = new List<string>();
        foreach (var file in ScannedDirectories().SelectMany(SqlBoundaryTests.Sources))
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
    [TestCase("select 1 from t where permission = {p}")]
    [TestCase("select 1 from t where slug = {slug}")]
    [TestCase("select 1 from t where g.field = {field}")]
    [TestCase("select 1 from t where g.value = {value}")]
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

    [TestCase("ListAsync")]
    [TestCase("ScalarAsync")]
    [TestCase("ExecuteAsync")]
    public void A_converted_query_without_the_cast_is_reported(string helper)
    {
        // The scan reads every SQL-looking string literal, not the method that receives it, so it sees a query after it leaves SqlQuery and ExecuteSql.
        var uncast = "await db." + helper + "($\"\"\"select 1 from identity.users where email = {email} limit 1\"\"\", row => row.Int(\"id\"), ct);";
        var cast = "await db." + helper + "($\"\"\"select 1 from identity.users where email = {email}::citext limit 1\"\"\", row => row.Int(\"id\"), ct);";

        Assert.Multiple(() =>
        {
            Assert.That(Violations(uncast), Has.Count.EqualTo(1));
            Assert.That(Violations(cast), Is.Empty);
        });
    }

    internal static IEnumerable<string> ScannedDirectories()
    {
        var root = RouteCatalog.RepoRoot();
        return Directory.EnumerateDirectories(Path.Combine(root, "domains"))
            .Select(d => Path.Combine(d, "api"))
            .Where(Directory.Exists)
            .Append(Path.Combine(root, "shared", "api"))
            .Append(Path.Combine(root, "hosts"));
    }

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
