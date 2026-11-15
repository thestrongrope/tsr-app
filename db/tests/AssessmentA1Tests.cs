using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// Batch A1 of assessment (a member takes a quiz and reads scores), against a real database through the API as the limited role. Hurl proves the wire against PHP; this proves what it cannot see:
/// who is NOT shown data (another class's student, a student who left, a stranger, a teacher, a parent of another child), and what the one write leaves behind.
/// World: class 9951 (teacher 903006) with students 903001 and 903002, 903004 left it, 903003 is only in class 9952, 903005 is in none.
/// Quizzes: 995101 live (3 questions), 995102 draft, 995103 deactivated, 995104 live in class 9952.
/// </summary>
public sealed class AssessmentA1Tests
{
    private const int Student = 903001;
    private const int Mate = 903002;
    private const int OtherClass = 903003;
    private const int Left = 903004;
    private const int Stranger = 903005;
    private const int Teacher = 903006;
    private const int ClassId = 9951;

    private static readonly string[] QuestionKeys = ["id", "text", "isArabic", "options"];
    private static readonly string[] FirstOptions = ["Alpha", "Beta", "Gamma", "I don't know"];

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
            "truncate platform.outbox, assessment.spot_quiz_responses, assessment.spot_quiz_questions, assessment.spot_quizzes, classes.class_students, classes.classes restart identity cascade");
        foreach (var token in new[] { Student, Mate, OtherClass, Left, Stranger, Teacher })
        {
            await MembershipTestKit.AddMemberAsync(token, "A1 Member " + token, "1");
        }

        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values "
            + $"({ClassId}, 'A1-1', 1, 'a1lnk1', 'A1 One', 3, {Teacher}, 1, 'Offline', 'A', {Teacher}), (9952, 'A1-2', 1, 'a1lnk2', 'A1 Two', 3, {Teacher}, 1, 'Offline', 'A', {Teacher}); "
            + "insert into classes.class_students (class_id, token_no, joined_on, status, removed_at) values "
            + $"({ClassId}, {Student}, current_date, 'A', null), ({ClassId}, {Mate}, current_date, 'A', null), ({ClassId}, {Left}, current_date, 'I', '2025-10-01'), (9952, {OtherClass}, current_date, 'A', null); "
            + "insert into assessment.spot_quizzes (id, code, name, topic, class_id, published_at, deactivated_at, created_by) values "
            + "(995101, 'A1DB1', 'Live', 'Topic', 9951, '2026-01-10 10:00:00+00', null, 903006), (995102, 'A1DB2', 'Draft', null, 9951, null, null, 903006), "
            + "(995103, 'A1DB3', 'Deactivated', null, 9951, '2026-01-09 10:00:00+00', '2026-01-11 10:00:00+00', 903006), (995104, 'A1DB4', 'Elsewhere', null, 9952, '2026-01-08 10:00:00+00', null, 903006); "
            + "insert into assessment.spot_quiz_questions (id, spot_quiz_id, is_arabic, question, option1, option2, option3, answer) values "
            + "(995201, 995101, false, 'q1', 'Alpha', 'Beta', 'Gamma', 1), (995202, 995101, false, 'q2', 'Red', 'Green', 'Blue', 2), (995203, 995101, true, 'q3', 'نعم', 'لا', null, 1), "
            + "(995204, 995102, false, 'q4', 'a', 'b', null, 1), (995205, 995103, false, 'q5', 'a', 'b', null, 1), (995206, 995104, false, 'q6', 'a', 'b', null, 1); "
            + "insert into assessment.spot_quiz_responses (spot_quiz_id, spot_quiz_question_id, token, response, correct_response, is_correct) values "
            + $"(995101, 995201, {Mate}, 'Alpha', 'Alpha', 1), (995101, 995202, {Mate}, 'Green', 'Green', 1), (995101, 995203, {Mate}, 'نعم', 'نعم', 1)");
    }

    private Task<MembershipTestKit.Reply> GetAsync(int caller, string path) => kit.SendAsync(caller, HttpMethod.Get, path);

    [Test]
    public async Task A_quiz_is_shown_only_to_a_current_student_of_its_class_and_only_once_published()
    {
        Assert.That((await GetAsync(Student, "/mcq/quizzes/995101")).Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That((await GetAsync(Student, "/mcq/quizzes/995103")).Status, Is.EqualTo(HttpStatusCode.OK), "deactivated is still visible");

        foreach (var (caller, quiz) in new[] { (OtherClass, 995101), (Left, 995101), (Stranger, 995101), (Teacher, 995101), (Student, 995102), (Student, 995104) })
        {
            var reply = await GetAsync(caller, "/mcq/quizzes/" + quiz);
            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.NotFound), $"{caller} must not see {quiz}");
            Assert.That(reply.Detail, Is.EqualTo("Quiz not found"));
        }
    }

    [Test]
    public async Task The_detail_carries_the_callers_own_attempt_not_a_classmates()
    {
        var mine = (await GetAsync(Student, "/mcq/quizzes/995101")).Json!;
        var mates = (await GetAsync(Mate, "/mcq/quizzes/995101")).Json!;

        Assert.That((bool)mine["attempted"]!, Is.False);
        Assert.That(mine["score"], Is.Null);
        Assert.That((bool)mates["attempted"]!, Is.True);
        Assert.That((int)mates["score"]!, Is.EqualTo(3));
        Assert.That((int)mine["questionCount"]!, Is.EqualTo(3));
    }

    [Test]
    public async Task Questions_are_shown_only_to_a_current_student_who_has_not_scored_and_never_say_which_option_is_right()
    {
        var reply = await GetAsync(Student, "/mcq/quizzes/995101/questions");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var items = reply.Json!["items"]!.AsArray();
        Assert.That(items, Has.Count.EqualTo(3));
        var first = items[0]!.AsObject();
        Assert.That(first.Select(p => p.Key), Is.EqualTo(QuestionKeys), "no answer column, no option number");
        Assert.That(first["options"]!.AsArray().Select(o => (string?)o), Is.EquivalentTo(FirstOptions));

        foreach (var (caller, quiz) in new[] { (OtherClass, 995101), (Left, 995101), (Stranger, 995101), (Teacher, 995101), (Student, 995102), (Student, 995104) })
        {
            Assert.That((await GetAsync(caller, "/mcq/quizzes/" + quiz + "/questions")).Status, Is.EqualTo(HttpStatusCode.NotFound), $"{caller} must not read the questions of {quiz}");
        }
    }

    [Test]
    public async Task Questions_are_refused_to_a_member_who_scored_and_while_the_quiz_is_deactivated()
    {
        Assert.That((await GetAsync(Mate, "/mcq/quizzes/995101/questions")).Status, Is.EqualTo(HttpStatusCode.Conflict), "scored above zero");
        Assert.That((await GetAsync(Student, "/mcq/quizzes/995103/questions")).Detail, Is.EqualTo("This quiz is not currently available"));
    }

    [Test]
    public async Task My_score_shows_only_the_callers_own_answers_to_a_quiz_they_may_see()
    {
        var mine = await GetAsync(Mate, "/mcq/quizzes/995101/my-score");
        Assert.That(mine.Status, Is.EqualTo(HttpStatusCode.OK), mine.Body);
        Assert.That((int)mine.Json!["correct"]!, Is.EqualTo(3));
        Assert.That(mine.Json["responses"]!.AsArray(), Has.Count.EqualTo(3));

        var classmate = await GetAsync(Student, "/mcq/quizzes/995101/my-score");
        Assert.That((classmate.Status, classmate.Detail), Is.EqualTo((HttpStatusCode.NotFound, "No attempt found")), "a classmate's answers are not mine");

        foreach (var caller in new[] { OtherClass, Left, Stranger, Teacher })
        {
            var reply = await GetAsync(caller, "/mcq/quizzes/995101/my-score");
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Quiz not found")), $"{caller} must not read a result of this quiz");
        }
    }

    private const string Answers = """{"responses": [{"questionId": 995202, "selectedText": "Green"}, {"questionId": 995201, "selectedText": " alpha "}, {"questionId": 995203, "selectedText": "لا"}]}""";

    private Task<MembershipTestKit.Reply> SubmitAsync(int caller, string quiz, string body) => kit.SendAsync(caller, HttpMethod.Post, $"/mcq/quizzes/{quiz}/responses", body);

    [Test]
    public async Task Submitting_stores_one_scored_row_per_question_and_exactly_one_event_without_the_answers()
    {
        var reply = await SubmitAsync(Student, "995101", Answers);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That((int)reply.Json!["correct"]!, Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_responses", $"token = {Student} and spot_quiz_id = 995101"), Is.EqualTo(3));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_responses", $"token = {Student} and is_correct = 1 and response in ('Green', ' alpha ') and correct_response in ('Green', 'Alpha')"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_responses", $"token = {Student} and is_correct = 0 and correct_response = 'نعم' and response = 'لا'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
        var payload = await TestDatabase.RowAsync("select event_type, payload::text as payload from platform.outbox");
        Assert.That(payload!["event_type"], Is.EqualTo("assessment.quiz_answered"));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", $"payload = '{{\"quizId\": 995101, \"classId\": {ClassId}, \"token\": {Student}}}'::jsonb"), Is.EqualTo(1), "exactly these three fields, no answers");
    }

    [Test]
    public async Task A_refusal_writes_no_response_and_no_event()
    {
        var wrongQuestions = """{"responses": [{"questionId": 995201, "selectedText": "Alpha"}]}""";
        // Each refusal is pinned to the guard that must give it: remove a guard and its line fails, even though a later check would still refuse.
        var attempts = new[]
        {
            (OtherClass, "995101", Answers, 404, "Quiz not found"), (Left, "995101", Answers, 404, "Quiz not found"), (Stranger, "995101", Answers, 404, "Quiz not found"),
            (Teacher, "995101", Answers, 404, "Quiz not found"), (Student, "995102", Answers, 404, "Quiz not found"), (Student, "995103", Answers, 409, "This quiz is not currently available"),
            (Student, "995104", Answers, 404, "Quiz not found"), (Mate, "995101", Answers, 409, "Already attempted"), (Student, "995101", wrongQuestions, 400, "\"missing\":[995202,995203]"),
            (Student, "995101", "{}", 400, "Payload requires non-empty responses"), (Student, "995101", "abc", 422, "Invalid JSON body"),
            (Student, "995101", """{"responses": [{"questionId": 995201, "selectedText": "Alpha"}, {"questionId": 995202, "selectedText": "x"}, {"questionId": 995203, "selectedText": "\u0000"}, {"questionId": 5}]}""", 400, "\"extra\":[5]"),
            (Student, "995101", $"{{\"responses\": [{{\"questionId\": 995201, \"selectedText\": \"{new string('x', 1001)}\"}}, {{\"questionId\": 995202}}, {{\"questionId\": 995203}}]}}", 400, "selectedText is too long"),
        };
        var before = await MembershipTestKit.CountAsync("assessment.spot_quiz_responses");

        foreach (var (caller, quiz, body, status, detail) in attempts)
        {
            var reply = await SubmitAsync(caller, quiz, body);
            Assert.That((int)reply.Status, Is.EqualTo(status), $"{caller} on {quiz}: {reply.Body}");
            Assert.That(reply.Body, Does.Contain(detail), $"{caller} on {quiz}");
        }

        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_responses"), Is.EqualTo(before));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.Zero);
    }

    [Test]
    public async Task Simultaneous_submissions_by_one_member_give_one_success_and_leave_one_set_of_rows_and_one_event()
    {
        var replies = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => SubmitAsync(Student, "995101", Answers)));

        Assert.That(replies.Count(r => r.Status == HttpStatusCode.OK), Is.EqualTo(1), string.Join(" | ", replies.Select(r => (int)r.Status + " " + r.Body)));
        Assert.That(replies.Count(r => r.Status == HttpStatusCode.Conflict), Is.EqualTo(7));
        Assert.That(await MembershipTestKit.CountAsync("assessment.spot_quiz_responses", $"token = {Student}"), Is.EqualTo(3));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_code_tells_only_a_current_student_more_than_not_eligible()
    {
        async Task<string?> StateAsync(int caller, string code) => (await GetAsync(caller, "/mcq/by-code/" + code)).Json!["state"]!.GetValue<string>();

        Assert.That(await StateAsync(Student, "A1DB1"), Is.EqualTo("open"));
        Assert.That(await StateAsync(Student, "a1db1"), Is.EqualTo("open"), "ignoring case");
        Assert.That(await StateAsync(Mate, "A1DB1"), Is.EqualTo("attempted"));
        Assert.That(await StateAsync(Student, "A1DB2"), Is.EqualTo("not_released"));
        Assert.That(await StateAsync(Student, "A1DB3"), Is.EqualTo("closed"));
        Assert.That(await StateAsync(Student, "A1DB9"), Is.EqualTo("not_found"));

        foreach (var caller in new[] { OtherClass, Left, Stranger, Teacher })
        {
            foreach (var code in new[] { "A1DB1", "A1DB2", "A1DB3" })
            {
                var reply = await GetAsync(caller, "/mcq/by-code/" + code);
                Assert.That(reply.Json!.ToJsonString(), Is.EqualTo("""{"state":"not_eligible","quizId":null}"""), $"{caller} on {code}");
            }
        }
    }

    [Test]
    public async Task The_open_list_is_the_callers_own_classes_without_answered_drafts_or_deactivated_quizzes_and_stops_at_20()
    {
        await TestDatabase.ExecuteAsync(
            "insert into assessment.spot_quizzes (code, name, class_id, published_at, created_by) "
            + "select 'A1BULK' || g, 'Bulk ' || g, 9951, '2026-03-01 10:00:00+00'::timestamptz + g * interval '1 minute', 903006 from generate_series(1, 25) g");

        var mine = (await GetAsync(Student, "/mcq/open")).Json!["items"]!.AsArray();

        Assert.That(mine, Has.Count.EqualTo(20));
        Assert.That(mine.Select(i => (string?)i!["name"]), Does.Not.Contain("Draft").And.Not.Contain("Deactivated").And.Not.Contain("Elsewhere"));
        Assert.That((string?)mine[0]!["name"], Is.EqualTo("Bulk 25"), "newest first");

        foreach (var caller in new[] { OtherClass, Left, Stranger, Teacher })
        {
            var theirs = (await GetAsync(caller, "/mcq/open")).Json!["items"]!.AsArray();
            Assert.That(theirs.Select(i => (string?)i!["name"]), Does.Not.Contain("Live").And.Not.Contain("Bulk 25"), $"{caller} must not see class 9951 quizzes");
        }

        var mates = (await GetAsync(Mate, "/mcq/open")).Json!["items"]!.AsArray();
        Assert.That(mates.Select(i => (string?)i!["name"]), Does.Not.Contain("Live"), "answered by the caller: not listed");
    }

    [Test]
    public async Task A_class_list_is_refused_to_everyone_but_a_current_student_and_carries_only_their_attempt()
    {
        foreach (var caller in new[] { OtherClass, Left, Stranger, Teacher })
        {
            Assert.That((await GetAsync(caller, $"/classes/{ClassId}/mcq/quizzes")).Status, Is.EqualTo(HttpStatusCode.Forbidden), $"{caller} must not list class {ClassId}");
        }

        var mine = await GetAsync(Student, $"/classes/{ClassId}/mcq/quizzes");
        var mates = await GetAsync(Mate, $"/classes/{ClassId}/mcq/quizzes");

        Assert.That(mine.Status, Is.EqualTo(HttpStatusCode.OK), mine.Body);
        Assert.That((int)mine.Json!["total"]!, Is.EqualTo(2), "the draft is not listed; the deactivated quiz is");
        Assert.That(mine.Json["items"]!.AsArray().Select(i => (bool)i!["attempted"]!), Is.All.False);
        var live = mates.Json!["items"]!.AsArray().Single(i => (int)i!["id"]! == 995101)!;
        Assert.That(((bool)live["attempted"]!, (int)live["score"]!, (int)live["total"]!), Is.EqualTo((true, 3, 3)));
        Assert.That(mates.Body, Does.Not.Contain("Alpha").And.Not.Contain("correct"), "no question or answer in a list");
    }

    [Test]
    public async Task My_scores_lists_only_the_callers_own_answers_for_a_current_student_and_survives_a_NUL_in_a_date()
    {
        foreach (var caller in new[] { OtherClass, Left, Stranger, Teacher })
        {
            Assert.That((await GetAsync(caller, $"/classes/{ClassId}/my-scores")).Status, Is.EqualTo(HttpStatusCode.NotFound), $"{caller} must not read scores of class {ClassId}");
        }

        Assert.That((await GetAsync(Student, $"/classes/{ClassId}/my-scores")).Body, Is.EqualTo("[]"), "a classmate's answers are not mine");
        var mate = (await GetAsync(Mate, $"/classes/{ClassId}/my-scores")).Json!.AsArray();
        Assert.That(mate, Has.Count.EqualTo(1));
        Assert.That(((int)mate[0]!["quizId"]!, (int)mate[0]!["score"]!, (int)mate[0]!["total"]!), Is.EqualTo((995101, 3, 3)));

        var start = await GetAsync(Mate, $"/classes/{ClassId}/my-scores?start_date=2026-01-01%00x");
        var end = await GetAsync(Mate, $"/classes/{ClassId}/my-scores?end_date=%00");
        Assert.That((start.Status, end.Status), Is.EqualTo((HttpStatusCode.OK, HttpStatusCode.OK)), start.Body + end.Body);
        Assert.That(start.Json!.AsArray(), Has.Count.EqualTo(1), "an unreadable start bounds nothing");
        Assert.That(end.Json!.AsArray(), Is.Empty, "an unreadable end lists nothing");
    }

    [Test]
    public async Task A_parent_reads_a_childs_scores_only_with_an_active_link_to_that_child_and_the_child_in_the_class()
    {
        const int Parent = 903010;
        const int Revoked = 903011;
        const int ParentOfStudent = 903012;
        var users = new Dictionary<int, int>();
        foreach (var token in new[] { Parent, Revoked, ParentOfStudent })
        {
            users[token] = await MembershipTestKit.AddMemberAsync(token, "A1 Parent " + token, "1");
        }

        await TestDatabase.ExecuteAsync(
            "insert into membership.user_guardians (parent_token, child_token, relationship, status, source, created_by, created_at, activated_at) values "
            + $"({Parent}, {Mate}, 'father', 'active', 'token_entry', {users[Parent]}, now(), now()), ({Revoked}, {Mate}, 'father', 'revoked', 'token_entry', {users[Revoked]}, now(), now()), "
            + $"({ParentOfStudent}, {Student}, 'father', 'active', 'token_entry', {users[ParentOfStudent]}, now(), now())");

        var scores = await GetAsync(Parent, $"/me/children/{Mate}/classes/{ClassId}/scores");
        Assert.That(scores.Status, Is.EqualTo(HttpStatusCode.OK), scores.Body);
        Assert.That(scores.Json!.AsArray(), Has.Count.EqualTo(1));
        Assert.That(((int)scores.Json[0]!["quiz_id"]!, (int)scores.Json[0]!["score"]!, (int)scores.Json[0]!["total_questions"]!), Is.EqualTo((995101, 3, 3)));

        foreach (var (caller, child, classId) in new[] { (Revoked, Mate, ClassId), (ParentOfStudent, Mate, ClassId), (Stranger, Mate, ClassId), (Mate, Mate, ClassId), (Teacher, Mate, ClassId), (Parent, Mate, 9952), (Parent, Student, ClassId) })
        {
            var reply = await GetAsync(caller, $"/me/children/{child}/classes/{classId}/scores");
            Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.NotFound, "Child or class not found")), $"{caller} for child {child} in class {classId}");
        }

        Assert.That((await GetAsync(ParentOfStudent, $"/me/children/{Student}/classes/{ClassId}/scores")).Body, Is.EqualTo("[]"), "the parent of another child sees that child's own list");
    }
}
