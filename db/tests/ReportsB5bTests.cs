using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The class reports of batch B5b (active teachers, this week, students, tsr, pending) for callers who are NOT the super administrator: a gender administrator asking for the other gender, a coordinator limited to one
/// assigned class, and a coordinator with classes of both genders asking for one gender must each see only their classes. The Hurl files cover the contract.
/// </summary>
public sealed class ReportsB5bTests
{
    private const int Admin = 901701;
    private const int GentsAdmin = 901702;
    private const int LadiesAdmin = 901703;
    private const int Coordinator = 901704;
    private const int Both = 901705;
    private const int Teacher = 901706;
    private const int LadiesTeacher = 901707;

    // 9701 gents level 3 (the coordinator's rule matches it), 9702 gents level 1 (it does not), 9703 ladies level 3, 9704 gents level 3 and closed.
    private const string Assigned = "RT-G-1";
    private const string OtherGents = "RT-G-2";
    private const string Ladies = "RT-L-3";
    private const string Closed = "RT-G-4";

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
        var both = await MembershipTestKit.AddMemberAsync(Both, "Rt Both", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Rt Teacher", "1");
        await MembershipTestKit.AddMemberAsync(LadiesTeacher, "Rt Ladies Teacher", "2");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({admin}, 1), ({gentsAdmin}, 3), ({ladiesAdmin}, 4), ({coordinator}, 5), ({both}, 5); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (1, {Coordinator}, 1, 'rt level 3'), (3, {Both}, 1, 'rt gents level 3'), (4, {Both}, 2, 'rt ladies level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (1, 'level', false, 3), (3, 'level', false, 3), (4, 'level', false, 3); "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, started_on) values "
            + $"(9701, '{Assigned}', 1, 'rtlink1', 'Assigned', 3, {Teacher}, 1, 'Offline', 'A', {Admin}, date '2025-01-06'), "
            + $"(9702, '{OtherGents}', 1, 'rtlink2', 'Other gents', 1, {Teacher}, 1, 'Offline', 'A', {Admin}, date '2025-01-06'), "
            + $"(9703, '{Ladies}', 1, 'rtlink3', 'Ladies', 3, {LadiesTeacher}, 2, 'Offline', 'A', {Admin}, date '2025-01-06'), "
            + $"(9704, '{Closed}', 1, 'rtlink4', 'Closed', 3, {Teacher}, 1, 'Offline', 'I', {Admin}, date '2025-01-06'); "
            + "insert into classes.class_schedules (class_id, day, hour, minute, timezone, created_by) "
            + $"select id, 2, 18, 0, 'Asia/Kolkata', {Admin} from classes.classes; "
            + "insert into classes.class_sessions (class_id, teacher, conducted_on, conducted, created_by) "
            + $"select id, teacher, date '2025-11-10', 1, {Admin} from classes.classes");
    }

    /// <summary>The route as one caller: the class codes the body must name and the ones it must not.</summary>
    private async Task ShowsAsync(int caller, string url, string[] present, string[] absent)
    {
        var answer = await kit.SendAsync(caller, HttpMethod.Get, url);
        Assert.That(answer.Status, Is.EqualTo(HttpStatusCode.OK), url + " " + answer.Body);
        foreach (var code in present)
        {
            Assert.That(answer.Body, Does.Contain(code), $"{url}: {code}");
        }

        foreach (var code in absent)
        {
            Assert.That(answer.Body, Does.Not.Contain(code), $"{url}: {code}");
        }
    }

    /// <summary>The three scope cases every class-scoped report must pass; <paramref name="route"/> holds the query string the report needs.</summary>
    private async Task AssertScopeAsync(string route)
    {
        var sep = route.Contains('?', StringComparison.Ordinal) ? "&" : "?";

        // A gender administrator keeps their gender whatever they ask for, and never sees a closed class.
        await ShowsAsync(GentsAdmin, route + sep + "gender=2", [Assigned, OtherGents], [Ladies, Closed]);
        await ShowsAsync(LadiesAdmin, route + sep + "gender=1", [Ladies], [Assigned, OtherGents, Closed]);

        // A coordinator assigned one class sees that class only, whatever gender or class it asks for.
        await ShowsAsync(Coordinator, route + sep + "gender=2", [Assigned], [OtherGents, Ladies, Closed]);

        // A coordinator with classes of both genders sees only the gender asked for.
        await ShowsAsync(Both, route + sep + "gender=1", [Assigned], [OtherGents, Ladies, Closed]);
        await ShowsAsync(Both, route + sep + "gender=2", [Ladies], [Assigned, OtherGents, Closed]);
    }

    [Test]
    public async Task Active_teachers_lists_only_the_teachers_of_the_classes_in_reach_and_of_the_gender_asked_for() =>
        await AssertScopeAsync("/reports/active-teachers");

    [Test]
    public async Task This_week_lists_only_the_classes_in_reach_and_the_gender_asked_for() => await AssertScopeAsync("/reports/this-week");

    [Test]
    public async Task This_week_class_is_404_for_a_class_out_of_reach_by_the_class_own_gender_and_closed_or_missing_classes()
    {
        async Task<HttpStatusCode> StatusAsync(int caller, int classId) => (await kit.SendAsync(caller, HttpMethod.Get, $"/reports/this-week/class/{classId}")).Status;

        Assert.That(await StatusAsync(Coordinator, 9701), Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await StatusAsync(Coordinator, 9702), Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await StatusAsync(Coordinator, 9703), Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await StatusAsync(GentsAdmin, 9703), Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await StatusAsync(GentsAdmin, 9702), Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await StatusAsync(LadiesAdmin, 9703), Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await StatusAsync(LadiesAdmin, 9701), Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await StatusAsync(Both, 9703), Is.EqualTo(HttpStatusCode.OK), "a coordinator of both genders reaches each class by its own gender");
        Assert.That(await StatusAsync(Both, 9702), Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await StatusAsync(Admin, 9704), Is.EqualTo(HttpStatusCode.NotFound), "closed");
        Assert.That(await StatusAsync(Admin, 9799), Is.EqualTo(HttpStatusCode.NotFound), "missing");
    }

    [Test]
    public async Task This_week_shows_a_teacher_mobile_only_to_a_caller_who_may_look_teachers_up()
    {
        await TestDatabase.ExecuteAsync("update membership.member_profiles set mobile = '+910000999' where gender = '1'");
        var plain = await MembershipTestKit.AddMemberAsync(901715, "Rt Reports Only", "1");
        await TestDatabase.ExecuteAsync($"insert into access.user_permissions (user_id, permission) values ({plain}, 'reports:read:all')");

        var seen = await kit.SendAsync(Admin, HttpMethod.Get, "/reports/this-week");
        Assert.That(seen.Json!["stages"]!["alignment"]!.AsArray().Select(r => r!["teacherMobile"]?.GetValue<string>()), Has.All.EqualTo("+910000999"));

        var hidden = await kit.SendAsync(901715, HttpMethod.Get, "/reports/this-week");
        Assert.That(hidden.Status, Is.EqualTo(HttpStatusCode.OK), hidden.Body);
        Assert.That(hidden.Json!["stages"]!["alignment"]!.AsArray(), Is.Not.Empty);
        Assert.That(hidden.Json["stages"]!["alignment"]!.AsArray().Select(r => r!["teacherMobile"]), Has.All.Null);
    }

    [Test]
    public async Task Registrations_lists_only_the_waiting_people_of_the_gender_asked_for_newest_first_and_a_coordinator_is_locked_to_the_gender_of_their_classes()
    {
        var older = await MembershipTestKit.AddMemberAsync(901711, "Rt Waiting Older", "1");
        var newer = await MembershipTestKit.AddMemberAsync(901712, "Rt Waiting Newer", "1");
        var woman = await MembershipTestKit.AddMemberAsync(901713, "Rt Waiting Woman", "2");
        Assert.That(older + newer + woman, Is.GreaterThan(0));
        await TestDatabase.ExecuteAsync(
            "insert into membership.class_registrations (token, status, created_at) values "
            + "(901711, 'Pending', timestamptz '2025-04-01 10:00:00+00'), (901712, 'Pending', timestamptz '2025-04-02 10:00:00+00'), (901713, 'Pending', timestamptz '2025-04-03 10:00:00+00')");

        var gents = await kit.SendAsync(GentsAdmin, HttpMethod.Get, "/reports/registrations?gender=2");
        Assert.That(gents.Status, Is.EqualTo(HttpStatusCode.OK), gents.Body);
        Assert.That(gents.Json!["gender"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(Ids(gents.Json["registrants"], "token"), Is.EqualTo((int[])[901712, 901711]));

        var ladies = await kit.SendAsync(LadiesAdmin, HttpMethod.Get, "/reports/registrations?gender=1");
        Assert.That(Ids(ladies.Json!["registrants"], "token"), Is.EqualTo((int[])[901713]));

        var assigned = await kit.SendAsync(Coordinator, HttpMethod.Get, "/reports/registrations?gender=2");
        Assert.That(assigned.Status, Is.EqualTo(HttpStatusCode.OK), assigned.Body);
        Assert.That(assigned.Json!["gender"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(Ids(assigned.Json["registrants"], "token"), Is.EqualTo((int[])[901712, 901711]));

        var both = await kit.SendAsync(Both, HttpMethod.Get, "/reports/registrations?gender=2");
        Assert.That(Ids(both.Json!["registrants"], "token"), Is.EqualTo((int[])[901713]));
    }

    [Test]
    public async Task The_student_card_shows_only_the_classes_in_the_callers_reach_and_never_a_closed_class()
    {
        const int Student = 901714;
        Assert.That(await MembershipTestKit.AddMemberAsync(Student, "Rt Student", "1"), Is.GreaterThan(0));
        await TestDatabase.ExecuteAsync(
            "insert into classes.class_students (class_id, token_no, joined_on, status) select id, 901714, date '2025-01-06', 'A' from classes.classes");

        async Task<string[]> CodesAsync(int caller)
        {
            var card = await kit.SendAsync(caller, HttpMethod.Get, "/students/901714");
            return card.Status == HttpStatusCode.OK ? card.Json!["classes"]!.AsArray().Select(c => c!["code"]!.GetValue<string>()).ToArray() : [];
        }

        Assert.That(await CodesAsync(Admin), Is.EqualTo((string[])[Assigned, OtherGents, Ladies]));
        Assert.That(await CodesAsync(GentsAdmin), Is.EqualTo((string[])[Assigned, OtherGents]));
        Assert.That(await CodesAsync(LadiesAdmin), Is.EqualTo((string[])[Ladies]));
        Assert.That(await CodesAsync(Coordinator), Is.EqualTo((string[])[Assigned]));
        Assert.That(await CodesAsync(Both), Is.EqualTo((string[])[Assigned, Ladies]));
        var level = await kit.SendAsync(Admin, HttpMethod.Get, "/students/901714");
        Assert.That(level.Json!["classes"]![0]!["level"]!.GetValue<string>(), Is.EqualTo("MIQDAD"));
    }

    private static IEnumerable<int> Ids(System.Text.Json.Nodes.JsonNode? list, string field) => list!.AsArray().Select(c => c![field]!.GetValue<int>());

    /// <summary>PHP getAll: a caller whose classes:read is assigned-only sees the assigned classes in this-week, even when a named grant gives every class for reports.</summary>
    [Test]
    public async Task This_week_keeps_to_the_assigned_classes_of_a_coordinator_granted_all_reports()
    {
        const int Granted = 901708;
        var granted = await MembershipTestKit.AddMemberAsync(Granted, "Rt Granted", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({granted}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({granted}, 'reports:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (5, {Granted}, 1, 'rt level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (5, 'level', false, 3)");

        await ShowsAsync(Granted, "/reports/this-week", [Assigned], [OtherGents, Ladies, Closed]);
        Assert.That((await kit.SendAsync(Granted, HttpMethod.Get, "/reports/this-week/class/9701")).Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That((await kit.SendAsync(Granted, HttpMethod.Get, "/reports/this-week/class/9702")).Status, Is.EqualTo(HttpStatusCode.NotFound));
    }
}
