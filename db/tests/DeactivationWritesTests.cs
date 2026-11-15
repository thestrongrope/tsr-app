using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// POST /classes/{id}/deactivate writes the class, its students, its schedules and topics, one audit row and exactly one outbox row in one transaction, and a refusal writes nothing.
/// Hurl cannot see these tables, so this goes through the API as the limited role.
/// </summary>
public sealed class DeactivationWritesTests
{
    private const int Admin = 901201;
    private const int Teacher = 901202;
    private const int Active = 901211;
    private const int Gone = 901212;
    private const int ClassId = 9921;

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate platform.outbox, classes.class_audit_log, classes.class_schedule_topics, classes.class_students, classes.class_schedules, classes.classes restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Deactivate Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Deactivate Teacher", "1");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({admin}, 1)");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'DE-1', 1, 'delink1', 'Deactivate Class', 3, {Teacher}, 1, 'Offline', 'A', {Admin}); "
            + "insert into classes.topics (id, name, is_vocational, sort_order, created_by) values (9921, 'De Topic', 0, 1, 1) on conflict do nothing; "
            + $"insert into classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by) values (1, {ClassId}, 2, 18, 0, 'Asia/Kolkata', {Admin}), (2, {ClassId}, 4, 19, 0, 'Asia/Kolkata', {Admin}); "
            + $"insert into classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by, deleted_at, deleted_by) values (3, {ClassId}, 6, 11, 0, 'Asia/Kolkata', {Admin}, '2025-10-01', 7); "
            + "insert into classes.class_schedule_topics (class_schedule_id, topic_id, sort_order, created_by) values (1, 9921, 1, 1); "
            + $"insert into classes.class_students (class_id, token_no, joined_on, mcq_admin) values ({ClassId}, {Active}, current_date, 1); "
            + $"insert into classes.class_students (class_id, token_no, joined_on, removed_at, removed_by, removed_reason, status) values ({ClassId}, {Gone}, current_date, '2025-10-01', 7, 'left earlier', 'I')");
    }

    private Task<MembershipTestKit.Reply> DeactivateAsync(string body) => kit.SendAsync(Admin, HttpMethod.Post, $"/classes/{ClassId}/deactivate", body);

    [Test]
    public async Task Deactivating_writes_every_part_once_and_one_event_naming_the_removed_students()
    {
        var reply = await DeactivateAsync("""{"type": "shutdown", "effectiveDate": "2026-03-04", "reason": " Too few students "}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var cls = await TestDatabase.RowAsync($"select status, comments, completed_on, shutdown_on, updated_by, deleted_by from classes.classes where id = {ClassId}");
        Assert.That(cls!["status"], Is.EqualTo("I"));
        Assert.That(cls["comments"], Is.EqualTo("Too few students"));
        Assert.That(await MembershipTestKit.CountAsync("classes.classes", $"id = {ClassId} and updated_at is not null and deleted_at is not null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.classes", $"id = {ClassId} and completed_on is null and shutdown_on = date '2026-03-04'"), Is.EqualTo(1));
        Assert.That(cls["updated_by"], Is.EqualTo(Admin.ToString(System.Globalization.CultureInfo.InvariantCulture)));
        Assert.That(cls["deleted_by"], Is.EqualTo(Admin.ToString(System.Globalization.CultureInfo.InvariantCulture)));

        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"token_no = {Active} and status = 'I' and removed_by = {Admin} and removed_at is not null and removed_reason = 'Class deactivated: Too few students' and mcq_admin = 1"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"token_no = {Gone} and removed_reason = 'left earlier' and removed_by = 7"), Is.EqualTo(1), "an earlier removal is not rewritten");
        Assert.That(await MembershipTestKit.CountAsync("classes.class_schedules", $"class_id = {ClassId} and deleted_at is not null and deleted_by = {Admin}"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_schedules", "id = 3 and deleted_by = 7"), Is.EqualTo(1), "an already deleted slot keeps its own stamp");
        Assert.That(await MembershipTestKit.CountAsync("classes.class_schedule_topics", $"deleted_at is not null and deleted_by = {Admin}"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_audit_log", $"class_id = {ClassId} and action = 'deactivated' and performed_by = {Admin} and details = '{{\"type\":\"shutdown\",\"effective_date\":\"2026-03-04\",\"reason\":\"Too few students\"}}'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.class_deactivated'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_refused_deactivation_and_a_repeat_write_nothing_more()
    {
        var refused = await DeactivateAsync("""{"type": "shutdown", "effectiveDate": "2026-03-04", "reason": ""}""");
        Assert.That(refused.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("classes.classes", "status = 'A'"), Is.EqualTo(1));

        Assert.That((await DeactivateAsync("""{"type": "completed", "effectiveDate": "2026-03-04", "reason": "done"}""")).Status, Is.EqualTo(HttpStatusCode.OK));
        var repeat = await DeactivateAsync("""{"type": "completed", "effectiveDate": "2026-03-05", "reason": "again"}""");

        Assert.That(repeat.Status, Is.EqualTo(HttpStatusCode.Conflict));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_audit_log"), Is.EqualTo(1));
    }
}
