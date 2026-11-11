using System.Net;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Platform.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// The class reports of batch B5b (active teachers, this week, students, tsr, pending) for callers who are NOT the super administrator: a gender administrator asking for the other gender, a coordinator limited to one
/// assigned class, and a coordinator with classes of both genders asking for one gender must each see only their classes. The Hurl files cover the contract.
/// </summary>
public sealed partial class ReportsB5bTests
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
    private readonly FakePdfRenderer renderer = new();

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit(services => services.AddSingleton<IPdfRenderer>(renderer));

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
        await MembershipTestKit.AddMemberAsync(901714, "Rt Waiting Other Class", "1");
        Assert.That(older + newer + woman, Is.GreaterThan(0));
        await TestDatabase.ExecuteAsync(
            "insert into membership.class_registrations (token, for_classid, status, created_at) values "
            + "(901711, 9701, 'Pending', timestamptz '2025-04-01 10:00:00+00'), (901712, null, 'Pending', timestamptz '2025-04-02 10:00:00+00'), (901713, 9703, 'Pending', timestamptz '2025-04-03 10:00:00+00'), "
            + "(901714, 9702, 'Pending', timestamptz '2025-04-04 10:00:00+00')");

        var gents = await kit.SendAsync(GentsAdmin, HttpMethod.Get, "/reports/registrations?gender=2");
        Assert.That(gents.Status, Is.EqualTo(HttpStatusCode.OK), gents.Body);
        Assert.That(gents.Json!["gender"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(Ids(gents.Json["registrants"], "token"), Is.EqualTo((int[])[901714, 901712, 901711]));

        var ladies = await kit.SendAsync(LadiesAdmin, HttpMethod.Get, "/reports/registrations?gender=1");
        Assert.That(Ids(ladies.Json!["registrants"], "token"), Is.EqualTo((int[])[901713]));

        var assigned = await kit.SendAsync(Coordinator, HttpMethod.Get, "/reports/registrations?gender=2");
        Assert.That(assigned.Status, Is.EqualTo(HttpStatusCode.OK), assigned.Body);
        Assert.That(assigned.Json!["gender"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(Ids(assigned.Json["registrants"], "token"), Is.EqualTo((int[])[901711]), "decided 11 Nov 2026, stricter than PHP: only the people who asked for an assigned class (9701), not an open request or another class");

        var file = await kit.SendAsync(Coordinator, HttpMethod.Get, "/reports/registrations/download?format=xlsx");
        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK));

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

    [Test]
    public async Task Pending_lists_only_the_classes_in_reach_and_the_gender_asked_for() => await AssertScopeAsync("/reports/pending?from=11-2025&to=11-2025");

    [Test]
    public async Task Pending_keeps_to_the_assigned_classes_of_a_coordinator_granted_all_reports()
    {
        const int Granted = 901709;
        var granted = await MembershipTestKit.AddMemberAsync(Granted, "Rt Granted Pending", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({granted}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({granted}, 'reports:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (6, {Granted}, 1, 'rt level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (6, 'level', false, 3)");

        await ShowsAsync(Granted, "/reports/pending?from=11-2025&to=11-2025", [Assigned], [OtherGents, Ladies, Closed]);
    }

    [Test]
    public async Task Pending_counts_the_standard_mcqs_of_language_one_for_a_class_with_no_language_and_never_a_deleted_one_or_a_deactivated_copy()
    {
        await TestDatabase.ExecuteAsync(
            "truncate assessment.spot_quizzes, assessment.standard_mcqs restart identity cascade; "
            + "update classes.classes set language_id = null where id = 9701; "
            + "insert into assessment.standard_mcqs (code, language_id, level_id, topic, subject, lesson, name, deleted_at) values "
            + "('RT-M1', 1, 3, 't', 's', 'l', 'n', null), ('RT-M2', 1, 3, 't', 's', 'l', 'n', null), ('RT-M3', 1, 3, 't', 's', 'l', 'n', now()), ('RT-M4', 2, 3, 't', 's', 'l', 'n', null); "
            + "insert into assessment.spot_quizzes (code, mcq_code, class_id, published_at) values ('RTQ1', 'rt-m1', 9701, timestamptz '2025-10-01 00:00:00+00'); "
            + "insert into assessment.spot_quizzes (code, mcq_code, class_id, published_at, deactivated_at) values ('RTQ2', 'RT-M2', 9701, null, now())");

        var answer = await kit.SendAsync(Admin, HttpMethod.Get, "/reports/pending?from=11-2025&to=11-2025");

        Assert.That(answer.Status, Is.EqualTo(HttpStatusCode.OK), answer.Body);
        var row = answer.Json!["teachers"]!.AsArray().SelectMany(t => t!["classes"]!.AsArray()).Single(c => c!["classId"]!.GetValue<int>() == 9701)!;
        Assert.That((row["mcqExpected"]!.GetValue<int>(), row["mcqConducted"]!.GetValue<int>(), row["mcqPending"]!.GetValue<int>()), Is.EqualTo((2, 1, 0)));
    }

    [Test]
    public async Task Tsr_lists_only_the_classes_in_reach_and_the_gender_asked_for() => await AssertScopeAsync("/reports/tsr?from=2025-11-01&to=2025-11-30");

    /// <summary>PHP reachFilter (not getAll): TSR follows the reports:read grant, so a named grant for every class widens a coordinator, unlike pending, weekly and this week.</summary>
    [Test]
    public async Task Tsr_follows_the_reports_grant_so_a_coordinator_granted_all_reports_sees_every_class_of_the_gender()
    {
        const int Granted = 901710;
        var granted = await MembershipTestKit.AddMemberAsync(Granted, "Rt Granted Tsr", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({granted}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({granted}, 'reports:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (7, {Granted}, 1, 'rt level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (7, 'level', false, 3)");

        await ShowsAsync(Granted, "/reports/tsr?from=2025-11-01&to=2025-11-30&gender=1", [Assigned, OtherGents], [Ladies, Closed]);
    }

    /// <summary>PHP's recitation list has no status condition: a closed class with recitation is listed there for a caller who reaches every class of a gender, and in no other list.</summary>
    [Test]
    public async Task Tsr_lists_the_recitation_of_a_closed_class_only_in_the_recitation_list()
    {
        await TestDatabase.ExecuteAsync(
            "insert into classes.class_attendance (session_id, token, extra_student, present, recitation) "
            + "select s.id, 1, 0, 1, 7 from classes.class_sessions s join classes.classes c on c.id = s.class_id where c.status = 'I'");

        var answer = await kit.SendAsync(GentsAdmin, HttpMethod.Get, "/reports/tsr?from=2025-11-01&to=2025-11-30");

        Assert.That(answer.Status, Is.EqualTo(HttpStatusCode.OK), answer.Body);
        Assert.That(answer.Json!["recitation"]!["classes"]!.AsArray().Select(c => c!["class"]!.GetValue<string>()), Does.Contain(Closed));
        foreach (var list in new[] { "conduction", "mcq", "attendance" })
        {
            Assert.That(answer.Json[list]!["classes"]!.AsArray().Select(c => c!["class"]!.GetValue<string>()), Does.Not.Contain(Closed), list);
        }

        var coordinator = await kit.SendAsync(Coordinator, HttpMethod.Get, "/reports/tsr?from=2025-11-01&to=2025-11-30");
        Assert.That(coordinator.Body, Does.Not.Contain(Closed), "a class assigned by a rule is an active one");
    }

    /// <summary>One student per class (member tokens 901731 to 901734, in 9701 to 9704), each with a mark in the class's held session and a recitation figure: who sees whose name and token.</summary>
    private static async Task SeedStudentsAsync()
    {
        for (var i = 0; i < 4; i++)
        {
            Assert.That(await MembershipTestKit.AddMemberAsync(901731 + i, "Rt Student " + (i + 1), i == 2 ? "2" : "1"), Is.GreaterThan(0));
        }

        await TestDatabase.ExecuteAsync(
            "insert into classes.class_students (class_id, token_no, joined_on, status) select 9701 + (token - 901731), token, date '2025-01-06', 'A' from generate_series(901731, 901734) token; "
            + "insert into classes.class_attendance (session_id, token, extra_student, present, recitation) "
            + "select s.id, 901731 + (s.class_id - 9701), 0, 1, 10 from classes.class_sessions s");
    }

    private async Task<string[]> StudentTokensAsync(int caller, string query)
    {
        var answer = await kit.SendAsync(caller, HttpMethod.Get, "/reports/students?from=2025-11-01&to=2025-11-30" + query);
        Assert.That(answer.Status, Is.EqualTo(HttpStatusCode.OK), answer.Body);
        return [.. answer.Json!["students"]!.AsArray().Select(s => s!["token"]!.GetValue<string>())];
    }

    [Test]
    public async Task Students_lists_only_the_students_of_the_classes_in_reach_and_the_gender_asked_for_and_never_a_closed_class()
    {
        await SeedStudentsAsync();

        Assert.That(await StudentTokensAsync(GentsAdmin, "&gender=2"), Is.EqualTo((string[])["901731", "901732"]));
        Assert.That(await StudentTokensAsync(LadiesAdmin, "&gender=1"), Is.EqualTo((string[])["901733"]));
        Assert.That(await StudentTokensAsync(Coordinator, "&gender=2"), Is.EqualTo((string[])["901731"]));
        Assert.That(await StudentTokensAsync(Both, "&gender=1"), Is.EqualTo((string[])["901731"]));
        Assert.That(await StudentTokensAsync(Both, "&gender=2"), Is.EqualTo((string[])["901733"]));
        Assert.That(await StudentTokensAsync(Admin, "&gender=1"), Is.EqualTo((string[])["901731", "901732"]));
    }

    /// <summary>PHP reachFilter (not getAll): the students report follows the reports:read grant, so a named grant for every class widens a coordinator.</summary>
    [Test]
    public async Task Students_follows_the_reports_grant_so_a_coordinator_granted_all_reports_sees_the_students_of_every_class_of_the_gender()
    {
        await SeedStudentsAsync();
        const int Granted = 901711;
        var granted = await MembershipTestKit.AddMemberAsync(Granted, "Rt Granted Students", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({granted}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({granted}, 'reports:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (8, {Granted}, 1, 'rt level 3'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (8, 'level', false, 3)");

        Assert.That(await StudentTokensAsync(Granted, "&gender=1"), Is.EqualTo((string[])["901731", "901732"]));
    }

    /// <summary>PHP's recitation leaderboard keeps the enrolments of the reports:read assigned classes when that is all the caller reaches: a student of an outside class has recitation 0 even when ranked.</summary>
    [Test]
    public async Task Students_recitation_counts_only_enrolments_in_the_assigned_classes_of_an_assigned_only_caller()
    {
        await SeedStudentsAsync();
        await TestDatabase.ExecuteAsync("insert into classes.class_students (class_id, token_no, joined_on, status) values (9702, 901731, date '2025-01-06', 'A')");

        async Task<int> RecitationAsync(int caller)
        {
            var answer = await kit.SendAsync(caller, HttpMethod.Get, "/reports/students?from=2025-11-01&to=2025-11-30&gender=1");
            return answer.Json!["students"]!.AsArray().First(s => s!["class"]!.GetValue<string>() == Assigned)!["recitation"]!.GetValue<int>();
        }

        Assert.That(await RecitationAsync(Coordinator), Is.EqualTo(10), "the student is enrolled in an assigned class too");
        await TestDatabase.ExecuteAsync("update classes.class_students set status = 'I' where class_id = 9701 and token_no = 901731");
        Assert.That(await RecitationAsync(Admin), Is.EqualTo(10), "the enrolment in 9702 still ranks");
        Assert.That(await RecitationAsync(Coordinator), Is.EqualTo(0), "the only enrolment left with status A is outside the assigned classes");
    }
}
