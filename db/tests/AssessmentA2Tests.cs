using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// Batch A2 of assessment (a teacher or class admin manages a class's quizzes), against a real database through the API as the limited role. Hurl proves the wire against PHP; this proves what it cannot see:
/// who is REFUSED (each refusal pinned to its status and message), what the writes leave behind (rows, the event) and that the answer key never reaches anyone who may not manage the class.
/// World: class 9971 (teacher 903106) with the class admin 903102 and the plain student 903103; 903104 is the admin of class 9972 only (teacher 903107); 903105 was a class admin of 9971 and was removed; 903101 is in no class.
/// Quizzes: 997101 draft (2 questions), 997102 published (2 questions, answered by 903103), 997103 in class 9972, which also has 997105 and 997106 (topic "Same", the second with trailing spaces), 997107 (blank topic) and 997108 (no topic).
/// </summary>
public sealed class AssessmentA2Tests
{
    private const int Stranger = 903101;
    private const int ClassAdmin = 903102;
    private const int Student = 903103;
    private const int OtherAdmin = 903104;
    private const int RemovedAdmin = 903105;
    private const int Teacher = 903106;
    private const int OtherTeacher = 903107;
    private const int InactiveAdmin = 903112;
    private const int SuperAdmin = 903108;
    private const int GentsAdmin = 903109;
    private const int LadiesAdmin = 903110;
    private const int Coordinator = 903111;
    private const string NotAllowed = "You do not have permission to manage MCQs for this class";

    private static readonly int[] AllCopyable = [9971, 9972, 9975];
    private static readonly int[] GentsCopyable = [9971, 9972];
    private static readonly int[] LadiesCopyable = [9975];
    private static readonly int[] AssignedCopyable = [9971];
    private static readonly int[] CopyListIds = [997102, 997101];
    private static readonly int[] Managers = [Teacher, ClassAdmin, InactiveAdmin];
    private static readonly int[] ManageListIds = [997102, 997101];
    private static readonly string[] UnreachableClasses = ["/classes/99999999/mcq/manage", "/classes/9973/mcq/manage", "/classes/99999999999999999999/mcq/manage"];

    private static readonly string[] SameAndTopic = ["Same", "Topic"];

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
            "truncate access.user_roles, access.class_access_rule_conditions, access.class_access_rules restart identity cascade; truncate platform.outbox, assessment.spot_quiz_responses, assessment.spot_quiz_questions, assessment.spot_quizzes, assessment.standard_mcq_questions, assessment.standard_mcqs, classes.class_students, classes.classes restart identity cascade");
        foreach (var token in new[] { Stranger, ClassAdmin, Student, OtherAdmin, RemovedAdmin, Teacher, OtherTeacher, SuperAdmin, GentsAdmin, LadiesAdmin, Coordinator, InactiveAdmin })
        {
            await MembershipTestKit.AddMemberAsync(token, "A2 Member " + token, "1");
        }

        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, city) values "
            + $"(9971, 'A2-1', 1, 'a2lnk1', 'A2 One', 3, {Teacher}, 1, 'Offline', 'A', {Teacher}, 'Dbville'), (9972, 'A2-2', 1, 'a2lnk2', 'A2 Two', 3, {OtherTeacher}, 1, 'Offline', 'A', {OtherTeacher}, 'Dbother'), "
            + $"(9973, 'A2-3', 1, 'a2lnk3', 'A2 Closed', 3, {Teacher}, 1, 'Offline', 'I', {Teacher}, 'Dbville'), (9975, 'A2-5', 1, 'a2lnk5', 'A2 Ladies', 3, {OtherTeacher}, 2, 'Offline', 'A', {OtherTeacher}, 'Dbville'); "
            + "insert into access.user_roles (user_id, roleid) select id, v.role from (values (" + SuperAdmin + ", 1), (" + GentsAdmin + ", 3), (" + LadiesAdmin + ", 4), (" + Coordinator + ", 5)) v (token, role) join identity.users u on u.token = v.token; "
            + "insert into access.class_access_rules (id, token, gender, note, created_at) values (997901, " + Coordinator + ", 1, 'A2 db', now()); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, value) values (997901, 'city', false, 'Dbville'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin, status, removed_at) values "
            + $"(9971, {ClassAdmin}, current_date, 1, 'A', null), (9971, {Student}, current_date, 0, 'A', null), (9972, {OtherAdmin}, current_date, 1, 'A', null), (9971, {RemovedAdmin}, current_date, 1, 'I', '2025-10-01'), (9971, {InactiveAdmin}, current_date, 1, 'I', null); "
            + "insert into assessment.spot_quizzes (id, code, name, topic, class_id, published_at, deactivated_at, created_by) values "
            + $"(997101, 'A2DB1', 'Draft', 'Topic', 9971, null, null, {Teacher}), (997102, 'A2DB2', 'Published', 'Topic', 9971, '2026-01-10 10:00:00+00', null, {Teacher}), "
            + $"(997103, 'A2DB3', 'Elsewhere', 'Topic', 9972, null, null, {OtherTeacher}), (997104, 'A2DB4', 'Closed', 'Topic', 9973, null, null, {Teacher}), "
            + $"(997105, 'A2DB5', 'Same', 'Same', 9972, null, null, {OtherTeacher}), (997106, 'A2DB6', 'Same trailing', 'Same  ', 9972, null, null, {OtherTeacher}), (997107, 'A2DB7', 'Blank', '   ', 9972, null, null, {OtherTeacher}), (997108, 'A2DB8', 'No topic', null, 9972, null, null, {OtherTeacher}); "
            + "update assessment.spot_quizzes set mcq_code = 'DBS-1', deactivated_at = now() where id = 997103; "
            + "insert into assessment.standard_mcqs (id, code, language_id, level_id, topic, subject, lesson, name, sort_order) values (997301, 'DBS-1', 1, 3, 'Std topic', 'Std subject', 'Std lesson', 'Std name', 1); "
            + "insert into assessment.standard_mcq_questions (id, mcq_code, question, answer, option1) values (997311, 'DBS-1', 'sq1', 'SECRET-STD-1', 'x'), (997312, 'DBS-1', 'sq2', 'SECRET-STD-2', 'y'); "
            + "insert into assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, option3, answer) values "
            + "(997201, 997101, false, 'q1', 'SECRET-1', 'b', 'c', 1), (997202, 997101, false, 'q2', 'SECRET-2', 'b', null, 1), (997203, 997102, false, 'q3', 'SECRET-3', 'b', null, 1), (997204, 997102, false, 'q4', 'SECRET-4', 'b', null, 1), "
            + "(997205, 997103, false, 'q5', 'SECRET-5', 'b', null, 1); "
            + "insert into assessment.spot_quiz_responses (spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct) values "
            + $"(997102, 997203, {Student}, 'SECRET-3', 'SECRET-3', 1), (997102, 997204, {Student}, 'b', 'SECRET-4', 0)");
    }

    private Task<MembershipTestKit.Reply> GetAsync(int caller, string path) => kit.SendAsync(caller, HttpMethod.Get, path);

    private Task<MembershipTestKit.Reply> PostAsync(int caller, string path, string body = "{}") => kit.SendAsync(caller, HttpMethod.Post, path, body);

    private static Task<long> EventsAsync(string type) => MembershipTestKit.CountAsync("platform.outbox", $"event_type = '{type}'");

    private static readonly (int Caller, string Why)[] NotManagers =
    [
        (Student, "a plain student of the class"),
        (OtherAdmin, "the class admin of another class"),
        (RemovedAdmin, "a class admin who was removed"),
        (OtherTeacher, "the teacher of another class"),
        (Stranger, "a member of no class"),
    ];

    [Test]
    public async Task The_manage_list_is_shown_to_the_teacher_and_a_class_admin_only()
    {
        foreach (var caller in Managers)
        {
            var reply = await GetAsync(caller, "/classes/9971/mcq/manage");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
            Assert.That(reply.Json!["items"]!.AsArray().Select(i => (int)i!["id"]!), Is.EqualTo(ManageListIds));
            Assert.That((int)reply.Json["items"]![0]!["submittedCount"]!, Is.EqualTo(1));
        }

        foreach (var (caller, why) in NotManagers)
        {
            var reply = await GetAsync(caller, "/classes/9971/mcq/manage");
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotAllowed)), why);
        }
    }

    [Test]
    public async Task A_missing_or_closed_class_is_a_404_before_the_permission_check_and_no_list_carries_an_answer()
    {
        foreach (var path in UnreachableClasses)
        {
            var reply = await GetAsync(Student, path);
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")), path);
        }

        var list = await GetAsync(Teacher, "/classes/9971/mcq/manage");
        Assert.That(list.Body, Does.Not.Contain("SECRET"));
    }

    [Test]
    public async Task Topics_are_shown_to_a_manager_only_trimmed_merged_and_without_blanks()
    {
        var reply = await GetAsync(OtherTeacher, "/classes/9972/mcq/topics");
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!.AsArray().Select(t => (string?)t), Is.EqualTo(SameAndTopic), "trailing spaces merge, a blank and a missing topic are left out");

        foreach (var (caller, why) in NotManagers)
        {
            var refused = await GetAsync(caller, "/classes/9971/mcq/topics");
            Assert.That((refused.Status, refused.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotAllowed)), why);
        }

        var closed = await GetAsync(Teacher, "/classes/9973/mcq/topics");
        Assert.That((closed.Status, closed.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")));
    }

    [Test]
    public async Task The_answer_key_of_a_quiz_reaches_only_a_manager_of_its_class()
    {
        foreach (var caller in Managers)
        {
            var reply = await GetAsync(caller, "/mcq/manage/997101");
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
            Assert.That(reply.Json!["questions"]![0]!["answer"]!.GetValue<string>(), Is.EqualTo("SECRET-1"));
        }

        foreach (var quiz in new[] { 997101, 997102 })
        {
            foreach (var (caller, why) in NotManagers)
            {
                var reply = await GetAsync(caller, "/mcq/manage/" + quiz);
                Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotAllowed)), why + ", quiz " + quiz);
                Assert.That(reply.Body, Does.Not.Contain("SECRET"), why);
            }
        }

        var missing = await GetAsync(Student, "/mcq/manage/99999999");
        Assert.That((missing.Status, missing.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Quiz not found")));
        var closed = await GetAsync(Student, "/mcq/manage/997104");
        Assert.That((closed.Status, closed.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")));
    }

    [Test]
    public async Task Deactivating_sets_who_and_when_reactivating_clears_it_and_only_a_change_writes_an_event()
    {
        var first = await PostAsync(ClassAdmin, "/mcq/manage/997101/deactivate");
        Assert.That(first.Status, Is.EqualTo(HttpStatusCode.OK), first.Body);
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quizzes", $"id = 997101 and deactivated_at is not null and deactivated_by = {ClassAdmin} and modified_by is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", $"event_type = 'assessment.quiz_deactivated' and payload = '{{\"quizId\": 997101, \"classId\": 9971, \"token\": {ClassAdmin}, \"deactivated\": true}}'::jsonb"), Is.EqualTo(1), "ids and the actor only");

        await PostAsync(Teacher, "/mcq/manage/997101/deactivate");
        Assert.That(await EventsAsync("assessment.quiz_deactivated"), Is.EqualTo(1), "deactivating again is not a change");
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quizzes", $"id = 997101 and deactivated_by = {Teacher}"), Is.EqualTo(1), "PHP overwrites who and when");

        var back = await PostAsync(Teacher, "/mcq/manage/997101/deactivate", "{\"deactivate\": false}");
        Assert.That(back.Status, Is.EqualTo(HttpStatusCode.OK), back.Body);
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quizzes", $"id = 997101 and deactivated_at is null and deactivated_by is null and modified_by = {Teacher} and modified_at is not null"), Is.EqualTo(1));
        Assert.That(await EventsAsync("assessment.quiz_deactivated"), Is.EqualTo(2));

        await PostAsync(Teacher, "/mcq/manage/997101/deactivate", "{\"deactivate\": false}");
        Assert.That(await EventsAsync("assessment.quiz_deactivated"), Is.EqualTo(2), "reactivating an active quiz is not a change");
    }

    [Test]
    public async Task A_refusal_to_deactivate_changes_nothing_and_writes_no_event()
    {
        foreach (var (caller, why) in NotManagers)
        {
            var reply = await PostAsync(caller, "/mcq/manage/997101/deactivate");
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotAllowed)), why);
        }

        var missing = await PostAsync(Student, "/mcq/manage/99999999/deactivate");
        Assert.That((missing.Status, missing.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Quiz not found")));
        var closed = await PostAsync(Student, "/mcq/manage/997104/deactivate");
        Assert.That((closed.Status, closed.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")));
        var badBody = await PostAsync(Teacher, "/mcq/manage/997101/deactivate", "\"text\"");
        Assert.That((badBody.Status, badBody.Detail), Is.EqualTo((HttpStatusCode.UnprocessableEntity, "Invalid JSON body")));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quizzes", "id = 997101 and deactivated_at is not null"), Is.Zero);
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.Zero);
    }

    private const string TwoQuestions = "{\"name\": \" New name \", \"topic\": \"New topic\", \"restrictToClass\": 0, \"questions\": [{\"question\": \"Q1\", \"answer\": \"Right\", \"option2\": \"W2\", \"option5\": \"null\"}, {\"question\": \"Q2\", \"answer\": \"A\"}]}";

    [Test]
    public async Task An_edit_replaces_the_quiz_and_its_questions_in_one_step_and_writes_one_event_without_text()
    {
        var reply = await kit.SendAsync(ClassAdmin, HttpMethod.Put, "/mcq/manage/997101", TwoQuestions);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quizzes", $"id = 997101 and name = 'New name' and topic = 'New topic' and restrict_to_class = 0 and modified_by = {ClassAdmin} and modified_at is not null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_questions", "spot_quiz_id = 997101"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_questions", "id in (997201, 997202)"), Is.Zero, "the old rows are gone");
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_questions", "spot_quiz_id = 997101 and question = 'Q1' and option1 = 'Right' and option2 = 'W2' and option3 = '' and option4 = '' and option5 is null and answer = 1 and option_display_order is null and is_arabic is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_questions", "spot_quiz_id = 997102"), Is.EqualTo(2), "another quiz is untouched");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", $"event_type = 'assessment.quiz_updated' and payload = '{{\"quizId\": 997101, \"classId\": 9971, \"token\": {ClassAdmin}}}'::jsonb"), Is.EqualTo(1), "ids and the actor only");
    }

    [Test]
    public async Task An_edit_that_is_refused_changes_nothing_and_writes_no_event()
    {
        foreach (var (caller, why) in NotManagers)
        {
            var reply = await kit.SendAsync(caller, HttpMethod.Put, "/mcq/manage/997101", TwoQuestions);
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotAllowed)), why);
        }

        var attempts = new[]
        {
            ("{\"topic\": \"T\"}", HttpStatusCode.UnprocessableEntity, "name is required"),
            ("{\"name\": \"N\"}", HttpStatusCode.UnprocessableEntity, "topic is required"),
            ("{\"name\": \"N\", \"topic\": \"T\", \"questions\": [{\"question\": \"ok\", \"answer\": \"ok\"}, {\"question\": \"half\"}]}", HttpStatusCode.UnprocessableEntity, "Question 2 needs both a question and an answer"),
            ("\"text\"", HttpStatusCode.UnprocessableEntity, "Invalid JSON body"),
            ("{\"name\": \"a\\u0000b\", \"topic\": \"T\"}", HttpStatusCode.UnprocessableEntity, "name contains an invalid character"),
            ("{\"name\": \"" + new string('n', 301) + "\", \"topic\": \"T\"}", HttpStatusCode.UnprocessableEntity, "name is too long (at most 300 characters)"),
            ("{\"name\": \"N\", \"topic\": \"T\", \"questions\": [{\"question\": \"" + new string('q', 1001) + "\", \"answer\": \"A\"}]}", HttpStatusCode.UnprocessableEntity, "Question 1 is too long (the question and each option are at most 1000 characters)"),
        };
        foreach (var (body, status, message) in attempts)
        {
            var reply = await kit.SendAsync(Teacher, HttpMethod.Put, "/mcq/manage/997101", body);
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((status, message)), body.Length > 80 ? body[..80] : body);
        }

        var missing = await kit.SendAsync(Student, HttpMethod.Put, "/mcq/manage/99999999", TwoQuestions);
        Assert.That((missing.Status, missing.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Quiz not found")));
        var closed = await kit.SendAsync(Student, HttpMethod.Put, "/mcq/manage/997104", TwoQuestions);
        Assert.That((closed.Status, closed.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quizzes", "name <> 'Draft' and id = 997101"), Is.Zero);
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_questions", "id in (997201, 997202)"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.Zero);
    }

    [Test]
    public async Task FLAGGED_an_edit_of_an_answered_quiz_leaves_the_answers_behind_and_changes_the_students_score()
    {
        var before = await GetAsync(Student, "/mcq/quizzes/997102/my-score");
        Assert.That(((int)before.Json!["total"]!, (int)before.Json["correct"]!), Is.EqualTo((2, 1)));

        var edit = await kit.SendAsync(Teacher, HttpMethod.Put, "/mcq/manage/997102", "{\"name\": \"N\", \"topic\": \"T\", \"questions\": [{\"question\": \"a\", \"answer\": \"a\"}, {\"question\": \"b\", \"answer\": \"b\"}, {\"question\": \"c\", \"answer\": \"c\"}, {\"question\": \"d\", \"answer\": \"d\"}]}");
        Assert.That(edit.Status, Is.EqualTo(HttpStatusCode.OK), edit.Body);

        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_responses", "spot_quiz_id = 997102"), Is.EqualTo(2), "the answers are kept (PHP too)");
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_responses r", "r.spot_quiz_id = 997102 and not exists (select 1 from assessment.spot_quiz_questions q where q.id = r.spot_quiz_question_id)"), Is.EqualTo(2), "and now point at deleted questions");
        var after = await GetAsync(Student, "/mcq/quizzes/997102/my-score");
        Assert.That(((int)after.Json!["total"]!, (int)after.Json["correct"]!, (int)after.Json["answered"]!), Is.EqualTo((4, 1, 2)), "the same correct count over the new question count");
        Assert.That(after.Json["responses"]![0]!["questionText"], Is.Null);
    }

    [Test]
    public async Task Eight_simultaneous_edits_leave_exactly_one_set_of_questions_and_one_event_each()
    {
        var edits = Enumerable.Range(0, 8).Select(i => kit.SendAsync(ClassAdmin, HttpMethod.Put, "/mcq/manage/997101", TwoQuestions.Replace("New topic", "Topic " + i, StringComparison.Ordinal))).ToList();
        var replies = await Task.WhenAll(edits);

        Assert.That(replies.Select(r => r.Status), Is.All.EqualTo(HttpStatusCode.OK));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_questions", "spot_quiz_id = 997101"), Is.EqualTo(2), "never a doubled set");
        Assert.That(await EventsAsync("assessment.quiz_updated"), Is.EqualTo(8));
    }

    [Test]
    public async Task The_standard_list_is_shown_to_a_manager_only_never_carries_an_answer_and_counts_copies_as_PHP_does()
    {
        var mine = await GetAsync(Teacher, "/classes/9971/mcq/standard");
        Assert.That(mine.Status, Is.EqualTo(HttpStatusCode.OK), mine.Body);
        var first = mine.Json!["topics"]![0]!["subjects"]![0]!["quizzes"]![0]!;
        Assert.That(((string?)first["code"], (int)first["questionCount"]!, (bool)first["copied"]!), Is.EqualTo(("DBS-1", 2, false)));
        Assert.That(mine.Body, Does.Not.Contain("SECRET"), "only the count of the standard questions is read");

        var copied = await GetAsync(OtherTeacher, "/classes/9972/mcq/standard");
        var row = copied.Json!["topics"]![0]!["subjects"]![0]!["quizzes"]![0]!;
        Assert.That(((int)row["questionCount"]!, (bool)row["copied"]!), Is.EqualTo((2, true)), "a deactivated copy still counts, and the count is multiplied by the copies (one)");
        Assert.That(copied.Json["class"]!["languageId"]!.GetValue<int>(), Is.EqualTo(1));

        foreach (var (caller, why) in NotManagers)
        {
            var refused = await GetAsync(caller, "/classes/9971/mcq/standard");
            Assert.That((refused.Status, refused.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotAllowed)), why);
            Assert.That(refused.Body, Does.Not.Contain("DBS-1"));
        }

        var closed = await GetAsync(Teacher, "/classes/9973/mcq/standard");
        Assert.That((closed.Status, closed.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")));
    }

    [Test]
    public async Task The_copy_picker_lists_the_classes_of_the_genders_the_caller_may_copy_for_and_refuses_everyone_else()
    {
        foreach (var (caller, why) in NotManagers.Append((Teacher, "the class teacher")))
        {
            var refused = await GetAsync(caller, "/mcq/copy/classes");
            Assert.That((refused.Status, refused.Detail), Is.EqualTo((HttpStatusCode.Forbidden, "You do not have permission to copy MCQs")), why);
        }

        async Task<int[]> IdsAsync(int caller) => (await GetAsync(caller, "/mcq/copy/classes")).Json!.AsArray().Select(c => (int)c!["id"]!).ToArray();

        Assert.That(await IdsAsync(SuperAdmin), Is.EqualTo(AllCopyable), "gents first, then ladies; the closed class is never listed");
        Assert.That(await IdsAsync(GentsAdmin), Is.EqualTo(GentsCopyable), "a gents admin never gets the ladies class");
        Assert.That(await IdsAsync(LadiesAdmin), Is.EqualTo(LadiesCopyable));
        Assert.That(await IdsAsync(Coordinator), Is.EqualTo(AssignedCopyable), "a coordinator gets its assigned classes only");

        var first = (await GetAsync(GentsAdmin, "/mcq/copy/classes")).Json![0]!;
        Assert.That(((string?)first["code"], (string?)first["level"], (string?)first["city"], (string?)first["teacher"]), Is.EqualTo(("A2-1", "MIQDAD", "Dbville", "A2 Member " + Teacher)));
    }

    private static readonly int[] Copiers = [SuperAdmin, GentsAdmin, Coordinator];

    private static string[] CopyPaths(string classId) => [$"/mcq/copy/classes/{classId}/topics", $"/mcq/copy/classes/{classId}/quizzes?topic=Topic"];

    private const string CopyNotAllowed = "You do not have permission to copy MCQs from this class";

    private static readonly (int Caller, string Path, string Why)[] NotCopiers =
    [
        (Teacher, "9971", "the class teacher"),
        (ClassAdmin, "9971", "a class admin student"),
        (Student, "9971", "a plain student"),
        (Stranger, "9971", "a member of no class"),
        (LadiesAdmin, "9971", "a ladies admin on a gents class"),
        (GentsAdmin, "9975", "a gents admin on a ladies class"),
        (Coordinator, "9972", "a coordinator on a class not assigned to it"),
    ];

    [Test]
    public async Task The_copy_topics_and_quiz_lists_are_for_copiers_of_that_class_only()
    {
        foreach (var (caller, classId, why) in NotCopiers)
        {
            foreach (var path in CopyPaths(classId))
            {
                var refused = await GetAsync(caller, path);
                Assert.That((refused.Status, refused.Detail), Is.EqualTo((HttpStatusCode.Forbidden, CopyNotAllowed)), why + " " + path);
            }
        }

        foreach (var caller in Copiers)
        {
            var topics = await GetAsync(caller, "/mcq/copy/classes/9971/topics");
            Assert.That((topics.Status, topics.Json!.ToJsonString()), Is.EqualTo((HttpStatusCode.OK, "[\"Topic\"]")), "a copier");
        }

        var closed = await GetAsync(SuperAdmin, "/mcq/copy/classes/9973/topics");
        Assert.That((closed.Status, closed.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Class not found")));
    }

    [Test]
    public async Task The_copy_quiz_list_matches_the_topic_like_PHP_never_fails_on_odd_input_and_carries_no_answer()
    {
        var found = await GetAsync(SuperAdmin, "/mcq/copy/classes/9971/quizzes?topic=%20TOPIC%20");
        Assert.That(found.Status, Is.EqualTo(HttpStatusCode.OK), found.Body);
        Assert.That(found.Json!.AsArray().Select(q => (int)q!["id"]!), Is.EqualTo(CopyListIds), "case ignored, trimmed, newest first (ties by id)");
        Assert.That(found.Body, Does.Not.Contain("SECRET"));
        Assert.That(((await GetAsync(SuperAdmin, "/mcq/copy/classes/9971/quizzes?topic=Top%25")).Json!).AsArray(), Has.Count.EqualTo(2), "the wildcard is PHP's");
        Assert.That(((await GetAsync(SuperAdmin, "/mcq/copy/classes/9971/quizzes?topic=Nothing")).Json!).AsArray(), Is.Empty);

        var blank = await GetAsync(SuperAdmin, "/mcq/copy/classes/9971/quizzes?topic=%20");
        Assert.That((blank.Status, blank.Detail), Is.EqualTo((HttpStatusCode.UnprocessableEntity, "topic is required")));
        var none = await GetAsync(SuperAdmin, "/mcq/copy/classes/9971/quizzes");
        Assert.That((none.Status, none.Detail), Is.EqualTo((HttpStatusCode.UnprocessableEntity, "topic is required")));
        var nul = await GetAsync(SuperAdmin, "/mcq/copy/classes/9971/quizzes?topic=a%00b");
        Assert.That((nul.Status, nul.Body), Is.EqualTo((HttpStatusCode.OK, "[]")), "a NUL byte matches nothing and is not a 500");
    }
}
