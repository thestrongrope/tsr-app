using System.Net;
using System.Text;
using System.Text.Json.Nodes;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Assessment.Api;
using Tsr.Assessment.Api.Domain;
using Tsr.Platform.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Test lane quizwrites: the eight assessment routes that create, copy, score, enter offline, print and publish a class's quizzes, against a real database through the API as the limited role (the PDF renderer is a fake).
/// Hurl proves the wire against PHP; this proves what it cannot see: WHO is refused (each refusal pinned to PHP's status and message, and the answer key or scores never in a refusal), the rows and events each route
/// leaves (none for a refusal), all-or-nothing, simultaneous requests, the quiz code, the standard copy view, the notification rows of a publish and the page of a sheet.
/// World: class 98201 (teacher 922001) with the class admin 922002, plain students 922003, 922011 to 922015, the removed admin 922005 and the removed student 922016; class 98202 (same teacher, student 922018, removed student 922019);
/// class 98203 (teacher 922004, student 922006, admin 922017); 98204 closed; 98205 ladies. 922007 super admin, 922008 gents admin, 922009 ladies admin, 922010 in no class.
/// </summary>
public sealed class TestQuizwritesTests
{
    private const int Teacher = 922001;
    private const int ClassAdmin = 922002;
    private const int Student = 922003;
    private const int OtherTeacher = 922004;
    private const int RemovedAdmin = 922005;
    private const int OtherStudent = 922006;
    private const int SuperAdmin = 922007;
    private const int GentsAdmin = 922008;
    private const int LadiesAdmin = 922009;
    private const int Stranger = 922010;
    private const int OfflineStudent = 922011;
    private const int PhoneStudent = 922012;
    private const int Student13 = 922013;
    private const int Student14 = 922014;
    private const int Student15 = 922015;
    private const int RemovedStudent = 922016;
    private const int OtherAdmin = 922017;
    private const int Student18 = 922018;
    private const int RemovedStudent19 = 922019;

    private const int Scores = 9720001;
    private const int OfflineSave = 9720003;
    private const int OfflinePhone = 9720004;
    private const int Sheet = 9720005;
    private const int SheetEmpty = 9720006;
    private const int PublishA = 9720007;
    private const int CopySource = 9720009;
    private const int NullTopic = 9720014;
    private const int Closed = 9720012;

    private const string NotAllowed = "You do not have permission to manage MCQs for this class";
    private const string CopyNotAllowed = "You do not have permission to copy MCQs between these classes";
    private const string Conflict = "One or more students already have submissions.";

    private static readonly (int Caller, string Why)[] NotManagers =
    [
        (Student, "a plain student of the class"),
        (OtherStudent, "a student of another class"),
        (OtherTeacher, "the teacher of another class"),
        (OtherAdmin, "the class admin of another class"),
        (RemovedAdmin, "a class admin who was removed"),
        (RemovedStudent, "a student who was removed"),
        (Stranger, "a member of no class"),
    ];

    private static readonly string[] ThirdFirstSecond = ["third", "SECRET-1", "b"];
    private static readonly int[] OneToFour = [1, 2, 3, 4];
    private static readonly int[] OneToTwo = [1, 2];

    private readonly FakePdfRenderer renderer = new();
    private MembershipTestKit kit = null!;

    private sealed class FakePdfRenderer : IPdfRenderer
    {
        public Result<byte[]> Answer { get; set; } = Result.Ok(Encoding.ASCII.GetBytes("%PDF-fake"));

        public string? Html { get; private set; }

        public int Portrait { get; private set; }

        public void Reset()
        {
            Html = null;
            Portrait = 0;
            Answer = Result.Ok(Encoding.ASCII.GetBytes("%PDF-fake"));
        }

        public Task<Result<byte[]>> RenderAsync(string html, CancellationToken ct)
        {
            Html = html;
            return Task.FromResult(Answer);
        }

        public Task<Result<byte[]>> RenderPortraitAsync(string html, CancellationToken ct)
        {
            Portrait++;
            return RenderAsync(html, ct);
        }
    }

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit(services => services.AddSingleton<IPdfRenderer>(renderer));

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        renderer.Reset();
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate access.user_roles, access.class_access_rule_conditions, access.class_access_rules restart identity cascade; "
            + "truncate platform.outbox, platform.outbound_messages, notifications.user_notifications, notifications.notifications, notifications.user_devices, assessment.spot_quiz_submissions, assessment.spot_quiz_responses, "
            + "assessment.spot_quiz_questions, assessment.spot_quizzes, assessment.standard_mcq_questions, assessment.standard_mcqs, classes.class_students, classes.classes restart identity cascade");
        foreach (var token in new[] { Teacher, ClassAdmin, Student, OtherTeacher, RemovedAdmin, OtherStudent, SuperAdmin, GentsAdmin, LadiesAdmin, Stranger, OfflineStudent, PhoneStudent, Student13, Student14, Student15, RemovedStudent, OtherAdmin, Student18, RemovedStudent19 })
        {
            await MembershipTestKit.AddMemberAsync(token, "Qw Member " + token, "1");
        }

        await TestDatabase.ExecuteAsync($"update identity.users set email = '{OfflineStudent}@thestrongrope.com' where token = {OfflineStudent}");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, city) values "
            + $"(98201, 'QW-1', 7, 'qwlnk1', 'Qw One', 3, {Teacher}, 1, 'Offline', 'A', {Teacher}, 'Qwville'), (98202, 'QW-2', 7, 'qwlnk2', 'Qw Two', 3, {Teacher}, 1, 'Offline', 'A', {Teacher}, 'Qwville'), "
            + $"(98203, 'QW-3', 7, 'qwlnk3', 'Qw Three', 3, {OtherTeacher}, 1, 'Offline', 'A', {OtherTeacher}, 'Qwville'), (98204, 'QW-4', 7, 'qwlnk4', 'Qw Closed', 3, {Teacher}, 1, 'Offline', 'I', {Teacher}, 'Qwville'), "
            + $"(98205, 'QW-5', 7, 'qwlnk5', 'Qw Ladies', 3, {OtherTeacher}, 2, 'Offline', 'A', {OtherTeacher}, 'Qwville'); "
            + "insert into access.user_roles (user_id, roleid) select u.id, v.role from (values (" + SuperAdmin + ", 1), (" + GentsAdmin + ", 3), (" + LadiesAdmin + ", 4)) v (token, role) join identity.users u on u.token = v.token; "
            + "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin, status, removed_at) values "
            + $"(98201, {ClassAdmin}, current_date, 1, 'A', null), (98201, {Student}, current_date, 0, 'A', null), (98201, {RemovedAdmin}, current_date, 1, 'I', '2025-10-01'), (98201, {OfflineStudent}, current_date, 0, 'A', null), "
            + $"(98201, {PhoneStudent}, current_date, 0, 'A', null), (98201, {Student13}, current_date, 0, 'A', null), (98201, {Student14}, current_date, 0, 'A', null), (98201, {Student15}, current_date, 0, 'A', null), "
            + $"(98201, {RemovedStudent}, current_date, 0, 'I', '2025-10-01'), (98202, {Student18}, current_date, 0, 'A', null), (98202, {RemovedStudent19}, current_date, 0, 'I', '2025-10-01'), "
            + $"(98203, {OtherStudent}, current_date, 0, 'A', null), (98203, {OtherAdmin}, current_date, 1, 'A', null); "
            + "insert into assessment.spot_quizzes (id, code, mcq_code, name, topic, class_id, published_at, created_by) values "
            + $"({Scores}, 'QWQ1', null, 'Scores', 'Topic', 98201, '2026-01-10 10:00:00+00', {Teacher}), ({OfflineSave}, 'QWQ3', null, 'Offline Save', 'Topic', 98201, '2026-01-10 10:00:00+00', {Teacher}), "
            + $"({OfflinePhone}, 'QWQ4', null, 'Offline Phone', 'Topic', 98201, '2026-01-10 10:00:00+00', {Teacher}), ({Sheet}, 'QWQ5', null, 'Sheet <b>\"x\"</b>', 'Topic', 98201, null, {Teacher}), "
            + $"({SheetEmpty}, 'QWQ6', null, 'Sheet Empty', 'Topic', 98201, null, {Teacher}), ({PublishA}, 'QWQ7', null, 'Publish A', 'Publish topic', 98201, null, {Teacher}), "
            + $"({CopySource}, 'QWQ9', 'DBS-1', 'Copy Source', 'Copy topic', 98201, null, {Teacher}), ({NullTopic}, 'QWQ14', null, 'Null Topic', null, 98201, null, {Teacher}), ({Closed}, 'QWQ12', null, 'Closed', 'Topic', 98204, null, {Teacher}); "
            + "insert into assessment.standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order) values (9720101, 'DBS-1', 7, 3, 'Std topic', 'Std subject', 'Std lesson', 'Std name', 1), (9720102, 'DBS-2', 7, 3, 'Std topic 2', 'S2', 'L2', 'N2', 2); "
            + "insert into assessment.standard_mcq_questions (id, mcq_code, question, answer, option1, option2) values (9720111, 'DBS-1', 'sq1', 'STD-RIGHT-1', 'x', 'y'), (9720112, 'DBS-1', 'sq2', 'STD-RIGHT-2', 'z', null); "
            + "insert into assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, option3, option4, option5, answer, option_display_order) values "
            + $"(9720501, {Scores}, false, 'q1', 'SECRET-1', 'b', 'c', null, null, 1, null), (9720502, {Scores}, false, 'q2', 'SECRET-2', 'b', null, null, null, 1, null), "
            + $"(9720507, {OfflineSave}, false, 'save1', 'SECRET-A', 'b', null, null, null, 1, null), (9720508, {OfflineSave}, false, 'save2', 'SECRET-B', 'b', null, null, null, 1, null), (9720509, {OfflineSave}, false, 'save3', '', 'b', null, null, null, 1, null), "
            + $"(9720510, {OfflinePhone}, false, 'phone1', 'SECRET-P', 'b', null, null, null, 1, null), (9720511, {OfflinePhone}, false, 'phone2', 'SECRET-Q', 'b', null, null, null, 1, null), "
            + $"(9720512, {Sheet}, false, 'Q <script>alert(\"1\")</script> & ''quote''', 'Right <i>a</i>', 'Wrong \"b\"', 'Wrong & c', 'ما هو الجواب؟', null, 1, null), (9720513, {Sheet}, true, 'ما هو؟', 'نعم', 'لا', null, null, null, 1, null), "
            + $"(9720514, {PublishA}, false, 'pub1', 'SECRET-1', 'b', 'c', null, null, 1, null), (9720515, {PublishA}, false, 'pub2', '0', 'b', null, null, null, 1, '2,1'), "
            + $"(9720516, {CopySource}, true, 'copy1', 'SECRET-C1', 'b', 'c', 'd', 'e', 1, '2,1'), (9720517, {CopySource}, false, 'copy2', 'SECRET-C2', 'b', null, null, null, 1, null), (9720518, {NullTopic}, false, 'nt1', 'SECRET-N', 'b', null, null, null, 1, null); "
            + "insert into assessment.spot_quiz_responses (spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct) values "
            + $"({Scores}, 9720501, {Student}, 'SECRET-1', 'SECRET-1', 1), ({Scores}, 9720502, {Student}, 'b', 'SECRET-2', 0), ({OfflinePhone}, 9720510, {PhoneStudent}, 'SECRET-P', 'SECRET-P', 1), ({OfflinePhone}, 9720511, {PhoneStudent}, 'b', 'SECRET-Q', 0)");
        await TestDatabase.ExecuteAsync(
            "insert into assessment.spot_quiz_submissions (spot_quiz_id, token) values (" + OfflineSave + ", " + Student15 + ")");
    }

    private Task<MembershipTestKit.Reply> GetAsync(int caller, string path) => kit.SendAsync(caller, HttpMethod.Get, path);

    private Task<MembershipTestKit.Reply> PostAsync(int caller, string path, string body = "{}") => kit.SendAsync(caller, HttpMethod.Post, path, body);

    private static Task<long> Count(string table, string where = "true") => MembershipTestKit.CountAsync(table, where);

    private static Task<long> EventsAsync(string type) => Count("platform.outbox", $"event_type = '{type}'");

    private static async Task<string> TextAsync(string select) => await TestDatabase.ScalarAsync<string>($"select coalesce(({select})::text, '')", TestDatabase.OwnerConnection);

    private static string OfflineBody(params (int Token, int[] Correct)[] students) =>
        "{\"students\": [" + string.Join(", ", students.Select(s => $"{{\"token\": {s.Token}, \"correct\": [{string.Join(", ", s.Correct)}]}}")) + "]}";

    private static void AssertRefused(MembershipTestKit.Reply reply, string detail, string why, params string[] secrets)
    {
        Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.Forbidden, detail)), why);
        foreach (var secret in secrets)
        {
            Assert.That(reply.Body, Does.Not.Contain(secret), why);
        }
    }

    // ---------------------------------------------------------------- who is refused (the answer key, scores and the writes)

    [Test]
    public async Task The_scores_and_the_offline_screen_reach_only_a_manager_of_the_class_and_a_refusal_carries_nothing()
    {
        foreach (var path in new[] { $"/mcq/manage/{Scores}/scores", $"/mcq/manage/{OfflineSave}/offline" })
        {
            foreach (var caller in new[] { Teacher, ClassAdmin, SuperAdmin })
            {
                var reply = await GetAsync(caller, path);
                Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), path + " " + reply.Body);
            }

            foreach (var (caller, why) in NotManagers)
            {
                AssertRefused(await GetAsync(caller, path), NotAllowed, why + " " + path, "SECRET", "Qw Member", "isCorrect");
            }
        }

        var key = await GetAsync(ClassAdmin, $"/mcq/manage/{OfflineSave}/offline");
        Assert.That(key.Json!["questions"]![0]!["options"]![0]!["text"]!.GetValue<string>(), Is.EqualTo("SECRET-A"));
        Assert.That((bool)key.Json["questions"]![0]!["options"]![0]!["isCorrect"]!, Is.True);
        var scores = await GetAsync(Teacher, $"/mcq/manage/{Scores}/scores");
        Assert.That(((int)scores.Json!["total"]!, (int)scores.Json["items"]![0]!["correct"]!, (int)scores.Json["items"]![0]!["outof"]!), Is.EqualTo((1, 1, 2)));
    }

    [Test]
    public async Task A_missing_or_closed_class_or_quiz_is_a_404_before_the_permission_check_on_every_route()
    {
        var routes = new[]
        {
            (HttpMethod.Get, "/mcq/manage/{0}/scores"), (HttpMethod.Get, "/mcq/manage/{0}/offline"), (HttpMethod.Post, "/mcq/manage/{0}/offline"), (HttpMethod.Get, "/mcq/manage/{0}/sheet"),
            (HttpMethod.Post, "/mcq/manage/{0}/publish"), (HttpMethod.Post, "/mcq/manage/{0}/copy"),
        };
        foreach (var (method, template) in routes)
        {
            var missing = await kit.SendAsync(Stranger, method, template.Replace("{0}", "99999999", StringComparison.Ordinal), method == HttpMethod.Get ? null : "{}");
            Assert.That((missing.Status, missing.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Quiz not found")), template);
            var closed = await kit.SendAsync(Stranger, method, template.Replace("{0}", Closed.ToString(System.Globalization.CultureInfo.InvariantCulture), StringComparison.Ordinal), method == HttpMethod.Get ? null : "{}");
            Assert.That((closed.Status, closed.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")), template);
        }

        foreach (var path in new[] { "/classes/99999999/mcq", "/classes/98204/mcq", "/classes/99999999/mcq/standard/9720101/copy", "/classes/98204/mcq/standard/9720101/copy" })
        {
            var reply = await PostAsync(Stranger, path, "{\"name\": \"N\", \"topic\": \"T\"}");
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")), path);
        }
    }

    [Test]
    public async Task Every_write_refuses_a_non_manager_with_PHPs_text_and_changes_nothing()
    {
        foreach (var (caller, why) in NotManagers)
        {
            AssertRefused(await PostAsync(caller, "/classes/98201/mcq", "{\"name\": \"N\", \"topic\": \"T\"}"), NotAllowed, "create, " + why);
            AssertRefused(await PostAsync(caller, "/classes/98201/mcq/standard/9720101/copy"), NotAllowed, "standard copy, " + why);
            AssertRefused(await PostAsync(caller, $"/mcq/manage/{OfflineSave}/offline", OfflineBody((Student13, [9720507]))), NotAllowed, "offline save, " + why);
            AssertRefused(await PostAsync(caller, $"/mcq/manage/{PublishA}/publish"), NotAllowed, "publish, " + why);
            AssertRefused(await kit.SendAsync(caller, HttpMethod.Post, $"/mcq/manage/{CopySource}/copy", "{\"targetClassId\": 98202}"), CopyNotAllowed, "copy, " + why);
            var sheet = await kit.DownloadAsync(caller, $"/mcq/manage/{Sheet}/sheet");
            Assert.That(sheet.Status, Is.EqualTo(HttpStatusCode.Forbidden), "sheet, " + why);
            Assert.That(sheet.Text, Does.Not.Contain("script"), why);
        }

        Assert.That(await Count("assessment.spot_quizzes"), Is.EqualTo(9), "no quiz was created or copied");
        Assert.That(await Count("assessment.spot_quiz_submissions"), Is.EqualTo(1));
        Assert.That(await Count("assessment.spot_quiz_responses"), Is.EqualTo(4));
        Assert.That(await Count("assessment.spot_quizzes", "published_at is not null and id = " + PublishA), Is.Zero);
        Assert.That(await Count("assessment.spot_quiz_questions", "option_display_order is not null and spot_quiz_id in (" + Sheet + ", " + PublishA + ")"), Is.EqualTo(1), "only the stored order of the fixture");
        Assert.That(await Count("platform.outbox"), Is.Zero);
        Assert.That(await Count("notifications.notifications"), Is.Zero);
        Assert.That(renderer.Html, Is.Null, "nothing was rendered");
    }

    [Test]
    public async Task Copying_is_for_a_copier_of_both_classes_and_not_for_the_teacher_or_a_class_admin()
    {
        foreach (var caller in new[] { Teacher, ClassAdmin, LadiesAdmin })
        {
            AssertRefused(await kit.SendAsync(caller, HttpMethod.Post, $"/mcq/manage/{CopySource}/copy", "{\"targetClassId\": 98202}"), CopyNotAllowed, "caller " + caller);
        }

        AssertRefused(await kit.SendAsync(GentsAdmin, HttpMethod.Post, $"/mcq/manage/{CopySource}/copy", "{\"targetClassId\": 98205}"), CopyNotAllowed, "a gents admin into a ladies class");
        Assert.That(await Count("assessment.spot_quizzes"), Is.EqualTo(9));
        Assert.That(await EventsAsync("assessment.quiz_created"), Is.Zero);

        foreach (var caller in new[] { SuperAdmin, GentsAdmin })
        {
            var reply = await kit.SendAsync(caller, HttpMethod.Post, $"/mcq/manage/{CopySource}/copy", "{\"targetClassId\": " + (caller == SuperAdmin ? 98202 : 98203) + "}");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created), reply.Body);
        }
    }

    // ---------------------------------------------------------------- create and the quiz code

    [Test]
    public async Task Create_writes_one_quiz_and_one_event_and_a_refused_body_writes_neither()
    {
        var reply = await PostAsync(ClassAdmin, "/classes/98201/mcq", "{\"name\": \" New \", \"topic\": \" Topic \", \"restrictToClass\": 0}");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created), reply.Body);
        var id = (int)reply.Json!["id"]!;
        Assert.That(await Count("assessment.spot_quizzes", $"id = {id} and name = 'New' and topic = 'Topic' and class_id = 98201 and restrict_to_class = 0 and created_by = {ClassAdmin} and published_at is null and mcq_code is null"), Is.EqualTo(1));
        Assert.That(await Count("platform.outbox", $"event_type = 'assessment.quiz_created' and payload = '{{\"quizId\": {id}, \"classId\": 98201, \"token\": {ClassAdmin}, \"source\": \"new\"}}'::jsonb"), Is.EqualTo(1));

        var before = await Count("assessment.spot_quizzes");
        foreach (var body in new[] { "{\"topic\": \"T\"}", "{\"name\": \"N\"}", "\"text\"", "{\"name\": \"a\\u0000b\", \"topic\": \"T\"}", "{\"name\": \"" + new string('n', 301) + "\", \"topic\": \"T\"}", "{\"name\": \"N\", \"topic\": \"" + new string('t', 301) + "\"}" })
        {
            var refused = await PostAsync(Teacher, "/classes/98201/mcq", body);
            Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), body.Length > 60 ? body[..60] : body);
        }

        Assert.That(await Count("assessment.spot_quizzes"), Is.EqualTo(before));
        Assert.That(await EventsAsync("assessment.quiz_created"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_quiz_code_is_eight_digits_or_upper_case_letters_and_thirty_simultaneous_creates_give_thirty_different_codes()
    {
        var replies = await Task.WhenAll(Enumerable.Range(0, 30).Select(i => PostAsync(Teacher, "/classes/98201/mcq", $"{{\"name\": \"Race {i}\", \"topic\": \"Race\"}}")));

        Assert.That(replies.Select(r => r.Status), Is.All.EqualTo(HttpStatusCode.Created));
        Assert.That(await Count("assessment.spot_quizzes", "name like 'Race %'"), Is.EqualTo(30));
        Assert.That(await Count("assessment.spot_quizzes", "name like 'Race %' and code ~ '^[0-9A-Z]{8}$'"), Is.EqualTo(30), "PHP's alphabet and length");
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(distinct code) from assessment.spot_quizzes where name like 'Race %'", TestDatabase.OwnerConnection), Is.EqualTo(30),
            "no duplicate in this run: the draw is 36^8 and the check runs in the transaction; the documented race needs two draws of one code, which a test cannot provoke (0 of 30 here)");
        Assert.That(await EventsAsync("assessment.quiz_created"), Is.EqualTo(30));
    }

    [Test]
    public async Task FLAGGED_the_schema_has_no_unique_index_on_the_quiz_code_as_in_PHP()
    {
        await TestDatabase.ExecuteAsync(
            "insert into assessment.spot_quizzes (code, name, class_id, created_by) values ('SAMECODE', 'one', 98201, 1), ('SAMECODE', 'two', 98201, 1)");

        Assert.That(await Count("assessment.spot_quizzes", "code = 'samecode'"), Is.EqualTo(2), "nothing stops two quizzes with one code (and the lookup by code is case-insensitive); finding 15 is a decision for the owner");
    }

    // ---------------------------------------------------------------- copy from a standard MCQ and between classes

    [Test]
    public async Task A_standard_copy_shows_in_the_copy_view_with_the_standards_code_and_a_second_copy_keeps_one_row_with_the_latest_quiz()
    {
        Assert.That(await Count("assessment.v_class_mcq_copies", "class_id = 98202"), Is.Zero);

        var first = await PostAsync(Teacher, "/classes/98202/mcq/standard/9720101/copy");
        Assert.That(first.Status, Is.EqualTo(HttpStatusCode.Created), first.Body);
        var firstId = (int)first.Json!["id"]!;
        Assert.That(await Count("assessment.v_class_mcq_copies", $"class_id = 98202 and mcq_code = 'DBS-1' and quiz_id = {firstId} and published_at is null"), Is.EqualTo(1), "the pending report's view lists the copy under the standard's code");

        var second = await PostAsync(Teacher, "/classes/98202/mcq/standard/9720101/copy");
        Assert.That(second.Status, Is.EqualTo(HttpStatusCode.Created), "no duplicate rule, as PHP: " + second.Body);
        var secondId = (int)second.Json!["id"]!;
        Assert.That(secondId, Is.Not.EqualTo(firstId));
        Assert.That(await Count("assessment.spot_quizzes", "class_id = 98202 and mcq_code = 'DBS-1'"), Is.EqualTo(2));
        Assert.That(await Count("assessment.v_class_mcq_copies", "class_id = 98202 and mcq_code = 'DBS-1'"), Is.EqualTo(1), "one row per standard MCQ per class");
        Assert.That(await Count("assessment.v_class_mcq_copies", $"class_id = 98202 and quiz_id = {secondId}"), Is.EqualTo(1), "the latest copy");

        await PostAsync(Teacher, $"/mcq/manage/{secondId}/publish");
        Assert.That(await Count("assessment.v_class_mcq_copies", $"class_id = 98202 and quiz_id = {secondId} and published_at is not null"), Is.EqualTo(1));
        Assert.That(await Count("platform.outbox", "event_type = 'assessment.quiz_created' and payload ->> 'source' = 'standard'"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_quiz_state_document_is_found_and_deleted_by_its_name_in_another_letter_case_CASE_C5()
    {
        using var factory = TestApi.Create();
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AssessmentContext>();
        await QuizStateStore.SaveAsync(db, "winners", new System.Text.Json.Nodes.JsonObject(), TimeProvider.System, CancellationToken.None);

        Assert.That(await QuizStateStore.ExistsAsync(db, "WINNERS", CancellationToken.None), Is.True, "the name matches without regard to letter case");
        Assert.That(await QuizStateStore.LoadAsync(db, "Winners", CancellationToken.None), Is.Not.Null);
        await QuizStateStore.DeleteAsync(db, ["WINNERS"], CancellationToken.None);
        Assert.That(await Count("assessment.quiz_state", "name = 'winners'"), Is.Zero);
    }

    [Test]
    public async Task A_standard_copy_takes_the_questions_whose_code_differs_from_the_standards_only_in_letter_case_CASE_C6()
    {
        await TestDatabase.ExecuteAsync(
            "insert into assessment.standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order) values (9720103, 'DBS-3', 7, 3, 'T3', 'S3', 'L3', 'N3', 3); "
            + "insert into assessment.standard_mcq_questions (id, mcq_code, question, answer, option1, option2) values (9720131, 'dbs-3', 'cq1', 'CASE-RIGHT', 'x', 'y')");

        var reply = await PostAsync(ClassAdmin, "/classes/98201/mcq/standard/9720103/copy");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created), reply.Body);
        var id = (int)reply.Json!["id"]!;
        Assert.That(await Count("assessment.spot_quiz_questions", $"spot_quiz_id = {id}"), Is.EqualTo(1), "MariaDB matches the code without regard to letter case, so the question is copied");
    }

    [Test]
    public async Task A_standard_copy_makes_the_name_the_topic_the_questions_and_cuts_a_long_name_to_the_column()
    {
        var reply = await PostAsync(ClassAdmin, "/classes/98201/mcq/standard/9720101/copy");
        var id = (int)reply.Json!["id"]!;

        Assert.That(await Count("assessment.spot_quizzes", $"id = {id} and name = 'Std subject - Std lesson - Std name' and topic = 'Std topic' and mcq_code = 'DBS-1' and restrict_to_class = 1 and created_by = {ClassAdmin} and published_at is null and code ~ '^[0-9A-Z]{{8}}$'"), Is.EqualTo(1));
        Assert.That(await TextAsync($"select string_agg(question || ':' || option1 || ':' || option2 || ':' || coalesce(option3, '-') || ':' || answer, ',' order by id) from assessment.spot_quiz_questions where spot_quiz_id = {id}"),
            Is.EqualTo("sq1:STD-RIGHT-1:x:y:1,sq2:STD-RIGHT-2:z:-:1"), "the standard's answer becomes option1 and its options follow");
        Assert.That(await Count("assessment.spot_quiz_questions", $"spot_quiz_id = {id} and (is_arabic is not null or option_display_order is not null)"), Is.Zero);

        await TestDatabase.ExecuteAsync($"update assessment.standard_mcqs set subject = '{new string('s', 200)}', lesson = '{new string('l', 200)}', name = '{new string('n', 90)}', topic = '{new string('t', 400)}' where id = 9720102");
        var long_ = await PostAsync(Teacher, "/classes/98201/mcq/standard/9720102/copy");
        Assert.That(long_.Status, Is.EqualTo(HttpStatusCode.Created), long_.Body);
        Assert.That(await TestDatabase.ScalarAsync<int>($"select char_length(name) from assessment.spot_quizzes where id = {(int)long_.Json!["id"]!}", TestDatabase.OwnerConnection), Is.EqualTo(300));
        Assert.That(await TestDatabase.ScalarAsync<int>($"select char_length(topic) from assessment.spot_quizzes where id = {(int)long_.Json["id"]!}", TestDatabase.OwnerConnection), Is.EqualTo(300));
    }

    [Test]
    public async Task A_copy_between_classes_leaves_out_the_standard_code_and_the_arabic_flag_and_the_order_and_a_duplicate_is_refused_ignoring_case()
    {
        var copy = await kit.SendAsync(SuperAdmin, HttpMethod.Post, $"/mcq/manage/{CopySource}/copy", "{\"targetClassId\": 98202}");
        Assert.That(copy.Status, Is.EqualTo(HttpStatusCode.Created), copy.Body);
        var id = (int)copy.Json!["id"]!;
        Assert.That(await Count("assessment.spot_quizzes", $"id = {id} and class_id = 98202 and name = 'Copy Source' and topic = 'Copy topic' and mcq_code is null and published_at is null and created_by = {SuperAdmin} and code <> 'QWQ9'"), Is.EqualTo(1));
        Assert.That(await Count("assessment.v_class_mcq_copies", "class_id = 98202"), Is.Zero, "a copy of a copy is not a standard copy");
        Assert.That(await TextAsync($"select string_agg(question || ':' || option1 || ':' || coalesce(option5, ''), ',' order by id) from assessment.spot_quiz_questions where spot_quiz_id = {id}"), Is.EqualTo("copy1:SECRET-C1:e,copy2:SECRET-C2:"));
        Assert.That(await Count("assessment.spot_quiz_questions", $"spot_quiz_id = {id} and (is_arabic is not null or option_display_order is not null)"), Is.Zero);
        Assert.That(await Count("assessment.spot_quiz_questions", $"spot_quiz_id = {CopySource}"), Is.EqualTo(2), "the source keeps its questions");
        Assert.That(await Count("platform.outbox", $"event_type = 'assessment.quiz_created' and payload = '{{\"quizId\": {id}, \"classId\": 98202, \"token\": {SuperAdmin}, \"source\": \"copy\"}}'::jsonb"), Is.EqualTo(1));

        var again = await kit.SendAsync(SuperAdmin, HttpMethod.Post, $"/mcq/manage/{CopySource}/copy", "{\"targetClassId\": 98202}");
        Assert.That((again.Status, again.Detail), Is.EqualTo((HttpStatusCode.Conflict, "A quiz with the same name & topic already exists in target class")));
        await TestDatabase.ExecuteAsync($"update assessment.spot_quizzes set name = upper(name), topic = upper(topic) where id = {id}");
        var upper = await kit.SendAsync(SuperAdmin, HttpMethod.Post, $"/mcq/manage/{CopySource}/copy", "{\"targetClassId\": 98202}");
        Assert.That(upper.Status, Is.EqualTo(HttpStatusCode.Conflict), "the match ignores case (PHP's collation did): " + upper.Body);
        Assert.That(await EventsAsync("assessment.quiz_created"), Is.EqualTo(1), "a refusal writes no event");
    }

    [Test]
    public async Task A_quiz_without_a_topic_never_counts_as_a_duplicate_and_a_bad_target_is_refused()
    {
        for (var i = 0; i < 2; i++)
        {
            var reply = await kit.SendAsync(SuperAdmin, HttpMethod.Post, $"/mcq/manage/{NullTopic}/copy", "{\"targetClassId\": 98202}");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created), "a null topic never matches (PHP's = on null): " + reply.Body);
        }

        foreach (var (body, status, detail) in new[]
        {
            ("{}", HttpStatusCode.UnprocessableEntity, "targetClassId is required"), ("{\"targetClassId\": \"abc\"}", HttpStatusCode.UnprocessableEntity, "targetClassId is required"),
            ("{\"targetClassId\": -1}", HttpStatusCode.UnprocessableEntity, "targetClassId is required"), ("{\"targetClassId\": 99999999}", HttpStatusCode.NotFound, "Class not found"), ("{\"targetClassId\": 98204}", HttpStatusCode.NotFound, "Class not found"),
        })
        {
            var reply = await kit.SendAsync(SuperAdmin, HttpMethod.Post, $"/mcq/manage/{CopySource}/copy", body);
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((status, detail)), body);
        }

        Assert.That(await EventsAsync("assessment.quiz_created"), Is.EqualTo(2));
    }

    [Test]
    public async Task Simultaneous_copies_never_leave_half_a_quiz()
    {
        var replies = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => PostAsync(Teacher, "/classes/98202/mcq/standard/9720101/copy")));

        Assert.That(replies.Select(r => r.Status), Is.All.EqualTo(HttpStatusCode.Created));
        Assert.That(await Count("assessment.spot_quizzes", "class_id = 98202"), Is.EqualTo(6));
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from assessment.spot_quizzes q where q.class_id = 98202 and (select count(*) from assessment.spot_quiz_questions x where x.spot_quiz_id = q.id) <> 2", TestDatabase.OwnerConnection), Is.Zero,
            "each copy has exactly its own two questions (PHP attached them to MAX(id) of the table)");
        Assert.That(await EventsAsync("assessment.quiz_created"), Is.EqualTo(6));
    }

    // ---------------------------------------------------------------- offline answers

    [Test]
    public async Task An_offline_save_writes_one_submission_and_one_response_per_question_for_each_student_and_one_event()
    {
        var reply = await PostAsync(ClassAdmin, $"/mcq/manage/{OfflineSave}/offline", OfflineBody((Student13, [9720507, 9720509]), (Student14, [])));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That((int)reply.Json!["saved"]!, Is.EqualTo(2));
        Assert.That(await Count("assessment.spot_quiz_submissions", $"spot_quiz_id = {OfflineSave} and token in ({Student13}, {Student14})"), Is.EqualTo(2));
        Assert.That(await TextAsync($"select string_agg(spot_quiz_question_id || ':' || coalesce(response, '~') || ':' || correct_response || ':' || is_correct, ',' order by spot_quiz_question_id) from assessment.spot_quiz_responses where token = {Student13} and spot_quiz_id = {OfflineSave}"),
            Is.EqualTo("9720507:SECRET-A:SECRET-A:1,9720508:~:SECRET-B:0,9720509::" + ":1"), "a listed question is right whatever its text (a blank option 1 too: PHP's rule), the others wrong with no response; the key is the database's");
        Assert.That(await Count("assessment.spot_quiz_responses", $"token = {Student14} and spot_quiz_id = {OfflineSave} and is_correct = 0 and response is null"), Is.EqualTo(3));
        Assert.That(await Count("platform.outbox", $"event_type = 'assessment.offline_answers_recorded' and payload = '{{\"quizId\": {OfflineSave}, \"classId\": 98201, \"token\": {ClassAdmin}, \"count\": 2}}'::jsonb"), Is.EqualTo(1));
    }

    [Test]
    public async Task An_offline_score_is_what_the_same_answers_give_online()
    {
        await TestDatabase.ExecuteAsync($"update assessment.spot_quiz_questions set option1 = 'SECRET-C' where id = 9720509");
        await PostAsync(Teacher, $"/mcq/manage/{OfflineSave}/offline", OfflineBody((Student13, [9720507, 9720509])));
        var online = await PostAsync(Student14, $"/mcq/quizzes/{OfflineSave}/responses",
            "{\"responses\": [{\"questionId\": 9720507, \"selectedText\": \"SECRET-A\"}, {\"questionId\": 9720508, \"selectedText\": \"b\"}, {\"questionId\": 9720509, \"selectedText\": \"SECRET-C\"}]}");
        Assert.That(online.Status, Is.EqualTo(HttpStatusCode.OK).Or.EqualTo(HttpStatusCode.Created), online.Body);

        string Flags(int token) => $"select string_agg(spot_quiz_question_id || ':' || correct_response || ':' || is_correct, ',' order by spot_quiz_question_id) from assessment.spot_quiz_responses where token = {token} and spot_quiz_id = {OfflineSave}";
        Assert.That(await TextAsync(Flags(Student13)), Is.EqualTo(await TextAsync(Flags(Student14))), "the same right and wrong flags and the same stored key");
        var mine = await GetAsync(Student13, $"/mcq/quizzes/{OfflineSave}/my-score");
        var theirs = await GetAsync(Student14, $"/mcq/quizzes/{OfflineSave}/my-score");
        Assert.That(((int)mine.Json!["correct"]!, (int)mine.Json["answered"]!), Is.EqualTo(((int)theirs.Json!["correct"]!, (int)theirs.Json["answered"]!)));
    }

    [Test]
    public async Task An_offline_batch_with_a_student_who_already_has_a_submission_is_a_409_with_the_conflict_list_and_writes_nothing()
    {
        var reply = await PostAsync(Teacher, $"/mcq/manage/{OfflineSave}/offline", OfflineBody((Student13, [9720507]), (Student15, [9720507])));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Conflict), reply.Body);
        Assert.That(reply.Json!["detail"]!.GetValue<string>(), Is.EqualTo(Conflict));
        Assert.That(reply.Json["conflicts"]!.AsArray().Select(t => (int)t!), Is.EqualTo(new[] { Student15 }));
        Assert.That(await Count("assessment.spot_quiz_submissions"), Is.EqualTo(1));
        Assert.That(await Count("assessment.spot_quiz_responses", $"token = {Student13}"), Is.Zero);
        Assert.That(await EventsAsync("assessment.offline_answers_recorded"), Is.Zero);
    }

    [Test]
    public async Task A_student_who_answered_on_their_phone_gets_no_second_set_the_refusal_has_no_conflicts_list_as_PHP_and_the_whole_batch_is_rolled_back()
    {
        var alone = await PostAsync(Teacher, $"/mcq/manage/{OfflinePhone}/offline", OfflineBody((PhoneStudent, [9720510])));
        Assert.That((alone.Status, alone.Detail), Is.EqualTo((HttpStatusCode.Conflict, Conflict)));
        Assert.That(alone.Json!.AsObject().ContainsKey("conflicts"), Is.False, "PHP answers the unique-key case without the list too (checked on PHP in manage-offline-save.hurl)");

        var batch = await PostAsync(Teacher, $"/mcq/manage/{OfflinePhone}/offline", OfflineBody((Student13, [9720510]), (Student14, [9720511]), (PhoneStudent, [])));
        Assert.That((batch.Status, batch.Detail), Is.EqualTo((HttpStatusCode.Conflict, Conflict)));
        Assert.That(await Count("assessment.spot_quiz_submissions", "spot_quiz_id = " + OfflinePhone), Is.Zero, "the students before the failing one are rolled back");
        Assert.That(await Count("assessment.spot_quiz_responses", $"spot_quiz_id = {OfflinePhone}"), Is.EqualTo(2), "only the phone answers remain, unchanged");
        Assert.That(await Count("assessment.spot_quiz_responses", $"spot_quiz_id = {OfflinePhone} and token = {PhoneStudent} and response = 'SECRET-P'"), Is.EqualTo(1));
        Assert.That(await EventsAsync("assessment.offline_answers_recorded"), Is.Zero);

        var screen = await GetAsync(Teacher, $"/mcq/manage/{OfflinePhone}/offline");
        Assert.That((bool)screen.Json!["students"]!.AsArray().Single(s => (int)s!["token"]! == PhoneStudent)!["submitted"]!, Is.False, "the screen cannot tell (only an offline entry writes a submission row): PHP's");
    }

    [Test]
    public async Task Offline_bodies_that_PHP_refuses_write_nothing_and_name_the_first_refusal()
    {
        var cases = new (string Body, HttpStatusCode Status, string Detail)[]
        {
            ("{}", HttpStatusCode.UnprocessableEntity, "students is required"),
            ("{\"students\": []}", HttpStatusCode.UnprocessableEntity, "students is required"),
            ("{\"students\": [{\"token\": 922013}]}", HttpStatusCode.UnprocessableEntity, "each student needs a token and a correct list"),
            ("\"text\"", HttpStatusCode.UnprocessableEntity, "Invalid JSON body"),
            ("{\"students\": [{\"correct\": []}]}", HttpStatusCode.BadRequest, "Malformed response payload."),
            ("{\"students\": [{\"token\": 922013, \"correct\": [9720507]}, {\"token\": 922006, \"correct\": []}]}", HttpStatusCode.Forbidden, "Student 922006 is not enrolled in this class."),
            ("{\"students\": [{\"token\": 922016, \"correct\": []}]}", HttpStatusCode.Forbidden, "Student 922016 is not enrolled in this class."),
            ("{\"students\": [{\"token\": 922013, \"correct\": [9720501]}]}", HttpStatusCode.BadRequest, "Question 9720501 does not belong to this quiz."),
            ("{\"students\": [{\"token\": 99999999999999999999, \"correct\": []}]}", HttpStatusCode.Forbidden, "Student 9223372036854775807 is not enrolled in this class."),
        };
        foreach (var (body, status, detail) in cases)
        {
            var reply = await PostAsync(Teacher, $"/mcq/manage/{OfflineSave}/offline", body);
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((status, detail)), body);
        }

        var many = "{\"students\": [" + string.Join(", ", Enumerable.Range(0, 501).Select(i => $"{{\"token\": {i + 1}, \"correct\": []}}")) + "]}";
        Assert.That((await PostAsync(Teacher, $"/mcq/manage/{OfflineSave}/offline", many)).Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await Count("assessment.spot_quiz_submissions"), Is.EqualTo(1));
        Assert.That(await Count("assessment.spot_quiz_responses", "token = " + Student13), Is.Zero);
        Assert.That(await EventsAsync("assessment.offline_answers_recorded"), Is.Zero);
    }

    [Test]
    public async Task Two_simultaneous_offline_saves_of_one_student_write_one_set_and_one_event()
    {
        var saves = Enumerable.Range(0, 6).Select(_ => PostAsync(Teacher, $"/mcq/manage/{OfflineSave}/offline", OfflineBody((Student13, [9720507])))).ToList();
        var replies = await Task.WhenAll(saves);

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1), string.Join(" | ", replies.Select(r => r.Status + r.Body)));
        Assert.That(replies.Where(r => r.Status != HttpStatusCode.OK).Select(r => r.Status), Is.All.EqualTo(HttpStatusCode.Conflict));
        Assert.That(await Count("assessment.spot_quiz_submissions", "token = " + Student13), Is.EqualTo(1));
        Assert.That(await Count("assessment.spot_quiz_responses", $"token = {Student13} and spot_quiz_id = {OfflineSave}"), Is.EqualTo(3), "never a doubled set");
        Assert.That(await EventsAsync("assessment.offline_answers_recorded"), Is.EqualTo(1));
    }

    [Test]
    public async Task The_offline_screen_lists_the_current_students_only_follows_the_stored_order_and_marks_the_internal_address()
    {
        await TestDatabase.ExecuteAsync("update assessment.spot_quiz_questions set option_display_order = '3,1,2', option3 = 'third' where id = 9720501");
        var reply = await GetAsync(Teacher, $"/mcq/manage/{Scores}/offline");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["students"]!.AsArray().Select(s => (int)s!["token"]!), Is.EqualTo(new[] { ClassAdmin, Student, OfflineStudent, PhoneStudent, Student13, Student14, Student15 }), "removed students are not listed");
        Assert.That(reply.Json["students"]!.AsArray().Where(s => (bool)s!["isOffline"]!).Select(s => (int)s!["token"]!), Is.EqualTo(new[] { OfflineStudent }));
        Assert.That(reply.Json["questions"]![0]!["options"]!.AsArray().Select(o => o!["text"]!.GetValue<string>()), Is.EqualTo(ThirdFirstSecond));
        Assert.That(await Count("assessment.spot_quiz_questions", $"spot_quiz_id = {Scores} and option_display_order is null"), Is.EqualTo(1), "the screen does not store an order");
    }

    // ---------------------------------------------------------------- the sheet

    [Test]
    public async Task The_sheet_page_encodes_every_value_and_keeps_Arabic_and_is_rendered_upright()
    {
        var file = await kit.DownloadAsync(Teacher, $"/mcq/manage/{Sheet}/sheet");

        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK), file.Text);
        Assert.That(file.ContentType, Does.StartWith("application/pdf"));
        Assert.That(file.Disposition, Does.Contain("MCQ_QWQ5.pdf"));
        Assert.That(file.Text, Does.StartWith("%PDF"));
        Assert.That(renderer.Portrait, Is.EqualTo(1), "the sheet is portrait, the reports landscape");
        var html = renderer.Html!;
        Assert.That(html, Does.Not.Contain("<script"), "a question cannot add markup");
        Assert.That(html, Does.Not.Contain("<b>\"x\""));
        Assert.That(html, Does.Not.Contain("<i>"));
        Assert.That(html, Does.Contain("&lt;script&gt;alert(&quot;1&quot;)&lt;/script&gt; &amp; &#39;quote&#39;"));
        Assert.That(html, Does.Contain("Sheet &lt;b&gt;&quot;x&quot;&lt;/b&gt;"));
        Assert.That(html, Does.Contain("Right &lt;i&gt;a&lt;/i&gt;"));
        Assert.That(html, Does.Contain("ما هو الجواب؟").And.Contain("ما هو؟").And.Contain("نعم"));
        Assert.That(html, Does.Contain("<b>1.</b>").And.Contain("<b>2.</b>"));
        Assert.That(html, Does.Contain("Topic &middot; QW-1 Qw One"));
        Assert.That(html, Does.Not.Contain("http"), "no outside resource");
    }

    [Test]
    public async Task The_sheet_stores_an_option_order_once_and_keeps_it_and_a_stored_order_is_not_changed()
    {
        Assert.That(await Count("assessment.spot_quiz_questions", $"spot_quiz_id in ({Sheet}, {PublishA}) and option_display_order is null"), Is.EqualTo(3));

        await kit.DownloadAsync(Teacher, $"/mcq/manage/{Sheet}/sheet");
        var first = await TextAsync($"select string_agg(id || '=' || coalesce(option_display_order, '~'), ';' order by id) from assessment.spot_quiz_questions where spot_quiz_id = {Sheet}");
        Assert.That(first, Does.Not.Contain("~"), "every question got an order");
        var orders = await TextAsync($"select string_agg(option_display_order, ';' order by id) from assessment.spot_quiz_questions where spot_quiz_id = {Sheet}");
        var parts = orders.Split(';');
        Assert.That(parts[0].Split(',').Select(int.Parse).Order(), Is.EqualTo(OneToFour), "a permutation of the four options");
        Assert.That(parts[1].Split(',').Select(int.Parse).Order(), Is.EqualTo(OneToTwo));

        await kit.DownloadAsync(Teacher, $"/mcq/manage/{Sheet}/sheet");
        await kit.DownloadAsync(ClassAdmin, $"/mcq/manage/{Sheet}/sheet");
        Assert.That(await TextAsync($"select string_agg(id || '=' || coalesce(option_display_order, '~'), ';' order by id) from assessment.spot_quiz_questions where spot_quiz_id = {Sheet}"), Is.EqualTo(first), "stable afterwards");

        await kit.DownloadAsync(Teacher, $"/mcq/manage/{PublishA}/sheet");
        Assert.That(await TextAsync($"select option_display_order from assessment.spot_quiz_questions where id = 9720515"), Is.EqualTo("2,1"), "a stored order is never replaced");
        Assert.That(await TextAsync($"select option_display_order from assessment.spot_quiz_questions where id = 9720514"), Does.Match("^[1-3](,[1-3]){2}$"));
    }

    [Test]
    public async Task The_sheet_of_a_quiz_without_questions_is_a_404_a_failed_renderer_is_a_503_and_neither_renders_a_page_for_nobody()
    {
        var empty = await kit.DownloadAsync(Teacher, $"/mcq/manage/{SheetEmpty}/sheet");
        Assert.That((empty.Status, JsonNode.Parse(empty.Text)!["detail"]!.GetValue<string>()), Is.EqualTo((HttpStatusCode.NotFound, "This MCQ has no questions")));
        Assert.That(renderer.Html, Is.Null);

        renderer.Answer = Result.Fail<byte[]>("Gotenberg unreachable");
        var down = await kit.DownloadAsync(Teacher, $"/mcq/manage/{Sheet}/sheet");
        Assert.That(down.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable), down.Text);
        Assert.That(down.Text, Does.Not.Contain("Gotenberg"), "the renderer's text is not passed on");
    }

    // ---------------------------------------------------------------- publish

    private static async Task AddDevicesAsync() => await TestDatabase.ExecuteAsync(
        "insert into notifications.user_devices (token, device_id) values "
        + $"({Student}, 'dev-student'), ({Student}, 'dev-student-2'), ({Student14}, 'dev-s14'), ({RemovedStudent}, 'dev-removed'), ({OtherStudent}, 'dev-other'), ({Student18}, 'dev-s18')");

    [Test]
    public async Task Publish_writes_the_quiz_the_event_the_notification_the_inbox_rows_of_current_students_and_one_push_row_per_device()
    {
        await AddDevicesAsync();

        var reply = await PostAsync(Teacher, $"/mcq/manage/{PublishA}/publish");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(((bool)reply.Json!["success"]!, (int)reply.Json["deviceCount"]!, (int)reply.Json["successCount"]!, (int)reply.Json["failureCount"]!), Is.EqualTo((true, 3, 3, 0)));
        Assert.That(await Count("assessment.spot_quizzes", $"id = {PublishA} and published_at is not null and published_by = {Teacher}"), Is.EqualTo(1));
        Assert.That(await Count("platform.outbox", $"event_type = 'assessment.quiz_published' and payload = '{{\"quizId\": {PublishA}, \"classId\": 98201, \"token\": {Teacher}}}'::jsonb"), Is.EqualTo(1));
        Assert.That(await EventsAsync("assessment.quiz_published"), Is.EqualTo(1), "exactly one event");
        Assert.That(await Count("notifications.notifications", $"created_by = {Teacher} and title = 'MCQ for QW-1 [Publish A]' and body = 'MCQ for QW-1 for the Topic - Publish topic - Publish A' and action_link = '/quizzes/{PublishA}' and device_count = 3 and success_count = 3 and failure_count = 0 and target_audience_criteria::text::jsonb = '{{\"type\": \"CLASS\", \"value\": [\"98201\"]}}'::jsonb"), Is.EqualTo(1));
        Assert.That(await TextAsync("select string_agg(user_token::text, ',' order by user_token) from notifications.user_notifications"), Is.EqualTo($"{ClassAdmin},{Student},{OfflineStudent},{PhoneStudent},{Student13},{Student14},{Student15}"),
            "the class's current students only: not the removed ones, not another class");
        Assert.That(await TextAsync("select string_agg(recipient, ',' order by recipient) from platform.outbound_messages where channel = 'push'"), Is.EqualTo("dev-s14,dev-student,dev-student-2"), "the current students' devices only");
        Assert.That(await Count("platform.outbound_messages", $"dedupe_key like 'quiz-{PublishA}:%' and status = 'queued' and created_by = {Teacher}"), Is.EqualTo(3));
        var payload = JsonNode.Parse(await TextAsync("select payload::text from platform.outbound_messages order by id limit 1"))!;
        Assert.That(payload["data"]!["type"]!.GetValue<string>(), Is.EqualTo("quiz_released"));
        Assert.That((payload["data"]!["quiz_id"]!.GetValue<string>(), payload["data"]!["class_id"]!.GetValue<string>()), Is.EqualTo((PublishA.ToString(System.Globalization.CultureInfo.InvariantCulture), "98201")));
    }

    [Test]
    public async Task Publishing_again_moves_the_time_and_adds_a_notification_and_inbox_rows_as_PHP_does_but_queues_no_second_push()
    {
        await AddDevicesAsync();
        await PostAsync(Teacher, $"/mcq/manage/{PublishA}/publish");

        var again = await PostAsync(ClassAdmin, $"/mcq/manage/{PublishA}/publish");

        Assert.That(again.Status, Is.EqualTo(HttpStatusCode.OK), again.Body);
        Assert.That(((int)again.Json!["deviceCount"]!, (int)again.Json["successCount"]!, (int)again.Json["failureCount"]!), Is.EqualTo((3, 0, 3)), "PHP's dedupe: nothing queued twice, the refused count is the failures");
        Assert.That(await Count("platform.outbound_messages"), Is.EqualTo(3), "one push per device and quiz");
        Assert.That(await Count("notifications.notifications"), Is.EqualTo(2), "PHP writes a new notification on every publish");
        Assert.That(await Count("notifications.user_notifications"), Is.EqualTo(14));
        Assert.That(await EventsAsync("assessment.quiz_published"), Is.EqualTo(2));
        Assert.That(await Count("assessment.spot_quizzes", $"id = {PublishA} and published_by = {ClassAdmin}"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_publish_with_no_device_still_records_the_notification_and_the_inbox_and_stores_the_option_order()
    {
        var reply = await PostAsync(Teacher, $"/mcq/manage/{PublishA}/publish");

        Assert.That(((int)reply.Json!["deviceCount"]!, (int)reply.Json["successCount"]!, (int)reply.Json["failureCount"]!), Is.EqualTo((0, 0, 0)));
        Assert.That(await Count("notifications.notifications"), Is.EqualTo(1));
        Assert.That(await Count("notifications.user_notifications"), Is.EqualTo(7));
        Assert.That(await Count("platform.outbound_messages"), Is.Zero);
        Assert.That(await Count("assessment.spot_quiz_questions", $"spot_quiz_id = {PublishA} and option_display_order is null"), Is.Zero, "the order is fixed before anyone sees the quiz");
        Assert.That(await TextAsync("select option_display_order from assessment.spot_quiz_questions where id = 9720515"), Is.EqualTo("2,1"));
    }

    [Test]
    public async Task A_failure_of_the_announcement_leaves_the_quiz_published_with_the_event_and_counts_zero()
    {
        await AddDevicesAsync();
        await TestDatabase.ExecuteAsync($"update assessment.spot_quizzes set name = '{new string('n', 300)}' where id = {PublishA}");

        var reply = await PostAsync(Teacher, $"/mcq/manage/{PublishA}/publish");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(((int)reply.Json!["deviceCount"]!, (int)reply.Json["successCount"]!, (int)reply.Json["failureCount"]!), Is.EqualTo((0, 0, 0)));
        Assert.That(await Count("assessment.spot_quizzes", $"id = {PublishA} and published_at is not null"), Is.EqualTo(1), "a title over the column makes the notification fail: PHP's best effort too");
        Assert.That(await EventsAsync("assessment.quiz_published"), Is.EqualTo(1));
        Assert.That(await Count("notifications.notifications"), Is.Zero);
        Assert.That(await Count("platform.outbound_messages"), Is.Zero, "the failed announcement is rolled back as a whole");
    }
}
