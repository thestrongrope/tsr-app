using System.Net;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The reports2 lane: the MCQ summary and adherence reports, the Quran leaderboard and the pending nudge, for callers who must see less than everything (a gender administrator, a coordinator limited to one class, a coordinator of
/// both genders, a holder of only a named grant, a plain member), and the nudge's writes (rows, one event, the 24 hour rule under simultaneous requests, the hourly limit). The Hurl files cover the contract and the PHP parity.
/// Classes: 98101 gents MIQDAD (city Solo, the coordinator's class), 98102 gents ABUZAR, 98103 gents SALMAN (first in class order, with the worst adherence: the class that would win if reach leaked), 98104 ladies MIQDAD,
/// 98105 gents MIQDAD closed, 98106 gents MIQDAD (city Solo, taught by a demo member). Every date is in March 2019.
/// </summary>
public sealed partial class TestReports2Tests
{
    private const int Super = 921001;
    private const int GentsAdmin = 921002;
    private const int LadiesAdmin = 921003;
    private const int OneClass = 921004;
    private const int Both = 921005;
    private const int Plain = 921006;
    private const int Named = 921007;
    private const int Grant = 921008;
    private const int Teacher = 921011;
    private const int LadiesTeacher = 921012;
    private const int OtherTeacher = 921013;
    private const int DemoTeacher = 921014;

    private const string Range = "from=2019-03-01&to=2019-03-31";
    private const string Months = "\"from\":\"03-2019\",\"to\":\"03-2019\"";

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
            "truncate platform.outbox, platform.outbound_messages, notifications.user_notifications, notifications.notifications, notifications.user_devices, "
            + "assessment.spot_quiz_responses, assessment.spot_quiz_questions, assessment.spot_quizzes, assessment.standard_mcqs, "
            + "classes.class_attendance, classes.class_sessions, classes.class_schedules, classes.class_students, classes.classes restart identity cascade; "
            + "truncate access.class_access_rule_conditions, access.class_access_rules, access.user_permissions restart identity cascade");
        var ids = new Dictionary<int, int>();
        foreach (var (token, name, gender) in new (int, string, string)[]
        {
            (Super, "T2 Super", "1"), (GentsAdmin, "T2 Gents Admin", "1"), (LadiesAdmin, "T2 Ladies Admin", "2"), (OneClass, "T2 One Class", "1"), (Both, "T2 Both", "1"),
            (Plain, "T2 Plain", "1"), (Named, "T2 Named", "1"), (Grant, "T2 Grant", "1"), (Teacher, "T2 Teacher", "1"), (LadiesTeacher, "T2 Ladies Teacher", "2"),
            (OtherTeacher, "T2 Other Teacher", "1"), (DemoTeacher, "T2 Demo Teacher", "1"),
            (921021, "T2 Student 1", "1"), (921022, "T2 Student 2", "1"), (921023, "T2 Student 3", "1"), (921024, "T2 Student 4", "2"), (921025, "T2 Student 5", "1"),
        })
        {
            ids[token] = await MembershipTestKit.AddMemberAsync(token, name, gender);
        }

        await TestDatabase.ExecuteAsync($"update identity.users set email = 'demo921014@demo.invalid' where token = {DemoTeacher}");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({ids[Super]}, 1), ({ids[GentsAdmin]}, 3), ({ids[LadiesAdmin]}, 4), ({ids[OneClass]}, 5), ({ids[Both]}, 5), ({ids[Grant]}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({ids[Named]}, 'quran-leaderboard:read:all'), ({ids[Grant]}, 'quran-leaderboard:read:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (1, {OneClass}, 1, 'solo'), (2, {Both}, 1, 'solo'), (3, {Both}, 2, 'ladies'), (4, {Grant}, 1, 'solo'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, value) values (1, 'city', false, 'Solo'), (2, 'city', false, 'Solo'), (3, 'city', false, 'Lady'), (4, 'city', false, 'Solo'); "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (2, 'AB', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, city, created_by, started_on) values "
            + $"(98101, 'T2-G-1', 1, 'l1', 'One', 3, {Teacher}, 1, 'Offline', 'A', 'Solo', {Super}, date '2019-01-07'), "
            + $"(98102, 'T2-G-2', 1, 'l2', 'Two', 2, {Teacher}, 1, 'Offline', 'A', 'Other', {Super}, date '2019-01-07'), "
            + $"(98103, 'T2-G-3', 1, 'l3', 'Three', 1, {OtherTeacher}, 1, 'Offline', 'A', 'Else', {Super}, date '2019-01-07'), "
            + $"(98104, 'T2-L-4', 1, 'l4', 'Four', 3, {LadiesTeacher}, 2, 'Offline', 'A', 'Lady', {Super}, date '2019-01-07'), "
            + $"(98105, 'T2-G-5', 1, 'l5', 'Five', 3, {Teacher}, 1, 'Offline', 'I', 'Solo', {Super}, date '2019-01-07'), "
            + $"(98106, 'T2-G-6', 1, 'l6', 'Six', 3, {DemoTeacher}, 1, 'Offline', 'A', 'Solo', {Super}, date '2019-01-07'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, status) values "
            + "(98101, 921021, date '2019-01-07', 'A'), (98102, 921022, date '2019-01-07', 'A'), (98103, 921023, date '2019-01-07', 'A'), (98104, 921024, date '2019-01-07', 'A'), (98105, 921025, date '2019-01-07', 'A'); "
            + $"insert into classes.class_sessions (id, class_id, teacher, conducted_on, conducted, created_by) values (1, 98101, {Teacher}, date '2019-03-10', 1, {Teacher}), (2, 98102, {Teacher}, date '2019-03-10', 1, {Teacher}), "
            + $"(3, 98103, {OtherTeacher}, date '2019-03-10', 1, {Teacher}), (4, 98104, {LadiesTeacher}, date '2019-03-10', 1, {Teacher}), (5, 98105, {Teacher}, date '2019-03-10', 1, {Teacher}); "
            + "insert into classes.class_attendance (session_id, token, extra_student, present, recitation) values (1, 921021, 0, 1, 500), (2, 921022, 0, 1, 400), (3, 921023, 0, 1, 900), (4, 921024, 0, 1, 700), (5, 921025, 0, 1, 600)");
        await SeedMcqsAsync();
    }

    // Standard MCQs per level; each of the classes 98101 to 98105 conducted one (98103's copy has no code, so it conducted none: 0 percent). 98101, 98103, 98104 and 98106 also hold an unpublished copy of a second MCQ (pending),
    // which is what a nudge reminds about. A quiz in March 2019 with one question and one answer per class, topic "Tp".
    private static async Task SeedMcqsAsync() => await TestDatabase.ExecuteAsync(
        "insert into assessment.standard_mcqs (code, language_id, level_id, topic, subject, lesson, name, sort_order, created_by) values "
        + "('T2A', 1, 3, 'Tp', 'S', 'L', 'Three A', 1, 921001), ('T2B', 1, 3, 'Tp', 'S', 'L', 'Three B', 2, 921001), ('T2C', 1, 2, 'Tp', 'S', 'L', 'Two A', 1, 921001), ('T2D', 1, 1, 'Tp', 'S', 'L', 'One A', 1, 921001), ('T2E', 1, 1, 'Tp', 'S', 'L', 'One B', 2, 921001); "
        + "insert into assessment.spot_quizzes (id, code, mcq_code, language_id, level_id, name, class_id, restrict_to_class, topic, published_at, published_by, created_by) values "
        + "(1, 'T2Q1', 'T2A', 1, 3, 'q1', 98101, 1, 'Tp', timestamptz '2019-03-10 10:00:00+00', 921011, 921011), (2, 'T2Q2', 'T2C', 1, 2, 'q2', 98102, 1, 'Tp', timestamptz '2019-03-10 10:00:00+00', 921011, 921011), "
        + "(3, 'T2Q3', null, 1, 1, 'q3', 98103, 1, 'Tp', timestamptz '2019-03-10 10:00:00+00', 921013, 921013), (4, 'T2Q4', 'T2A', 1, 3, 'q4', 98104, 1, 'Tp', timestamptz '2019-03-10 10:00:00+00', 921012, 921012), "
        + "(5, 'T2Q5', 'T2A', 1, 3, 'q5', 98105, 1, 'Tp', timestamptz '2019-03-10 10:00:00+00', 921011, 921011), "
        + "(6, 'T2Q6', 'T2B', 1, 3, 'q6', 98101, 1, null, null, null, 921011), (7, 'T2Q7', 'T2E', 1, 1, 'q7', 98103, 1, null, null, null, 921013), (8, 'T2Q8', 'T2B', 1, 3, 'q8', 98104, 1, null, null, null, 921012), "
        + "(9, 'T2Q9', 'T2B', 1, 3, 'q9', 98106, 1, null, null, null, 921014); "
        + "insert into assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, answer) values "
        + "(1, 1, false, 'q', 'a', 'b', 1), (2, 2, false, 'q', 'a', 'b', 1), (3, 3, false, 'q', 'a', 'b', 1), (4, 4, false, 'q', 'a', 'b', 1), (5, 5, false, 'q', 'a', 'b', 1); "
        + "insert into assessment.spot_quiz_responses (spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct) values "
        + "(1, 1, 921021, 'a', 'a', 1), (2, 2, 921022, 'a', 'a', 1), (3, 3, 921023, 'a', 'a', 1), (4, 4, 921024, 'a', 'a', 1), (5, 5, 921025, 'a', 'a', 1); "
        + "insert into notifications.user_devices (token, device_id, registered_at, last_accessed_at) values "
        + "(921011, 't2-dev-1', now(), now()), (921011, 't2-dev-2', now(), now()), (921013, 't2-dev-3', now(), now()), (921014, 't2-dev-demo', now(), now())");

    [GeneratedRegex("T2-[GL]-[0-9]")]
    private static partial Regex ClassCode();

    private async Task<string[]> CodesAsync(int caller, string url, HttpStatusCode expected = HttpStatusCode.OK)
    {
        var reply = await kit.SendAsync(caller, HttpMethod.Get, url);
        Assert.That(reply.Status, Is.EqualTo(expected), url + " " + reply.Body);
        return [.. ClassCode().Matches(reply.Body).Select(m => m.Value).Distinct().Order(StringComparer.Ordinal)];
    }

    private async Task<string[]> CodesOfFileAsync(int caller, string url)
    {
        var file = await kit.DownloadAsync(caller, url);
        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), url + " " + file.Text);
        return [.. ClassCode().Matches(file.Bytes.Length > 1 && file.Bytes[0] == 'P' && file.Bytes[1] == 'K' ? string.Join('\n', file.Cells()) : file.Text).Select(m => m.Value).Distinct().Order(StringComparer.Ordinal)];
    }

    // ---- MCQ summary ----

    [TestCase("/reports/mcq-summary?" + Range)]
    [TestCase("/reports/mcq-summary/download-all?" + Range)]
    public async Task Summary_list_and_csv_hold_only_the_classes_in_reach_and_of_the_gender_asked_for(string route)
    {
        Assert.That(await CodesAsync(OneClass, route + "&gender=2"), Is.EqualTo((string[])["T2-G-1"]), "a coordinator of one class, whatever gender is asked");
        Assert.That(await CodesAsync(GentsAdmin, route + "&gender=2"), Is.EqualTo((string[])["T2-G-1", "T2-G-2", "T2-G-3"]), "the gender lock wins; the closed class never");
        Assert.That(await CodesAsync(LadiesAdmin, route + "&gender=1"), Is.EqualTo((string[])["T2-L-4"]));
        Assert.That(await CodesAsync(Both, route + "&gender=1"), Is.EqualTo((string[])["T2-G-1"]));
        Assert.That(await CodesAsync(Both, route + "&gender=2"), Is.EqualTo((string[])["T2-L-4"]));
        Assert.That(await CodesAsync(Super, route), Is.EqualTo((string[])["T2-G-1", "T2-G-2", "T2-G-3"]));
    }

    [Test]
    public async Task Summary_class_routes_answer_with_an_empty_class_outside_reach_and_zero_or_a_word_means_the_first_class_inside_reach()
    {
        async Task<JsonNode> ClassAsync(int caller, string id)
        {
            var reply = await kit.SendAsync(caller, HttpMethod.Get, $"/reports/mcq-summary/{id}?{Range}");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
            return reply.Json!;
        }

        Assert.That((await ClassAsync(OneClass, "98101"))["students"]!.AsArray(), Has.Count.EqualTo(1));
        foreach (var outside in new[] { "98102", "98103", "98104", "98105", "99999999", "-1" })
        {
            var body = await ClassAsync(OneClass, outside);
            Assert.That(body["mcqs"]!.GetValue<int>(), Is.Zero, outside);
            Assert.That(body["students"]!.AsArray(), Is.Empty, outside);
        }

        // 98103 (SALMAN) would be the first class of the whole report: a coordinator is never handed it.
        foreach (var first in new[] { "0", "abc" })
        {
            var body = await ClassAsync(OneClass, first);
            Assert.That(body["students"]!.AsArray().Select(s => s!["name"]!.GetValue<string>()), Is.EqualTo((string[])["T2 Student 1"]), first);
        }

        var admin = await ClassAsync(GentsAdmin, "0");
        Assert.That(admin["students"]!.AsArray().Select(s => s!["name"]!.GetValue<string>()), Is.EqualTo((string[])["T2 Student 3"]), "an administrator gets the first class in order");
        Assert.That((await ClassAsync(GentsAdmin, "98104"))["students"]!.AsArray(), Is.Empty, "the other gender's class");
    }

    [Test]
    public async Task Summary_class_download_holds_only_the_students_of_the_class_in_reach()
    {
        Assert.That(string.Join(' ', await CodesOfFileAsync(OneClass, $"/reports/mcq-summary/98101/download?format=xlsx&{Range}")), Is.Empty, "a student's name, not a class code");
        var own = await kit.DownloadAsync(OneClass, $"/reports/mcq-summary/98101/download?format=xlsx&{Range}");
        Assert.That(string.Join('\n', own.Cells()), Does.Contain("T2 Student 1"));
        var other = await kit.DownloadAsync(OneClass, $"/reports/mcq-summary/98103/download?format=xlsx&{Range}");
        Assert.That(string.Join('\n', other.Cells()), Does.Not.Contain("T2 Student 3"));
        var zero = await kit.DownloadAsync(OneClass, $"/reports/mcq-summary/0/download?format=xlsx&{Range}");
        Assert.That(string.Join('\n', zero.Cells()), Does.Contain("T2 Student 1").And.Not.Contain("T2 Student 3"));
    }

    [Test]
    public async Task Summary_refuses_a_caller_without_reports_read_and_the_other_gender_to_a_gender_administrator_is_the_own_gender()
    {
        foreach (var caller in new[] { Plain, Named })
        {
            var reply = await kit.SendAsync(caller, HttpMethod.Get, $"/reports/mcq-summary?{Range}");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden));
            Assert.That(reply.Detail, Is.EqualTo("You do not have permission to do that"));
        }

        var anonymous = await kit.DownloadAsync(Plain, $"/reports/mcq-summary/download-all?{Range}", signedIn: false);
        Assert.That(anonymous.Status, Is.EqualTo(HttpStatusCode.Unauthorized));
    }

    // ---- MCQ adherence ----

    [TestCase("/reports/mcq-adherence")]
    [TestCase("/reports/mcq-adherence/download-all")]
    public async Task Adherence_list_and_csv_hold_only_the_classes_in_reach_and_of_the_gender_asked_for(string route)
    {
        Assert.That(await CodesAsync(OneClass, route + "?gender=2"), Is.EqualTo((string[])["T2-G-1", "T2-G-6"]));
        Assert.That(await CodesAsync(GentsAdmin, route + "?gender=2"), Is.EqualTo((string[])["T2-G-1", "T2-G-2", "T2-G-3", "T2-G-6"]));
        Assert.That(await CodesAsync(LadiesAdmin, route + "?gender=1"), Is.EqualTo((string[])["T2-L-4"]));
        Assert.That(await CodesAsync(Both, route + "?gender=1"), Is.EqualTo((string[])["T2-G-1", "T2-G-6"]));
        Assert.That(await CodesAsync(Both, route + "?gender=2"), Is.EqualTo((string[])["T2-L-4"]));
    }

    [Test]
    public async Task Adherence_class_routes_answer_with_an_empty_class_outside_reach_and_zero_or_a_word_means_the_worst_class_inside_reach()
    {
        async Task<JsonNode> ClassAsync(int caller, string id)
        {
            var reply = await kit.SendAsync(caller, HttpMethod.Get, $"/reports/mcq-adherence/{id}");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
            return reply.Json!;
        }

        Assert.That((await ClassAsync(OneClass, "98101"))["mcqs"]!.AsArray(), Has.Count.EqualTo(2));
        foreach (var outside in new[] { "98102", "98103", "98104", "98105", "99999999", "-1" })
        {
            var body = await ClassAsync(OneClass, outside);
            Assert.That(body["expected"]!.GetValue<int>(), Is.Zero, outside);
            Assert.That(body["mcqs"]!.AsArray(), Is.Empty, outside);
        }

        // 98103 and 98106 both conduct nothing: the coordinator's worst class is 98106 (MIQDAD, "Three A"); an administrator's is 98103 (SALMAN, "One A"), first in class order.
        async Task<string> FirstMcqAsync(int caller, string id) => (await ClassAsync(caller, id))["mcqs"]![0]!["name"]!.GetValue<string>();

        foreach (var worst in new[] { "0", "abc" })
        {
            Assert.That(await FirstMcqAsync(OneClass, worst), Is.EqualTo("Three A"), worst);
        }

        Assert.That(await FirstMcqAsync(GentsAdmin, "0"), Is.EqualTo("One A"));
    }

    [Test]
    public async Task Adherence_class_download_holds_only_the_class_in_reach()
    {
        var own = await kit.DownloadAsync(OneClass, "/reports/mcq-adherence/98101/download?format=xlsx");
        Assert.That(string.Join('\n', own.Cells()), Does.Contain("Three A"));
        var outside = await kit.DownloadAsync(OneClass, "/reports/mcq-adherence/98102/download?format=xlsx");
        Assert.That(string.Join('\n', outside.Cells()), Does.Not.Contain("Two A"));
        var zero = await kit.DownloadAsync(OneClass, "/reports/mcq-adherence/0/download?format=xlsx");
        Assert.That(string.Join('\n', zero.Cells()), Does.Contain("Three A").And.Not.Contain("One A"));
    }

    // ---- the leaderboard ----

    private async Task<int[]> LeaderboardTokensAsync(int caller, string query, HttpStatusCode expected = HttpStatusCode.OK)
    {
        var reply = await kit.SendAsync(caller, HttpMethod.Get, $"/reports/quran-leaderboard?{Range}&minimum=0{query}");
        Assert.That(reply.Status, Is.EqualTo(expected), reply.Body);
        return expected == HttpStatusCode.OK ? [.. reply.Json!["students"]!.AsArray().Select(s => s!["token"]!.GetValue<int>())] : [];
    }

    [Test]
    public async Task Leaderboard_has_its_own_permission_and_gender_lock_and_the_assigned_classes_limit_only_a_coordinator_who_holds_the_grant()
    {
        Assert.That(await LeaderboardTokensAsync(Super, string.Empty), Is.EqualTo((int[])[921023, 921021, 921022]), "gents, ranked by total, the closed class never");
        Assert.That(await LeaderboardTokensAsync(GentsAdmin, "&gender=2"), Is.EqualTo((int[])[921023, 921021, 921022]), "the gender lock wins over ?gender");
        Assert.That(await LeaderboardTokensAsync(LadiesAdmin, "&gender=1"), Is.EqualTo((int[])[921024]));
        Assert.That(await LeaderboardTokensAsync(Super, "&gender=2"), Is.EqualTo((int[])[921024]));

        // Finding 3: a holder of only the named grant has no reports:read, so no class limit applies (as PHP).
        Assert.That(await LeaderboardTokensAsync(Named, string.Empty), Is.EqualTo((int[])[921023, 921021, 921022]));
        // A coordinator who also holds the grant is limited to the assigned classes (as PHP).
        Assert.That(await LeaderboardTokensAsync(Grant, string.Empty), Is.EqualTo((int[])[921021]));

        foreach (var caller in new[] { OneClass, Both, Plain })
        {
            var reply = await kit.SendAsync(caller, HttpMethod.Get, $"/reports/quran-leaderboard?{Range}");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden), $"caller {caller}");
            Assert.That(reply.Detail, Is.EqualTo("You do not have permission to do that"));
        }
    }

    [Test]
    public async Task Leaderboard_ranks_are_global_and_a_member_in_two_classes_appears_twice_with_the_same_rank()
    {
        await TestDatabase.ExecuteAsync(
            "insert into classes.class_students (class_id, token_no, joined_on, status) values (98102, 921021, date '2019-01-07', 'A'); "
            + "insert into classes.class_attendance (session_id, token, extra_student, present, recitation) values (4, 921024, 0, 1, 1000)");
        var reply = await kit.SendAsync(Super, HttpMethod.Get, $"/reports/quran-leaderboard?{Range}&minimum=0");
        var rows = reply.Json!["students"]!.AsArray().Select(s => (Token: s!["token"]!.GetValue<int>(), Rank: s["rank"]!.GetValue<int>(), Class: s["class"]!.GetValue<string>())).ToList();
        Assert.That(rows.Where(r => r.Token == 921021).Select(r => (r.Rank, r.Class)).Order().ToArray(), Is.EqualTo(new[] { (4, "T2-G-1"), (4, "T2-G-2") }), "921024 (1700, ladies), 921023 (900) and 921025 (600, a closed class) rank above, so 921021 is fourth");
        Assert.That(rows.Single(r => r.Token == 921023).Rank, Is.EqualTo(2), "the ranking counts the other gender's member");
    }

    [Test]
    public async Task Leaderboard_download_holds_only_the_rows_the_caller_may_see()
    {
        var all = await kit.DownloadAsync(Super, $"/reports/quran-leaderboard/download?format=xlsx&{Range}");
        Assert.That(string.Join('\n', all.Cells()), Does.Contain("T2 Student 1").And.Contain("T2 Student 3").And.Not.Contain("T2 Student 5"));
        var granted = await kit.DownloadAsync(Grant, $"/reports/quran-leaderboard/download?format=xlsx&{Range}");
        Assert.That(string.Join('\n', granted.Cells()), Does.Contain("T2 Student 1").And.Not.Contain("T2 Student 3"));
        var refused = await kit.DownloadAsync(OneClass, $"/reports/quran-leaderboard/download?format=xlsx&{Range}");
        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.Forbidden));
    }

    [Test]
    public async Task Leaderboard_lists_the_top_100_rows_with_the_total_of_all_and_the_download_holds_every_row()
    {
        await TestDatabase.ExecuteAsync(
            "insert into identity.users (token, email, firebase_uid) select 930000 + n, 'bulk' || n || '@example.invalid', 'uid-bulk' || n from generate_series(1, 105) n; "
            + "insert into membership.member_profiles (user_id, name, gender) select u.id, 'T2 Bulk ' || (u.token - 930000), '1' from identity.users u where u.token > 930000; "
            + "insert into classes.class_students (class_id, token_no, joined_on, status) select 98101, token, date '2019-01-07', 'A' from identity.users where token > 930000; "
            + "insert into classes.class_attendance (session_id, token, extra_student, present, recitation) select 1, token, 0, 1, 1000 + (token - 930000) from identity.users where token > 930000");
        var top = await kit.SendAsync(Super, HttpMethod.Get, $"/reports/quran-leaderboard?{Range}");
        Assert.That(top.Status, Is.EqualTo(HttpStatusCode.OK), top.Body);
        Assert.That(top.Json!["students"]!.AsArray(), Has.Count.EqualTo(100));
        Assert.That(top.Json["total"]!.GetValue<int>(), Is.EqualTo(105 + 3));
        var file = await kit.DownloadAsync(Super, $"/reports/quran-leaderboard/download?format=xlsx&{Range}");
        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK));
        using var book = file.Workbook();
        Assert.That(book.Worksheets.First().RowsUsed().Count(r => r.Cell(2).GetString().StartsWith("T2 ", StringComparison.Ordinal)), Is.EqualTo(105 + 3), "every ranked row, no cut");
    }

    // ---- the nudge ----

    private static string Nudge(int teacher, bool send) => $"{{\"teacher\":{teacher},{Months}{(send ? ",\"send\":true" : string.Empty)}}}";

    [Test]
    public async Task A_dry_run_writes_nothing_and_a_send_writes_the_notification_the_inbox_row_the_queued_pushes_and_one_event()
    {
        var dry = await kit.SendAsync(OneClass, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, false));
        Assert.That(dry.Status, Is.EqualTo(HttpStatusCode.OK), dry.Body);
        Assert.That(dry.Json!["sent"]!.GetValue<bool>(), Is.False);
        Assert.That(await MembershipTestKit.CountAsync("notifications.notifications"), Is.Zero);
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.teacher_nudged'"), Is.Zero);

        var sent = await kit.SendAsync(OneClass, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, true));
        Assert.That(sent.Status, Is.EqualTo(HttpStatusCode.OK), sent.Body);
        Assert.That(sent.Json!["sent"]!.GetValue<bool>(), Is.True);
        Assert.That(sent.Json["deviceCount"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(sent.Json["body"]!.GetValue<string>(), Does.Contain("T2-G-1").And.Not.Contain("T2-G-2"), "only the classes in the coordinator's reach");

        Assert.That(await MembershipTestKit.CountAsync("notifications.notifications", $"created_by = {OneClass}"), Is.EqualTo(1));
        var criteria = await TestDatabase.ScalarAsync<string>("select target_audience_criteria::text from notifications.notifications", TestDatabase.OwnerConnection);
        var node = JsonNode.Parse(criteria)!;
        Assert.That(node["type"]!.GetValue<string>(), Is.EqualTo("CC_NUDGE"));
        Assert.That(node["teacher"]!.GetValue<int>(), Is.EqualTo(Teacher));
        Assert.That(node["classes"]!.AsArray().Select(c => c!.GetValue<int>()), Is.EqualTo((int[])[98101]));
        Assert.That(await MembershipTestKit.CountAsync("notifications.user_notifications", $"user_token = {Teacher}"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "recipient in ('t2-dev-1', 't2-dev-2') and channel = 'push'"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.teacher_nudged'"), Is.EqualTo(1));
        var data = await TestDatabase.ScalarAsync<string>("select payload::text from platform.outbound_messages order by id limit 1", TestDatabase.OwnerConnection);
        var push = JsonNode.Parse(data)!["data"]!;
        Assert.That(push["type"]!.GetValue<string>(), Is.EqualTo("cc_reminder"));
        Assert.That(push["class_ids"]!.GetValue<string>(), Is.EqualTo("98101"));
    }

    [Test]
    public async Task A_second_send_within_24_hours_is_429_writes_nothing_more_and_a_dry_run_then_says_alreadyReminded()
    {
        Assert.That((await kit.SendAsync(Both, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, true))).Status, Is.EqualTo(HttpStatusCode.OK));
        var again = await kit.SendAsync(Both, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, true));
        Assert.That(again.Status, Is.EqualTo(HttpStatusCode.TooManyRequests));
        Assert.That(again.Detail, Is.EqualTo("This teacher was already reminded in the last 24 hours"));
        Assert.That(await MembershipTestKit.CountAsync("notifications.notifications"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.teacher_nudged'"), Is.EqualTo(1));

        var dry = await kit.SendAsync(Both, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, false));
        Assert.That(dry.Json!["alreadyReminded"]!.GetValue<bool>(), Is.True);
        Assert.That(dry.Json["lastReminded"]!.GetValue<string>(), Is.Not.Empty);

        await TestDatabase.ExecuteAsync("update notifications.notifications set sent_at = now() - interval '25 hours'");
        var later = await kit.SendAsync(Both, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, true));
        Assert.That(later.Status, Is.EqualTo(HttpStatusCode.OK), "after 24 hours it is allowed again");
    }

    [Test]
    public async Task Simultaneous_sends_to_one_teacher_make_exactly_one_notification_one_inbox_row_and_one_event()
    {
        var answers = await Task.WhenAll(Enumerable.Range(0, 12).Select(_ => kit.SendAsync(Super, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, true))));
        Assert.That(answers.Count(a => a.Status == HttpStatusCode.OK), Is.EqualTo(1), string.Join(" | ", answers.Select(a => (int)a.Status)));
        Assert.That(answers.Count(a => a.Status == HttpStatusCode.TooManyRequests), Is.EqualTo(11));
        Assert.That(await MembershipTestKit.CountAsync("notifications.notifications"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("notifications.user_notifications"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.teacher_nudged'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "channel = 'push'"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_sender_may_send_thirty_reminders_an_hour_and_the_thirty_first_is_429()
    {
        for (var i = 1; i <= 30; i++)
        {
            var ok = await kit.SendAsync(GentsAdmin, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, true));
            Assert.That(ok.Status, Is.EqualTo(HttpStatusCode.OK), $"send {i}: {ok.Body}");
            await TestDatabase.ExecuteAsync("delete from notifications.user_notifications; delete from notifications.notifications");
        }

        var over = await kit.SendAsync(GentsAdmin, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, true));
        Assert.That(over.Status, Is.EqualTo(HttpStatusCode.TooManyRequests));
        Assert.That(over.Detail, Is.EqualTo("Too many reminders; try again later"));
        Assert.That(await MembershipTestKit.CountAsync("notifications.notifications"), Is.Zero);
    }

    [Test]
    public async Task A_teacher_outside_the_reach_the_gender_or_with_nothing_pending_gets_the_same_422_and_nothing_is_written()
    {
        const string Same = "Nothing is pending for this teacher";
        async Task AssertRefusedAsync(int caller, int teacher, string why)
        {
            foreach (var send in new[] { false, true })
            {
                var reply = await kit.SendAsync(caller, HttpMethod.Post, "/reports/pending/nudge", Nudge(teacher, send));
                Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), why + " " + reply.Body);
                Assert.That(reply.Detail, Is.EqualTo(Same), why);
            }
        }

        await AssertRefusedAsync(OneClass, OtherTeacher, "a teacher of a class outside the assigned one");
        await AssertRefusedAsync(OneClass, LadiesTeacher, "a teacher of the other gender");
        await AssertRefusedAsync(GentsAdmin, LadiesTeacher, "a gender administrator and the other gender's teacher");
        await AssertRefusedAsync(Super, 921099, "a member who teaches nothing");
        await AssertRefusedAsync(Super, Plain, "a member who is not a teacher");
        Assert.That(await MembershipTestKit.CountAsync("notifications.notifications"), Is.Zero);
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.teacher_nudged'"), Is.Zero);

        Assert.That((await kit.SendAsync(Super, HttpMethod.Post, "/reports/pending/nudge", Nudge(OtherTeacher, false))).Status, Is.EqualTo(HttpStatusCode.OK), "an administrator reaches the same teacher");
    }

    [Test]
    public async Task A_demo_teacher_gets_the_notification_and_the_inbox_row_but_no_push_and_a_teacher_without_a_device_none()
    {
        var demo = await kit.SendAsync(Super, HttpMethod.Post, "/reports/pending/nudge", Nudge(DemoTeacher, true));
        Assert.That(demo.Status, Is.EqualTo(HttpStatusCode.OK), demo.Body);
        Assert.That(demo.Json!["deviceCount"]!.GetValue<int>(), Is.Zero);
        Assert.That(await MembershipTestKit.CountAsync("notifications.user_notifications", $"user_token = {DemoTeacher}"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbound_messages", "recipient = 't2-dev-demo'"), Is.Zero);

        var none = await kit.SendAsync(LadiesAdmin, HttpMethod.Post, "/reports/pending/nudge?gender=2", Nudge(LadiesTeacher, true));
        Assert.That(none.Status, Is.EqualTo(HttpStatusCode.OK), none.Body);
        Assert.That(none.Json!["deviceCount"]!.GetValue<int>(), Is.Zero);
        Assert.That(await MembershipTestKit.CountAsync("notifications.user_notifications", $"user_token = {LadiesTeacher}"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_long_list_of_classes_is_cut_at_500_characters_with_the_number_left_out()
    {
        var rows = string.Join(", ", Enumerable.Range(1, 40).Select(i => $"({99000 + i}, 'T2-LONG-{i:00}-{new string('x', 20)}', 1, 'l{99000 + i}', 'Long', 3, {Teacher}, 1, 'Offline', 'A', 'Solo', {Super}, date '2019-01-07')"));
        await TestDatabase.ExecuteAsync($"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, city, created_by, started_on) values {rows}");
        await TestDatabase.ExecuteAsync(
            string.Join("; ", Enumerable.Range(1, 40).Select(i => $"insert into assessment.spot_quizzes (id, code, mcq_code, language_id, level_id, name, class_id, restrict_to_class, created_by) values ({500 + i}, 'T2LQ{i}', 'T2B', 1, 3, 'long', {99000 + i}, 1, {Teacher})")));
        var reply = await kit.SendAsync(Super, HttpMethod.Post, "/reports/pending/nudge", Nudge(Teacher, false));
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var body = reply.Json!["body"]!.GetValue<string>();
        Assert.That(new System.Globalization.StringInfo(body).LengthInTextElements, Is.LessThanOrEqualTo(500));
        Assert.That(body, Does.Match("…and [0-9]+ more classes"));
    }
}
