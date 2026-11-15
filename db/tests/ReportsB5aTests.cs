using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The class reports of batch B5a for callers who are NOT the super administrator (the Hurl files cover the contract): a gender administrator and a class coordinator must see only their classes, and a named grant
/// of reports:read:all opens the reports that go by the reach (summary, subject conduction) but not the ones PHP also limits by classes:read (weekly), where an assigned-only coordinator keeps the assigned classes.
/// </summary>
public sealed class ReportsB5aTests
{
    private const int Admin = 901601;
    private const int GentsAdmin = 901602;
    private const int LadiesAdmin = 901603;
    private const int Coordinator = 901604;
    private const int Granted = 901605;
    private const int Teacher = 901606;

    // 9601 gents level 3 (the coordinator's rule matches it), 9602 gents level 1 (it does not), 9603 ladies level 3, 9604 gents level 3 and closed.
    private const int Assigned = 9601;
    private const int OtherGents = 9602;
    private const int Ladies = 9603;
    private const int Closed = 9604;

    private const string Month = "from=11-2025&to=11-2025";

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate platform.outbox, classes.class_attendance, classes.class_sessions, classes.class_schedules, classes.class_students, classes.classes restart identity cascade; "
            + "truncate access.class_access_rule_conditions, access.class_access_rules, access.user_permissions restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Rt Admin", "1");
        var gentsAdmin = await MembershipTestKit.AddMemberAsync(GentsAdmin, "Rt Gents Admin", "1");
        var ladiesAdmin = await MembershipTestKit.AddMemberAsync(LadiesAdmin, "Rt Ladies Admin", "2");
        var coordinator = await MembershipTestKit.AddMemberAsync(Coordinator, "Rt Coordinator", "1");
        var granted = await MembershipTestKit.AddMemberAsync(Granted, "Rt Granted", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Rt Teacher", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({admin}, 1), ({gentsAdmin}, 3), ({ladiesAdmin}, 4), ({coordinator}, 5), ({granted}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({granted}, 'reports:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (1, {Coordinator}, 1, 'rt level 3'), (2, {Granted}, 1, 'rt level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (1, 'level', false, 3), (2, 'level', false, 3); "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, started_on) values "
            + $"({Assigned}, 'RT-G-1', 1, 'rtlink1', 'Assigned', 3, {Teacher}, 1, 'Offline', 'A', {Admin}, date '2025-01-06'), "
            + $"({OtherGents}, 'RT-G-2', 1, 'rtlink2', 'Other gents', 1, {Teacher}, 1, 'Offline', 'A', {Admin}, date '2025-01-06'), "
            + $"({Ladies}, 'RT-L-3', 1, 'rtlink3', 'Ladies', 3, {Teacher}, 2, 'Offline', 'A', {Admin}, date '2025-01-06'), "
            + $"({Closed}, 'RT-G-4', 1, 'rtlink4', 'Closed', 3, {Teacher}, 1, 'Offline', 'I', {Admin}, date '2025-01-06'); "
            + "insert into classes.class_schedules (class_id, day, hour, minute, timezone, created_by) "
            + $"select id, 2, 18, 0, 'Asia/Kolkata', {Admin} from classes.classes; "
            + "insert into classes.class_sessions (class_id, teacher, conducted_on, conducted, created_by) "
            + $"select id, {Teacher}, date '2025-11-10', 1, {Admin} from classes.classes");
    }

    private static IEnumerable<int> Ids(System.Text.Json.Nodes.JsonNode? list, string field) => list!.AsArray().Select(c => c![field]!.GetValue<int>());

    [Test]
    public async Task A_class_coordinator_sees_only_the_assigned_class_in_every_report()
    {
        var summary = await kit.SendAsync(Coordinator, HttpMethod.Get, $"/reports/summary?{Month}&gender=2");
        Assert.That(summary.Status, Is.EqualTo(HttpStatusCode.OK), summary.Body);
        Assert.That(Ids(summary.Json!["classes"], "classId"), Is.EqualTo(new[] { Assigned }));
        Assert.That(summary.Json["gender"]!.GetValue<int>(), Is.EqualTo(1), "an assigned class of one gender locks the gender");

        var weekly = await kit.SendAsync(Coordinator, HttpMethod.Get, $"/reports/weekly?{Month}");
        Assert.That(Ids(weekly.Json!["classes"], "classId"), Is.EqualTo(new[] { Assigned }));

        var conduction = await kit.SendAsync(Coordinator, HttpMethod.Get, "/reports/conduction?year=2025&week=45");
        Assert.That(Ids(conduction.Json!["lastWeek"], "classId"), Is.EqualTo(new[] { Assigned }));

        var subject = await kit.SendAsync(Coordinator, HttpMethod.Get, $"/reports/subject-conduction?{Month}");
        Assert.That(Ids(subject.Json!["classes"], "classId"), Is.EqualTo(new[] { Assigned }));
        Assert.That((await kit.SendAsync(Coordinator, HttpMethod.Get, $"/reports/subject-conduction?{Month}&classId={OtherGents}")).Status, Is.EqualTo(HttpStatusCode.Forbidden));

        var sessions = await kit.SendAsync(Coordinator, HttpMethod.Get, "/reports/class-sessions");
        Assert.That(Ids(sessions.Json!["classes"], "classId"), Is.EqualTo(new[] { Assigned }));

        Assert.That((await kit.SendAsync(Coordinator, HttpMethod.Get, $"/reports/class-sessions/{Assigned}")).Json!["sessions"]!.AsArray(), Has.Count.EqualTo(1));
        foreach (var other in new[] { OtherGents, Ladies, Closed })
        {
            Assert.That((await kit.SendAsync(Coordinator, HttpMethod.Get, $"/reports/class-sessions/{other}")).Json!["sessions"]!.AsArray(), Is.Empty, $"class {other}");
        }

        var csv = await kit.SendAsync(Coordinator, HttpMethod.Get, "/reports/class-sessions/download-all");
        Assert.That(csv.Body, Does.Contain("RT-G-1").And.Not.Contain("RT-G-2").And.Not.Contain("RT-L-3").And.Not.Contain("RT-G-4"));
        var details = await kit.SendAsync(Coordinator, HttpMethod.Get, "/reports/conduction/download-all?year=2025&week=45");
        Assert.That(details.Body, Does.Contain("RT-G-1").And.Not.Contain("RT-G-2").And.Not.Contain("RT-L-3"));
    }

    [Test]
    public async Task A_gender_administrator_sees_only_their_gender_whatever_they_ask_for_and_never_a_closed_class()
    {
        var gents = await kit.SendAsync(GentsAdmin, HttpMethod.Get, $"/reports/summary?{Month}&gender=2");
        Assert.That(gents.Json!["gender"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(Ids(gents.Json["classes"], "classId"), Is.EquivalentTo(new[] { Assigned, OtherGents }));

        var ladies = await kit.SendAsync(LadiesAdmin, HttpMethod.Get, $"/reports/summary?{Month}&gender=1");
        Assert.That(ladies.Json!["gender"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(Ids(ladies.Json["classes"], "classId"), Is.EqualTo(new[] { Ladies }));

        Assert.That((await kit.SendAsync(GentsAdmin, HttpMethod.Get, $"/reports/class-sessions/{Ladies}")).Json!["sessions"]!.AsArray(), Is.Empty);
        Assert.That((await kit.SendAsync(GentsAdmin, HttpMethod.Get, $"/reports/class-sessions/{Closed}")).Json!["sessions"]!.AsArray(), Is.Empty);
        Assert.That((await kit.SendAsync(LadiesAdmin, HttpMethod.Get, $"/reports/class-sessions/{Ladies}")).Json!["sessions"]!.AsArray(), Has.Count.EqualTo(1));
    }

    /// <summary>
    /// PHP's weekly report lists ClassesModel::getAll, which a caller whose classes:read is assigned-only keeps to the assigned classes, whatever else reports:read allows; summary asks only the reach.
    /// </summary>
    [Test]
    public async Task A_coordinator_with_a_named_grant_of_all_reports_sees_every_class_in_summary_but_only_the_assigned_in_weekly()
    {
        var summary = await kit.SendAsync(Granted, HttpMethod.Get, $"/reports/summary?{Month}");
        Assert.That(Ids(summary.Json!["classes"], "classId"), Is.EquivalentTo(new[] { Assigned, OtherGents }));

        var subject = await kit.SendAsync(Granted, HttpMethod.Get, $"/reports/subject-conduction?{Month}");
        Assert.That(Ids(subject.Json!["classes"], "classId"), Is.EquivalentTo(new[] { Assigned, OtherGents }));

        var weekly = await kit.SendAsync(Granted, HttpMethod.Get, $"/reports/weekly?{Month}");
        Assert.That(Ids(weekly.Json!["classes"], "classId"), Is.EqualTo(new[] { Assigned }));
    }

    [Test]
    public async Task A_member_without_the_permission_is_refused_and_a_report_writes_nothing()
    {
        var member = await MembershipTestKit.AddMemberAsync(901607, "Rt Plain", "1");
        Assert.That(member, Is.GreaterThan(0));
        Assert.That((await kit.SendAsync(901607, HttpMethod.Get, $"/reports/summary?{Month}")).Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That((await kit.SendAsync(Admin, HttpMethod.Get, $"/reports/summary?{Month}")).Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    /// <summary>A coordinator with classes of both genders has no gender lock: the gender asked for must still narrow every report (PHP reachFilter's "and c.gender = g").</summary>
    [Test]
    public async Task A_coordinator_of_both_genders_sees_only_the_gender_asked_for()
    {
        const int Both = 901607;
        var both = await MembershipTestKit.AddMemberAsync(Both, "Rt Both", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({both}, 5); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (3, {Both}, 1, 'rt gents level 3'), (4, {Both}, 2, 'rt ladies level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (3, 'level', false, 3), (4, 'level', false, 3)");

        foreach (var (gender, own, code, otherCode) in new[] { (1, Assigned, "RT-G-1", "RT-L-3"), (2, Ladies, "RT-L-3", "RT-G-1") })
        {
            var summary = await kit.SendAsync(Both, HttpMethod.Get, $"/reports/summary?{Month}&gender={gender}");
            Assert.That(summary.Status, Is.EqualTo(HttpStatusCode.OK), summary.Body);
            Assert.That(Ids(summary.Json!["classes"], "classId").Single(), Is.EqualTo(own));

            var sessions = await kit.SendAsync(Both, HttpMethod.Get, $"/reports/class-sessions?gender={gender}");
            Assert.That(Ids(sessions.Json!["classes"], "classId").Single(), Is.EqualTo(own));

            var csv = await kit.SendAsync(Both, HttpMethod.Get, $"/reports/class-sessions/download-all?gender={gender}");
            Assert.That(csv.Body, Does.Contain(code).And.Not.Contain(otherCode));
        }
    }
}
