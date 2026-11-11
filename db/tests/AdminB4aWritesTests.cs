using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The writes of the /admin routes of batch B4a (syllabus, the transfer batch, enrolment by token, teacher training and import): rows, the one outbox row per change, nothing for a refusal. Hurl cannot see these
/// tables, so this goes through the API as the limited role.
/// </summary>
public sealed class AdminB4aWritesTests
{
    private const int Admin = 901301;
    private const int Teacher = 901302;
    private const int Source = 9931;
    private const int Destination = 9932;
    private const int Cohort = 9933;
    private const int LadiesClass = 9934;

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
            "truncate platform.outbox, classes.syllabus, classes.teachers_history, classes.teachers, classes.student_transfers, classes.class_students, classes.classes restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "B4 Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "B4 Teacher", "1");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({admin}, 1)");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values "
            + $"({Source}, 'B4-S', 1, 'b4link1', 'Source', 3, {Teacher}, 1, 'Offline', 'A', {Admin}), ({Destination}, 'B4-D', 1, 'b4link2', 'Destination', 3, {Teacher}, 1, 'Offline', 'A', {Admin}), "
            + $"({Cohort}, 'B4-C', 1, 'b4link3', 'Closed', 3, {Teacher}, 1, 'Offline', 'I', {Admin}), ({LadiesClass}, 'B4-L', 1, 'b4link4', 'Ladies', 1, {Teacher}, 2, 'Offline', 'A', {Admin})");
    }

    [Test]
    public async Task A_syllabus_item_is_created_edited_and_deleted_with_the_callers_token_and_one_event_each()
    {
        var created = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/syllabus", """{"level_id": 3, "subject_name": "Item", "url": "https://example.invalid/i"}""");
        Assert.That(created.Status, Is.EqualTo(HttpStatusCode.Created), created.Body);
        var id = created.Json!["id"]!.GetValue<int>();
        Assert.That(await MembershipTestKit.CountAsync("classes.syllabus", $"id = {id} and created_by = {Admin} and is_active = 1 and modified_at is null and deleted_at is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.syllabus_item_created'"), Is.EqualTo(1));

        Assert.That((await kit.SendAsync(Admin, HttpMethod.Put, $"/admin/syllabus/{id}", """{"is_active": false}""")).Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await MembershipTestKit.CountAsync("classes.syllabus", $"id = {id} and is_active = 0 and modified_at is not null and modified_by = {Admin}"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.syllabus_item_updated'"), Is.EqualTo(1));

        Assert.That((await kit.SendAsync(Admin, HttpMethod.Delete, $"/admin/syllabus/{id}")).Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(await MembershipTestKit.CountAsync("classes.syllabus", $"id = {id} and deleted_at is not null and deleted_by = {Admin} and modified_at is not null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.syllabus_item_deleted'"), Is.EqualTo(1));

        Assert.That((await kit.SendAsync(Admin, HttpMethod.Delete, $"/admin/syllabus/{id}")).Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That((await kit.SendAsync(Admin, HttpMethod.Put, $"/admin/syllabus/{id}", """{"url": "x"}""")).Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(3), "a refusal writes no event");
    }

    [Test]
    public async Task A_refused_syllabus_write_leaves_no_row_and_no_event()
    {
        Assert.That((await kit.SendAsync(Admin, HttpMethod.Post, "/admin/syllabus", """{"level_id": 99, "subject_name": "Item", "url": "u"}""")).Status, Is.EqualTo(HttpStatusCode.BadRequest));
        Assert.That((await kit.SendAsync(Admin, HttpMethod.Post, "/admin/syllabus", """{"level_id": 3, "subject_name": "Item", "url": "u", "sort_order": "x"}""")).Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await MembershipTestKit.CountAsync("classes.syllabus"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    private static async Task AddStudentsAsync(params int[] tokens)
    {
        foreach (var token in tokens)
        {
            await MembershipTestKit.AddMemberAsync(token, "B4 Student " + token, "1");
        }
    }

    [Test]
    public async Task A_batch_moves_each_student_in_a_transaction_of_its_own_and_one_event_per_move()
    {
        await AddStudentsAsync(901311, 901312);
        await TestDatabase.ExecuteAsync(
            "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin) values "
            + $"({Source}, 901311, current_date, 1), ({Source}, 901312, current_date, 0), ({Destination}, 901312, current_date, 0)");

        var reply = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/transfers", $$"""{"fromClassId": {{Source}}, "toClassId": {{Destination}}, "type": "promotion", "reason": "Ready", "tokens": [901311, 901312]}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["moved"]!.AsArray().Count, Is.EqualTo(1));
        Assert.That(reply.Json["failed"]![0]!["reason"]!.GetValue<string>(), Is.EqualTo($"Student 901312 is already enrolled in destination class #{Destination}"));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Source} and token_no = 901311 and status = 'I' and removed_by = {Admin} and removed_reason = 'Promotion to class #{Destination}: Ready' and mcq_admin = 1"), Is.EqualTo(1), "the removal names the move and keeps the MCQ flag");
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Destination} and token_no = 901311 and status = 'A' and removed_at is null and added_by is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Source} and token_no = 901312 and status = 'A'"), Is.EqualTo(1), "the student who could not move stays");
        Assert.That(await MembershipTestKit.CountAsync("classes.student_transfers", $"token_no = 901311 and from_class_id = {Source} and to_class_id = {Destination} and type = 'promotion' and reason = 'Ready' and transferred_by = {Admin}"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.student_transfers"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.student_transferred'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_student_whose_write_fails_is_rolled_back_whole_and_reported_as_not_moved()
    {
        await AddStudentsAsync(901311);
        await TestDatabase.ExecuteAsync($"insert into classes.class_students (class_id, token_no, joined_on) values ({Source}, 901311, current_date)");
        var reason = new string('r', 490);

        var reply = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/transfers", $$"""{"fromClassId": {{Source}}, "toClassId": {{Destination}}, "type": "transfer", "reason": "{{reason}}", "tokens": [901311]}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["failed"]![0]!["reason"]!.GetValue<string>(), Is.EqualTo("Could not be moved"));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Source} and token_no = 901311 and status = 'A' and removed_at is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Destination}"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("classes.student_transfers"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_student_of_a_deactivated_class_is_rehomed_and_the_old_rows_stay_as_the_audit_trail()
    {
        await AddStudentsAsync(901311, 901312);
        await TestDatabase.ExecuteAsync(
            "insert into classes.class_students (class_id, token_no, joined_on, removed_at, removed_by, removed_reason, status) values "
            + $"({Cohort}, 901311, current_date, '2025-10-05', 7, 'Class deactivated: closing', 'I'), ({Cohort}, 901312, current_date, '2025-10-05', 7, 'Class deactivated: closing', 'I'); "
            + $"insert into classes.class_students (class_id, token_no, joined_on) values ({Source}, 901312, current_date)");

        var reply = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/transfers", $$"""{"fromClassId": {{Cohort}}, "toClassId": {{Destination}}, "type": "transfer", "tokens": [901311, 901312]}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["moved"]![0]!["token"]!.GetValue<int>(), Is.EqualTo(901311));
        Assert.That(reply.Json["failed"]![0]!["reason"]!.GetValue<string>(), Is.EqualTo("Student 901312 already has an active class; skipped"));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Cohort} and token_no = 901311 and removed_by = 7 and removed_reason = 'Class deactivated: closing'"), Is.EqualTo(1), "the cohort row is not rewritten");
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Destination} and token_no = 901311 and status = 'A'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.student_transferred'"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_new_member_is_enrolled_with_an_accepted_request_and_one_event_and_a_second_call_writes_nothing()
    {
        await AddStudentsAsync(901321);

        var first = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/members/901321/enrolments", $$"""{"classId": {{Source}}}""");

        Assert.That(first.Status, Is.EqualTo(HttpStatusCode.OK), first.Body);
        Assert.That(first.Json!["saved"]!.GetValue<bool>(), Is.True);
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Source} and token_no = 901321 and status = 'A' and added_by = {Admin} and joined_on = current_date"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = 901321 and for_classid = {Source} and status = 'Accepted'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.student_enrolled' and payload ->> 'source' = 'by_token'"), Is.EqualTo(1));

        var second = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/members/901321/enrolments", $$"""{"classId": {{Source}}}""");

        Assert.That(second.Status, Is.EqualTo(HttpStatusCode.Conflict));
        Assert.That(second.Json!["code"]!.GetValue<string>(), Is.EqualTo("already_enrolled"));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", "token_no = 901321"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_member_with_a_removed_row_gets_the_latest_one_back_and_keeps_an_existing_request()
    {
        await AddStudentsAsync(901322);
        await TestDatabase.ExecuteAsync(
            "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin, removed_at, removed_by, removed_reason, status) values "
            + $"({Source}, 901322, '2025-01-01', 1, '2025-02-01', 7, 'first', 'I'), ({Source}, 901322, '2025-03-01', 1, '2025-04-01', 7, 'second', 'I'); "
            + $"insert into membership.class_registrations (token, for_classid, status) values (901322, {Destination}, 'Pending')");

        var reply = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/members/901322/enrolments", $$"""{"classId": {{Source}}}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", "token_no = 901322"), Is.EqualTo(2), "no third row");
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"token_no = 901322 and removed_reason = 'second'"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"token_no = 901322 and removed_reason = 'first' and status = 'I'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"token_no = 901322 and status = 'A' and removed_at is null and removed_by is null and removed_reason is null and mcq_admin = 0 and added_by = {Admin} and joined_on = current_date"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", "token = 901322"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.student_restored'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_refused_enrolment_writes_nothing()
    {
        await AddStudentsAsync(901323);

        var gender = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/members/901323/enrolments", $$"""{"classId": {{LadiesClass}}}""");
        var unknown = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/members/901399/enrolments", $$"""{"classId": {{Source}}}""");

        Assert.That(gender.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(gender.Json!["code"]!.GetValue<string>(), Is.EqualTo("other_gender"));
        Assert.That(unknown.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    [Test]
    public async Task Training_writes_a_record_a_history_row_and_an_event_per_distinct_teacher_and_reactivates_an_inactive_record()
    {
        await AddStudentsAsync(901331, 901332);
        await TestDatabase.ExecuteAsync("insert into classes.teachers (token, salman, abuzar, miqdad, ammar, bilal, comments, status, created_by) values (901332, 0, 0, 0, 0, 1, 'old', 'I', 1)");

        var reply = await kit.SendAsync(
            Admin,
            HttpMethod.Post,
            "/admin/teachers/training",
            """{"comments": " Batch note ", "changes": [{"token": 901331, "level": "salman", "action": "added"}, {"token": 901331, "level": "miqdad", "action": "added"}, {"token": 901332, "level": "bilal", "action": "removed"}]}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["changed"]!.GetValue<int>(), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("classes.teachers", $"token = 901331 and salman = 1 and miqdad = 1 and status = 'A' and created_by = {Admin} and comments ~ '^ADD: Batch note - Batch ID: [0-9a-f]{{13}} - \\+SM, \\+MK$'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.teachers", $"token = 901332 and bilal = 0 and status = 'A' and updated_by = {Admin} and updated_at is not null and comments ~ '^UPDATE: Batch note - Batch ID: [0-9a-f]{{13}} - -BL$'"), Is.EqualTo(1), "an inactive record is reactivated");
        Assert.That(await MembershipTestKit.CountAsync("classes.teachers_history", $"status = 'A' and created_by = {Admin}"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.teacher_training_changed'"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_refused_training_batch_writes_nothing_even_for_the_teachers_judged_before_the_refusal()
    {
        await AddStudentsAsync(901331);

        var reply = await kit.SendAsync(
            Admin,
            HttpMethod.Post,
            "/admin/teachers/training",
            """{"comments": "x", "changes": [{"token": 901331, "level": "salman", "action": "added"}, {"token": 999999, "level": "salman", "action": "added"}]}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await MembershipTestKit.CountAsync("classes.teachers"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("classes.teachers_history"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    [Test]
    public async Task Import_gives_a_record_to_each_ladies_teacher_of_an_active_class_without_one_and_a_second_call_adds_nobody()
    {
        await MembershipTestKit.AddMemberAsync(901341, "B4 Ladies Teacher", "2");
        await MembershipTestKit.AddMemberAsync(901342, "B4 Trained Ladies Teacher", "2");
        await TestDatabase.ExecuteAsync(
            "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values "
            + $"(9941, 'B4-L1', 1, 'b4link5', 'L1', 3, 901341, 2, 'Offline', 'A', {Admin}), (9942, 'B4-L2', 1, 'b4link6', 'L2', 1, 901341, 2, 'Offline', 'A', {Admin}), (9943, 'B4-L3', 1, 'b4link7', 'L3', 3, 901342, 2, 'Offline', 'A', {Admin}); "
            + "insert into classes.teachers (token, salman, abuzar, miqdad, ammar, bilal, comments, status, created_by) values (901342, 0, 0, 1, 0, 0, 'kept', 'A', 1)");

        var first = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/teachers/import", """{"gender": 2}""");

        Assert.That(first.Status, Is.EqualTo(HttpStatusCode.OK), first.Body);
        Assert.That(first.Json!["added"]!.GetValue<int>(), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.teachers", $"token = 901341 and salman = 1 and abuzar = 1 and bilal = 1 and status = 'A' and created_by = {Admin} and comments ~ '^ADD: Imported from Active Classes - Batch ID: [0-9a-f]{{13}} - \\+SM, \\+AG, \\+MK, \\+AY, \\+BL$'"), Is.EqualTo(1), "the lowest level taught is 1");
        Assert.That(await MembershipTestKit.CountAsync("classes.teachers", "token = 901342 and comments = 'kept'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.teachers_history", "token = 901341"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.teacher_training_changed'"), Is.EqualTo(1));

        var second = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/teachers/import", """{"gender": 2}""");

        Assert.That(second.Json!["added"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    /// <summary>PHP ClassesModel::getAll limits a caller whose only class reach is "assigned" to those classes, whatever named grant opened the screen.</summary>
    [Test]
    public async Task A_coordinator_holding_a_named_grant_sees_and_moves_only_the_assigned_classes()
    {
        const int Coordinator = 901303;
        var coordinator = await MembershipTestKit.AddMemberAsync(Coordinator, "B4 Coordinator", "2");
        await AddStudentsAsync(901311);
        await TestDatabase.ExecuteAsync(
            "truncate access.class_access_rule_conditions, access.class_access_rules, access.user_permissions restart identity cascade; "
            + $"insert into access.user_roles (user_id, roleid) values ({coordinator}, 5); "
            + $"insert into access.user_permissions (user_id, permission) values ({coordinator}, 'students:transfer:all'), ({coordinator}, 'deactivated-classes:manage:all'); "
            + $"insert into access.class_access_rules (id, token, gender, note) values (1, {Coordinator}, 2, 'ladies level 1'); "
            + "insert into access.class_access_rule_conditions (rule_id, field, negate, level_id) values (1, 'level', false, 1); "
            + $"insert into classes.class_students (class_id, token_no, joined_on, mcq_admin) values ({Source}, 901311, current_date, 0)");

        var listed = await kit.SendAsync(Coordinator, HttpMethod.Get, "/admin/transfers/classes");
        Assert.That(listed.Status, Is.EqualTo(HttpStatusCode.OK), listed.Body);
        Assert.That(listed.Json!["classes"]!.AsArray().Select(c => c!["id"]!.GetValue<int>()), Is.EqualTo(new[] { LadiesClass }));

        var candidates = await kit.SendAsync(Coordinator, HttpMethod.Get, "/admin/deactivated-classes/candidates");
        Assert.That(candidates.Status, Is.EqualTo(HttpStatusCode.OK), candidates.Body);
        Assert.That(candidates.Json!["classes"]!.AsArray().Select(c => c!["id"]!.GetValue<int>()), Is.EqualTo(new[] { LadiesClass }));

        Assert.That((await kit.SendAsync(Coordinator, HttpMethod.Get, $"/admin/transfers/classes/{Source}/students")).Status, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That((await kit.SendAsync(Coordinator, HttpMethod.Get, $"/admin/transfers/classes/{LadiesClass}/students")).Status, Is.EqualTo(HttpStatusCode.OK));

        var moved = await kit.SendAsync(Coordinator, HttpMethod.Post, "/admin/transfers", $$"""{"fromClassId": {{Source}}, "toClassId": {{Destination}}, "type": "transfer", "reason": "move", "tokens": [901311]}""");
        Assert.That(moved.Status, Is.EqualTo(HttpStatusCode.NotFound), moved.Body);
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {Source} and token_no = 901311 and removed_at is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    /// <summary>PostgreSQL text cannot hold a NUL byte: a search for one finds nothing, and a comment with one is refused, neither a 500.</summary>
    [Test]
    public async Task A_NUL_byte_in_the_history_search_or_a_training_comment_is_not_a_server_error()
    {
        var searched = await kit.SendAsync(Admin, HttpMethod.Get, "/admin/transfers/history?q=a%00b");
        Assert.That(searched.Status, Is.EqualTo(HttpStatusCode.OK), searched.Body);
        Assert.That(searched.Json!["total"]!.GetValue<int>(), Is.EqualTo(0));

        var trained = await kit.SendAsync(Admin, HttpMethod.Post, "/admin/teachers/training", """{"comments": "a\u0000b", "changes": [{"token": 901302, "level": "salman", "action": "added"}]}""");
        Assert.That(trained.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), trained.Body);
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }
}
