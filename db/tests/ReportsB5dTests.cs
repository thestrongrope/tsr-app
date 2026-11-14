using System.Net;
using System.Text;
using NUnit.Framework;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The report DOWNLOADS of batch B5d (xlsx and PDF), on the fixtures of <see cref="ReportsB5bTests"/>: a file holds exactly the rows the screen shows that caller, a member's text cannot become a formula or markup,
/// and a renderer that fails is a 503. The PDF renderer is a fake here (no Gotenberg in this process); Hurl on the test stack proves the real one.
/// </summary>
public sealed partial class ReportsB5bTests
{
    private sealed class FakePdfRenderer : IPdfRenderer
    {
        public Result<byte[]> Answer { get; set; } = Result.Ok(Encoding.ASCII.GetBytes("%PDF-fake"));

        public string? Html { get; private set; }

        public Task<Result<byte[]>> RenderAsync(string html, CancellationToken ct)
        {
            Html = html;
            return Task.FromResult(Answer);
        }
    }

    /// <summary>The three scope cases of <see cref="AssertScopeAsync"/>, read from the cells of the workbook: the same classes the screen shows, no others.</summary>
    private async Task AssertDownloadScopeAsync(string route)
    {
        var sep = route.Contains('?', StringComparison.Ordinal) ? "&" : "?";

        await SeesInFileAsync(GentsAdmin, route + sep + "gender=2", [Assigned, OtherGents], [Ladies, Closed]);
        await SeesInFileAsync(LadiesAdmin, route + sep + "gender=1", [Ladies], [Assigned, OtherGents, Closed]);
        await SeesInFileAsync(Coordinator, route + sep + "gender=2", [Assigned], [OtherGents, Ladies, Closed]);
        await SeesInFileAsync(Both, route + sep + "gender=1", [Assigned], [OtherGents, Ladies, Closed]);
        await SeesInFileAsync(Both, route + sep + "gender=2", [Ladies], [Assigned, OtherGents, Closed]);
    }

    private async Task SeesInFileAsync(int caller, string url, string[] present, string[] absent)
    {
        var file = await kit.DownloadAsync(caller, url);
        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), url + " " + file.Text);
        var text = string.Join('\n', file.Cells());
        foreach (var code in present)
        {
            Assert.That(text, Does.Contain(code), $"{url}: {code}");
        }

        foreach (var code in absent)
        {
            Assert.That(text, Does.Not.Contain(code), $"{url}: {code}");
        }
    }

    [Test]
    public async Task Active_teachers_download_holds_only_the_teachers_of_the_classes_in_reach_and_of_the_gender_asked_for() =>
        await AssertDownloadScopeAsync("/reports/active-teachers/download?format=xlsx");

    [Test]
    public async Task Conduction_download_holds_only_the_classes_in_reach_and_the_gender_asked_for() =>
        await AssertDownloadScopeAsync("/reports/conduction/download?format=xlsx&year=2025&week=45");

    [Test]
    public async Task Weekly_download_holds_only_the_classes_in_reach_and_the_gender_asked_for() =>
        await AssertDownloadScopeAsync("/reports/weekly/download?format=xlsx&from=11-2025&to=11-2025");

    [Test]
    public async Task Summary_download_holds_only_the_classes_in_reach_and_the_gender_asked_for() =>
        await AssertDownloadScopeAsync("/reports/summary/download?format=xlsx&from=11-2025&to=11-2025");

    [Test]
    public async Task Subject_conduction_download_holds_only_the_classes_in_reach_and_refuses_a_class_asked_for_out_of_reach()
    {
        await AssertDownloadScopeAsync("/reports/subject-conduction/download?format=xlsx&from=11-2025&to=11-2025");

        var refused = await kit.DownloadAsync(Coordinator, "/reports/subject-conduction/download?format=xlsx&from=11-2025&classId=9702");
        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.Forbidden));
    }

    [Test]
    public async Task Pending_download_holds_only_the_classes_in_reach_and_the_gender_asked_for() =>
        await AssertDownloadScopeAsync("/reports/pending/download?format=xlsx&from=11-2025&to=11-2025");

    [Test]
    public async Task Pending_download_keeps_to_the_assigned_classes_of_a_coordinator_granted_all_reports()
    {
        const int Granted = 901709;
        var granted = await MembershipTestKit.AddMemberAsync(Granted, "Rt Granted Pending Dl", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({granted}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({granted}, 'reports:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (6, {Granted}, 1, 'rt level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (6, 'level', false, 3)");

        await SeesInFileAsync(Granted, "/reports/pending/download?format=xlsx&from=11-2025&to=11-2025", [Assigned], [OtherGents, Ladies, Closed]);
    }

    [Test]
    public async Task Tsr_download_holds_only_the_classes_in_reach_and_the_gender_asked_for() =>
        await AssertDownloadScopeAsync("/reports/tsr/download?format=xlsx&from=2025-11-01&to=2025-11-30");

    [Test]
    public async Task Tsr_download_follows_the_reports_grant_like_the_screen()
    {
        const int Granted = 901710;
        var granted = await MembershipTestKit.AddMemberAsync(Granted, "Rt Granted Tsr Dl", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({granted}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({granted}, 'reports:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (7, {Granted}, 1, 'rt level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (7, 'level', false, 3)");

        await SeesInFileAsync(Granted, "/reports/tsr/download?format=xlsx&from=2025-11-01&to=2025-11-30&gender=1", [Assigned, OtherGents], [Ladies, Closed]);
    }

    private async Task<string[]> StudentTokensInFileAsync(int caller, string query)
    {
        var file = await kit.DownloadAsync(caller, "/reports/students/download?format=xlsx&from=2025-11-01&to=2025-11-30" + query);
        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), file.Text);
        return [.. file.Cells().Where(c => c.StartsWith("9017", StringComparison.Ordinal) && c.Length == 6)];
    }

    [Test]
    public async Task Students_download_holds_only_the_students_of_the_classes_in_reach_and_the_gender_asked_for_and_never_a_closed_class()
    {
        await SeedStudentsAsync();

        Assert.That(await StudentTokensInFileAsync(GentsAdmin, "&gender=2"), Is.EquivalentTo((string[])["901731", "901732"]));
        Assert.That(await StudentTokensInFileAsync(LadiesAdmin, "&gender=1"), Is.EqualTo((string[])["901733"]));
        Assert.That(await StudentTokensInFileAsync(Coordinator, "&gender=2"), Is.EqualTo((string[])["901731"]));
        Assert.That(await StudentTokensInFileAsync(Both, "&gender=1"), Is.EqualTo((string[])["901731"]));
        Assert.That(await StudentTokensInFileAsync(Both, "&gender=2"), Is.EqualTo((string[])["901733"]));
        Assert.That(await StudentTokensInFileAsync(Admin, "&gender=1"), Is.EquivalentTo((string[])["901731", "901732"]));
    }

    [Test]
    public async Task Students_download_follows_the_reports_grant_and_filters_by_level_and_class_after_the_scope()
    {
        await SeedStudentsAsync();
        const int Granted = 901711;
        var granted = await MembershipTestKit.AddMemberAsync(Granted, "Rt Granted Students Dl", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({granted}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({granted}, 'reports:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (8, {Granted}, 1, 'rt level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (8, 'level', false, 3)");

        Assert.That(await StudentTokensInFileAsync(Granted, "&gender=1"), Is.EquivalentTo((string[])["901731", "901732"]));
        Assert.That(await StudentTokensInFileAsync(Granted, "&gender=1&class=" + OtherGents), Is.EqualTo((string[])["901732"]));
        Assert.That(await StudentTokensInFileAsync(Granted, "&gender=1&class=" + Closed), Is.Empty);
    }

    [Test]
    public async Task Students_download_recitation_counts_only_enrolments_in_the_assigned_classes_of_an_assigned_only_caller()
    {
        await SeedStudentsAsync();
        await TestDatabase.ExecuteAsync("insert into classes.class_students (class_id, token_no, joined_on, status) values (9702, 901731, date '2025-01-06', 'A')");
        await TestDatabase.ExecuteAsync("update classes.class_students set status = 'I' where class_id = 9701 and token_no = 901731");

        var file = await kit.DownloadAsync(Coordinator, "/reports/students/download?format=xlsx&from=2025-11-01&to=2025-11-30&gender=1");

        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), file.Text);
        using var book = file.Workbook();
        var row = book.Worksheet(1).RowsUsed().Single(r => r.Cell(4).GetString() == Assigned);
        Assert.That(row.Cell(10).GetDouble(), Is.EqualTo(0), "the only enrolment left with status A is outside the assigned classes");
    }

    [Test]
    public async Task Registrations_download_holds_the_same_waiting_people_as_the_screen_with_their_full_creation_time_and_a_formula_stays_text()
    {
        await MembershipTestKit.AddMemberAsync(901711, "Rt Waiting Older", "1");
        await MembershipTestKit.AddMemberAsync(901712, "=HYPERLINK(\"http://evil.invalid\",\"x\")", "1");
        await MembershipTestKit.AddMemberAsync(901713, "Rt Waiting Woman", "2");
        await TestDatabase.ExecuteAsync(
            "insert into membership.class_registrations (token, for_classid, status, created_at) values "
            + "(901711, 9701, 'Pending', timestamptz '2025-04-01 10:00:00+00'), (901712, null, 'Pending', timestamptz '2025-04-02 10:05:06+00'), (901713, 9703, 'Pending', timestamptz '2025-04-03 10:00:00+00')");

        async Task<(IReadOnlyList<double> Tokens, IReadOnlyList<string> Created)> ReadAsync(int caller, string query)
        {
            var file = await kit.DownloadAsync(caller, "/reports/registrations/download?format=xlsx" + query);
            Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), file.Text);
            using var book = file.Workbook();
            var rows = book.Worksheet(1).RowsUsed().Where(r => r.RowNumber() >= 5).ToList();
            return ([.. rows.Select(r => r.Cell(2).GetDouble())], [.. rows.Select(r => r.Cell(4).GetString())]);
        }

        var gents = await ReadAsync(GentsAdmin, "&gender=2");
        Assert.That(gents.Tokens, Is.EqualTo((double[])[901712, 901711]));
        Assert.That(gents.Created, Is.EqualTo((string[])["2025-04-02 10:05:06", "2025-04-01 10:00:00"]));
        Assert.That((await ReadAsync(LadiesAdmin, "&gender=1")).Tokens, Is.EqualTo((double[])[901713]));
        Assert.That((await ReadAsync(Coordinator, "&gender=2")).Tokens, Is.EqualTo((double[])[901712, 901711]), "as PHP: every waiting person of the gender, the open request too; never the other gender (901713)");
        Assert.That((await ReadAsync(Both, "&gender=2")).Tokens, Is.EqualTo((double[])[901713]));

        var file = await kit.DownloadAsync(GentsAdmin, "/reports/registrations/download?format=xlsx");
        using var workbook = file.Workbook();
        var name = workbook.Worksheet(1).Cell("C5");
        Assert.That(name.GetString(), Does.StartWith("=HYPERLINK"));
        Assert.That(name.HasFormula, Is.False);
        Assert.That(name.DataType, Is.EqualTo(ClosedXML.Excel.XLDataType.Text));

        Assert.That((await kit.DownloadAsync(Teacher, "/reports/registrations/download?format=xlsx")).Status, Is.EqualTo(HttpStatusCode.Forbidden));
    }

    [Test]
    public async Task Donors_download_is_404_when_nobody_is_in_an_active_class_and_otherwise_lists_each_enrolment_with_a_formula_name_as_text()
    {
        var none = await kit.DownloadAsync(Admin, "/admin/donors/download?format=xlsx");
        Assert.That(none.Status, Is.EqualTo(HttpStatusCode.NotFound), none.Text);
        Assert.That(none.Text, Does.Contain("There are no donors to download"));

        await MembershipTestKit.AddMemberAsync(901731, "=HYPERLINK(\"http://evil.invalid\",\"x\")", "1");
        await MembershipTestKit.AddMemberAsync(901732, "Rt Donor In Closed", "1");
        await TestDatabase.ExecuteAsync(
            "insert into classes.class_students (class_id, token_no, joined_on, status) values (9701, 901731, date '2025-01-06', 'A'), (9702, 901731, date '2025-01-06', 'A'), (9704, 901732, date '2025-01-06', 'A')");

        var file = await kit.DownloadAsync(Admin, "/admin/donors/download?format=xlsx");

        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), file.Text);
        using var book = file.Workbook();
        var names = book.Worksheet(1).RowsUsed().Where(r => r.RowNumber() >= 5).Select(r => r.Cell(1)).ToList();
        Assert.That(names, Has.Count.EqualTo(2), "one row per enrolment, none for a closed class");
        foreach (var cell in names)
        {
            Assert.That(cell.GetString(), Does.StartWith("=HYPERLINK"));
            Assert.That(cell.HasFormula, Is.False);
            Assert.That(cell.DataType, Is.EqualTo(ClosedXML.Excel.XLDataType.Text));
        }

        Assert.That((await kit.DownloadAsync(Teacher, "/admin/donors/download?format=xlsx")).Status, Is.EqualTo(HttpStatusCode.Forbidden));
    }

    [Test]
    public async Task Placed_registrations_download_gives_an_administrator_every_placed_person_and_an_assigned_only_caller_only_class_registrations_of_people_placed_in_their_classes()
    {
        foreach (var token in new[] { 901741, 901742, 901743, 901744, 901745 })
        {
            await MembershipTestKit.AddMemberAsync(token, token == 901741 ? "=HYPERLINK(\"http://evil.invalid\",\"x\")" : "Rt Placed " + token, token == 901744 ? "2" : "1");
        }

        await TestDatabase.ExecuteAsync(
            "insert into membership.class_registrations (token, for_classid, status, created_at) values "
            + "(901741, 9701, 'Accepted', timestamptz '2025-03-01 10:00:00+00'), (901742, null, 'Accepted', timestamptz '2025-03-02 10:00:00+00'), (901743, 9702, 'Accepted', timestamptz '2025-03-03 10:00:00+00'), "
            + "(901744, 9703, 'Accepted', timestamptz '2025-03-04 10:00:00+00'), (901745, 9704, 'Accepted', timestamptz '2025-03-05 10:00:00+00'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, status) values "
            + "(9701, 901741, date '2025-09-02', 'A'), (9701, 901742, date '2025-09-02', 'A'), (9702, 901743, date '2025-09-02', 'A'), (9703, 901744, date '2025-09-02', 'A'), (9704, 901745, date '2025-09-02', 'A')");

        async Task<double[]> TokensAsync(int caller, string query)
        {
            var file = await kit.DownloadAsync(caller, "/reports/registrations/allocated/download?format=xlsx" + query);
            Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), file.Text);
            using var book = file.Workbook();
            return [.. book.Worksheet(1).RowsUsed().Where(r => r.RowNumber() >= 5).Select(r => r.Cell(2).GetDouble()).Order()];
        }

        Assert.That(await TokensAsync(Admin, "&gender=1"), Is.EqualTo((double[])[901741, 901742, 901743]));
        Assert.That(await TokensAsync(GentsAdmin, "&gender=2"), Is.EqualTo((double[])[901741, 901742, 901743]));
        Assert.That(await TokensAsync(LadiesAdmin, "&gender=1"), Is.EqualTo((double[])[901744]));
        Assert.That(await TokensAsync(Coordinator, "&gender=2"), Is.EqualTo((double[])[901741]), "assigned class 9701 only, and not the open registration of 901742");
        Assert.That(await TokensAsync(Both, "&gender=2"), Is.EqualTo((double[])[901744]));
        Assert.That(await TokensAsync(Both, "&gender=1"), Is.EqualTo((double[])[901741]));

        var file = await kit.DownloadAsync(Admin, "/reports/registrations/allocated/download?format=xlsx");
        using var workbook = file.Workbook();
        var name = workbook.Worksheet(1).RowsUsed().Single(r => r.RowNumber() >= 5 && r.Cell(2).GetDouble() == 901741).Cell(3);
        Assert.That(name.GetString(), Does.StartWith("=HYPERLINK"));
        Assert.That(name.HasFormula, Is.False);
        Assert.That(name.DataType, Is.EqualTo(ClosedXML.Excel.XLDataType.Text));
        Assert.That((await kit.DownloadAsync(Teacher, "/reports/registrations/allocated/download?format=xlsx")).Status, Is.EqualTo(HttpStatusCode.Forbidden));
    }

    [Test]
    public async Task Class_session_download_holds_the_sessions_of_a_class_only_for_a_caller_who_reaches_it_by_the_class_own_gender()
    {
        async Task<bool> HasSessionAsync(int caller, int classId)
        {
            var file = await kit.DownloadAsync(caller, $"/reports/class-sessions/{classId}/download?format=xlsx");
            Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), file.Text);
            return file.Cells().Contains("2025-11-10");
        }

        Assert.That(await HasSessionAsync(Coordinator, 9701), Is.True);
        Assert.That(await HasSessionAsync(Coordinator, 9702), Is.False, "not assigned");
        Assert.That(await HasSessionAsync(Coordinator, 9703), Is.False, "ladies class");
        Assert.That(await HasSessionAsync(GentsAdmin, 9702), Is.True);
        Assert.That(await HasSessionAsync(GentsAdmin, 9703), Is.False, "the other gender");
        Assert.That(await HasSessionAsync(LadiesAdmin, 9703), Is.True);
        Assert.That(await HasSessionAsync(LadiesAdmin, 9701), Is.False);
        Assert.That(await HasSessionAsync(Both, 9703), Is.True, "a coordinator of both genders reaches each class by its own gender");
        Assert.That(await HasSessionAsync(Both, 9702), Is.False);
        Assert.That(await HasSessionAsync(Admin, 9704), Is.False, "closed");
        Assert.That(await HasSessionAsync(Admin, 99999999), Is.False, "missing");
    }

    [Test]
    public async Task A_member_name_that_looks_like_a_formula_is_text_in_the_workbook_and_escaped_in_the_pdf_page()
    {
        const string Formula = "=HYPERLINK(\"http://evil.invalid\",\"x\")";
        await TestDatabase.ExecuteAsync("update membership.member_profiles set name = " + MembershipTestKit.Quote(Formula) + " where user_id = (select id from identity.users where token = " + Teacher + ")");

        var xlsx = await kit.DownloadAsync(Admin, "/reports/active-teachers/download?format=xlsx");
        Assert.That(xlsx.Status, Is.EqualTo(HttpStatusCode.OK));
        using (var book = xlsx.Workbook())
        {
            var cell = book.Worksheets.SelectMany(s => s.CellsUsed()).Single(c => c.GetString() == Formula);
            Assert.That(cell.HasFormula, Is.False);
            Assert.That(cell.DataType, Is.EqualTo(ClosedXML.Excel.XLDataType.Text));
        }

        await TestDatabase.ExecuteAsync("update membership.member_profiles set name = '<img src=x onerror=alert(1)>' where user_id = (select id from identity.users where token = " + Teacher + ")");
        var pdf = await kit.DownloadAsync(Admin, "/reports/active-teachers/download?format=pdf");
        Assert.That(pdf.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(renderer.Html, Does.Contain("&lt;img src=x onerror=alert(1)&gt;").And.Not.Contain("<img"));
    }

    [Test]
    public async Task A_download_with_a_bad_format_is_422_even_without_a_sign_in_and_a_good_one_needs_it()
    {
        var bad = await kit.DownloadAsync(0, "/reports/active-teachers/download?format=csv", signedIn: false);
        Assert.That(bad.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(bad.Text, Does.Contain("format must be xlsx or pdf"));

        var missing = await kit.DownloadAsync(0, "/reports/active-teachers/download", signedIn: false);
        Assert.That(missing.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));

        var unsigned = await kit.DownloadAsync(0, "/reports/active-teachers/download?format=xlsx", signedIn: false);
        Assert.That(unsigned.Status, Is.EqualTo(HttpStatusCode.Unauthorized));
    }

    [Test]
    public async Task A_renderer_that_is_down_makes_a_pdf_download_503_and_leaves_the_workbook_working()
    {
        renderer.Answer = Result.Fail<byte[]>("Gotenberg unreachable");
        try
        {
            var pdf = await kit.DownloadAsync(Admin, "/reports/active-teachers/download?format=pdf");
            Assert.That(pdf.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable));
            Assert.That(pdf.Text, Does.Contain("\"detail\"").And.Not.Contain("Gotenberg"));
            Assert.That((await kit.DownloadAsync(Admin, "/reports/active-teachers/download?format=xlsx")).Status, Is.EqualTo(HttpStatusCode.OK));
        }
        finally
        {
            renderer.Answer = Result.Ok(Encoding.ASCII.GetBytes("%PDF-fake"));
        }
    }

    [Test]
    public async Task A_pdf_download_returns_what_the_renderer_made_with_the_PHP_headers()
    {
        var pdf = await kit.DownloadAsync(Admin, "/reports/active-teachers/download?format=pdf");

        Assert.That(pdf.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(pdf.ContentType, Is.EqualTo("application/pdf"));
        Assert.That(pdf.Disposition, Is.EqualTo("attachment; filename=\"Active-teachers-Gents.pdf\""));
        Assert.That(pdf.Text, Is.EqualTo("%PDF-fake"));
    }

    /// <summary>PHP leaves out only the placeholder members (address ending @thestrongrope.com): a member with an ordinary .com address is in the file.</summary>
    [Test]
    public async Task The_allocated_download_keeps_a_member_with_a_dot_com_address_and_leaves_out_only_placeholder_members()
    {
        await MembershipTestKit.AddMemberAsync(901746, "Rt Dot Com", "1");
        await MembershipTestKit.AddMemberAsync(901747, "Rt Placeholder", "1");
        await TestDatabase.ExecuteAsync(
            // example.com is a reserved documentation domain (RFC 2606), not a real address; the rule under test needs an address ending in .com.
            "update identity.users set email = 'rt.placed@example.com' where token = 901746; update identity.users set email = '901747@thestrongrope.com' where token = 901747; "
            + "insert into membership.class_registrations (token, for_classid, status, created_at) values "
            + "(901746, 9701, 'Accepted', timestamptz '2025-03-06 10:00:00+00'), (901747, 9701, 'Accepted', timestamptz '2025-03-07 10:00:00+00'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, status) values (9701, 901746, date '2025-09-02', 'A'), (9701, 901747, date '2025-09-02', 'A')");

        var file = await kit.DownloadAsync(Admin, "/reports/registrations/allocated/download?format=xlsx&gender=1");
        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), file.Text);
        using var book = file.Workbook();
        var tokens = book.Worksheet(1).RowsUsed().Where(r => r.RowNumber() >= 5).Select(r => r.Cell(2).GetDouble()).ToList();
        Assert.That(tokens, Does.Contain(901746d));
        Assert.That(tokens, Does.Not.Contain(901747d));
    }
}
