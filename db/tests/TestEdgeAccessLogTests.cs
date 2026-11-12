using System.Net;
using ClosedXML.Excel;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// GET /admin/access-log and its download, on rows seeded straight into platform.admin_access_log: the 30 day window (users, pages and the file; not the recent list), the 500 cap, the filters, the refusals, a NUL in the page filter,
/// and the workbook read back cell by cell. Members: 927040 super admin (role 1, holds audit-log:read), 927041 gents admin (role 3), 927042 plain member, 927043 the subject whose rows these are.
/// </summary>
public sealed class TestEdgeAccessLogTests
{
    private const int Super = 927040;
    private const int GentsAdmin = 927041;
    private const int Plain = 927042;
    private const int Subject = 927043;

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate platform.admin_access_log restart identity");
        foreach (var (token, role) in new[] { (Super, 1), (GentsAdmin, 3), (Plain, 0), (Subject, 0) })
        {
            var id = await MembershipTestKit.AddMemberAsync(token, "Edge Member " + token, "1");
            if (role != 0)
            {
                await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({id}, {role})");
            }
        }
    }

    private static Task LogAsync(string page, string interval, string method = "GET", string? agent = "Edge UA", string? referer = null, string? ip = "192.0.2.1", int token = Subject) =>
        TestDatabase.ExecuteAsync(
            "insert into platform.admin_access_log (accessed_at, user_id, token, roleid, page, method, ip, user_agent, referer) "
            + $"select now() - interval '{interval}', u.id, {token}, 1, '{page.Replace("'", "''", StringComparison.Ordinal)}', '{method}', "
            + $"{(ip is null ? "null" : "'" + ip + "'")}, {(agent is null ? "null" : "'" + agent.Replace("'", "''", StringComparison.Ordinal) + "'")}, {(referer is null ? "null" : "'" + referer + "'")} "
            + $"from identity.users u where u.token = {token}");

    [Test]
    public async Task Only_audit_log_read_holders_see_the_log_and_the_file_and_the_order_of_checks_is_format_sign_in_permission_filter()
    {
        await LogAsync("/a", "1 hour");

        var gents = await kit.SendAsync(GentsAdmin, HttpMethod.Get, "/admin/access-log");
        var plain = await kit.SendAsync(Plain, HttpMethod.Get, "/admin/access-log?token=abc");
        var nobody = await kit.SendUnsignedAsync(HttpMethod.Get, "/admin/access-log");
        var gentsFile = await kit.DownloadAsync(GentsAdmin, "/admin/access-log/download?format=xlsx");
        var plainFile = await kit.DownloadAsync(Plain, "/admin/access-log/download?format=xlsx&token=abc");
        var noFormat = await kit.DownloadAsync(Super, "/admin/access-log/download", signedIn: false);
        var nobodyFile = await kit.DownloadAsync(Super, "/admin/access-log/download?format=xlsx", signedIn: false);
        var badToken = await kit.SendAsync(Super, HttpMethod.Get, "/admin/access-log?token=1.5");

        Assert.That(gents.Status, Is.EqualTo(HttpStatusCode.Forbidden), gents.Body);
        Assert.That(gents.Detail, Is.EqualTo("You do not have permission to do that"));
        Assert.That(plain.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(nobody.Status, Is.EqualTo(HttpStatusCode.Unauthorized));
        Assert.That(gentsFile.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(plainFile.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(noFormat.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(nobodyFile.Status, Is.EqualTo(HttpStatusCode.Unauthorized));
        Assert.That(badToken.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
    }

    [Test]
    public async Task The_summaries_and_the_file_cover_30_days_and_the_recent_list_does_not()
    {
        await LogAsync("/inside", "29 days 23 hours");
        await LogAsync("/outside", "30 days 1 hour");
        await LogAsync("/outside", "90 days");

        var reply = await kit.SendAsync(Super, HttpMethod.Get, $"/admin/access-log?token={Subject}");
        var file = await kit.DownloadAsync(Super, $"/admin/access-log/download?format=xlsx&token={Subject}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["users"]![0]!["hits"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(reply.Json["pages"]!.AsArray().Select(p => p!["page"]!.GetValue<string>()), Is.EqualTo(new List<string> { "/inside" }));
        Assert.That(reply.Json["recent"]!.AsArray(), Has.Count.EqualTo(3));
        Assert.That(file.Cells(), Does.Contain("/inside").And.Not.Contain("/outside"));
    }

    [Test]
    public async Task The_recent_list_is_the_latest_500()
    {
        await TestDatabase.ExecuteAsync(
            "insert into platform.admin_access_log (accessed_at, user_id, token, roleid, page, method) "
            + $"select now() - (g || ' minutes')::interval, (select id from identity.users where token = {Subject}), {Subject}, 1, '/bulk/' || g, 'GET' from generate_series(1, 505) g");

        var reply = await kit.SendAsync(Super, HttpMethod.Get, $"/admin/access-log?token={Subject}");

        Assert.That(reply.Json!["recent"]!.AsArray(), Has.Count.EqualTo(500));
        Assert.That(reply.Json["recent"]![0]!["page"]!.GetValue<string>(), Is.EqualTo("/bulk/505"));
        Assert.That(reply.Json["users"]![0]!["hits"]!.GetValue<int>(), Is.EqualTo(505));
    }

    [Test]
    public async Task The_token_and_page_filters_narrow_all_three_lists_and_a_nul_in_the_page_matches_nothing_without_a_500()
    {
        await LogAsync("/alpha", "1 hour");
        await LogAsync("/beta", "2 hours");
        var other = await MembershipTestKit.AddMemberAsync(927044, "Other", "1");
        await LogAsync("/alpha", "3 hours", token: 927044);

        var byToken = await kit.SendAsync(Super, HttpMethod.Get, $"/admin/access-log?token={Subject}");
        var byPage = await kit.SendAsync(Super, HttpMethod.Get, $"/admin/access-log?token={Subject}&page=alp");
        var nul = await kit.SendAsync(Super, HttpMethod.Get, $"/admin/access-log?token={Subject}&page=al%00pha");
        var huge = await kit.SendAsync(Super, HttpMethod.Get, "/admin/access-log?token=99999999999999999999999999");
        var wildcard = await kit.SendAsync(Super, HttpMethod.Get, $"/admin/access-log?token={Subject}&page=%25");

        Assert.That(other, Is.GreaterThan(0));
        Assert.That(byToken.Json!["recent"]!.AsArray(), Has.Count.EqualTo(2));
        Assert.That(byToken.Json["users"]!.AsArray(), Has.Count.EqualTo(1));
        Assert.That(byPage.Json!["recent"]!.AsArray(), Has.Count.EqualTo(1));
        Assert.That(byPage.Json["pages"]!.AsArray(), Has.Count.EqualTo(1));
        Assert.That(nul.Status, Is.EqualTo(HttpStatusCode.OK), nul.Body);
        Assert.That(nul.Json!["recent"]!.AsArray(), Is.Empty);
        Assert.That(nul.Json["users"]!.AsArray(), Is.Empty);
        Assert.That(huge.Status, Is.EqualTo(HttpStatusCode.OK), huge.Body);
        Assert.That(huge.Json!["recent"]!.AsArray(), Is.Empty);
        Assert.That(wildcard.Json!["recent"]!.AsArray(), Has.Count.EqualTo(2), "% is a wildcard, as in PHP (a cost, not a leak)");
    }

    [Test]
    public async Task The_workbook_holds_the_window_rows_cell_by_cell_with_formula_like_text_kept_as_text()
    {
        await LogAsync("/edge/alpha", "1 hour", referer: "https://example.invalid/r");
        await LogAsync("/edge/beta", "2 hours", method: "POST", agent: "=cmd|calc", referer: "@ref", ip: null);
        await LogAsync("/edge/old", "40 days");

        var file = await kit.DownloadAsync(Super, $"/admin/access-log/download?format=xlsx&token={Subject}");

        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK));
        using var book = file.Workbook();
        var sheet = book.Worksheet(1);
        Assert.That(sheet.Name, Is.EqualTo("Admin access log"));
        var rows = sheet.RowsUsed().Select(r => r.CellsUsed().Select(c => c.GetString()).ToList()).ToList();
        Assert.That(rows[0][0], Is.EqualTo("Admin access log"));
        Assert.That(rows[1][0], Does.StartWith("Admin access log, last 30 days, "));
        var headers = rows.First(r => r.Contains("Time"));
        Assert.That(headers, Is.EqualTo(new List<string> { "Time", "Member", "Name", "Email", "Role", "Method", "Page", "Address", "Device", "Referrer" }));
        var data = rows.Where(r => r.Count > 0 && r.Contains(Subject.ToString(System.Globalization.CultureInfo.InvariantCulture))).ToList();
        Assert.That(data, Has.Count.EqualTo(2), "the 40 day old access is not in the file");
        Assert.That(data[0].Contains("/edge/beta"), "highest id first, as PHP orders (l.id DESC)");
        Assert.That(string.Join('|', data[1]), Does.Contain("Admin|GET|/edge/alpha|192.0.2.1|Edge UA|https://example.invalid/r"));
        var formula = sheet.CellsUsed().Single(c => c.GetString().Contains("cmd|calc", StringComparison.Ordinal));
        Assert.That(formula.HasFormula, Is.False);
        Assert.That(formula.DataType, Is.EqualTo(XLDataType.Text));
    }

    [Test]
    public async Task A_download_with_no_match_is_404_and_the_pdf_failure_is_not_this_routes_concern()
    {
        var empty = await kit.DownloadAsync(Super, "/admin/access-log/download?format=xlsx&token=999999999");

        Assert.That(empty.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(empty.Text, Does.Contain("No accesses match"));
    }
}
