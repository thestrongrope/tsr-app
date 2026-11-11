using System.Globalization;
using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// POST and PUT /classes/{id}/conduction write the session, its attendance and exactly one outbox row in one transaction; a refusal, a repeat and a failed write leave nothing behind. Hurl cannot see these tables, so
/// this goes through the API as the limited role: the author and the class teacher are stored as PHP stores them, and PUT keeps what PHP keeps.
/// </summary>
public sealed class ConductionWritesTests
{
    private const int Admin = 901301;
    private const int Teacher = 901302;
    private const int Student = 901311;
    private const int Left = 901312;
    private const int Stranger = 901313;
    private const int ClassId = 9931;

    private const string Held = """
        {"conductedOn": "2026-03-04", "duration": 45, "students": [
            {"token": 901311, "present": true, "recitation": 6}, {"token": 901312, "present": false, "recitation": 9}, {"token": 901313, "present": true}],
         "extraStudents": [{"name": "Guest", "token": 1, "present": true}], "aqaedConducted": true, "aqaedTopic": "Wudu", "ahkamConducted": true, "ahkamTopic": "Ghusl"}
        """;

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("drop trigger if exists cd_fail on classes.class_attendance; drop function if exists classes.cd_fail()");
        await TestDatabase.ExecuteAsync("truncate platform.outbox, classes.class_attendance, classes.class_sessions, classes.class_students, classes.class_schedules, classes.classes restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Conduction Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Conduction Teacher", "1");
        await MembershipTestKit.AddMemberAsync(Student, "Conduction Student", "1");
        await MembershipTestKit.AddMemberAsync(Left, "Conduction Left", "1");
        await MembershipTestKit.AddMemberAsync(Stranger, "Conduction Stranger", "1");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({admin}, 1)");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'CW-1', 1, 'cwlnk1', 'Conduction Class', 3, {Teacher}, 1, 'Offline', 'A', {Admin}); "
            + $"insert into classes.class_students (class_id, token_no, joined_on) values ({ClassId}, {Student}, current_date); "
            + $"insert into classes.class_students (class_id, token_no, joined_on, removed_at, removed_by, removed_reason, status) values ({ClassId}, {Left}, current_date, '2025-10-01', 7, 'left', 'I')");
    }

    private Task<MembershipTestKit.Reply> PostAsync(int caller, string body) => kit.SendAsync(caller, HttpMethod.Post, $"/classes/{ClassId}/conduction", body);

    private static string Text(int value) => value.ToString(CultureInfo.InvariantCulture);

    [Test]
    public async Task Recording_stores_the_author_and_the_class_teacher_the_attendance_that_belongs_and_one_event()
    {
        var reply = await PostAsync(Admin, Held);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created), reply.Body);
        var row = await TestDatabase.RowAsync("select id, teacher, created_by, conducted, attendance, arabic_conducted, aqaed_conducted, ahkam_conducted, aqaed_topic, conducted_by, updated_by from classes.class_sessions");
        Assert.That(row!["teacher"], Is.EqualTo(Text(Teacher)), "the class's teacher, not the caller");
        Assert.That(row["created_by"], Is.EqualTo(Text(Admin)));
        Assert.That(row["conducted"], Is.EqualTo("1"));
        Assert.That(row["attendance"], Is.EqualTo("2"), "the present student who belongs and the present guest; the stranger is not counted");
        Assert.That(row["arabic_conducted"], Is.EqualTo("0"));
        Assert.That(row["aqaed_conducted"], Is.EqualTo("1"));
        Assert.That(row["aqaed_topic"], Is.EqualTo("Wudu"));
        Assert.That(row["conducted_by"], Is.Null.Or.Empty);
        Assert.That(await MembershipTestKit.CountAsync("classes.class_attendance", $"token = {Stranger}"), Is.EqualTo(0), "a member who is not in the class gets no attendance row");
        Assert.That(await MembershipTestKit.CountAsync("classes.class_attendance", $"token = {Left} and present = 0 and recitation = 0 and extra_student = 0"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_attendance", $"token = {Student} and present = 1 and recitation = 6"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_attendance", "name = 'Guest' and extra_student = 1 and present = 1"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.session_recorded'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_refusal_and_a_repeat_write_no_second_session_and_no_second_event()
    {
        var withTime = Held.Replace("\"duration\"", "\"recordedAt\": \"2026-03-04T08:00:00Z\", \"duration\"", StringComparison.Ordinal);
        Assert.That((await PostAsync(Teacher, withTime)).Status, Is.EqualTo(HttpStatusCode.Created));
        Assert.That((await PostAsync(Teacher, withTime)).Status, Is.EqualTo(HttpStatusCode.OK), "the same request again is a replay");
        Assert.That((await PostAsync(Teacher, Held)).Status, Is.EqualTo(HttpStatusCode.Conflict));
        Assert.That((await PostAsync(Teacher, """{"conductedOn": "2026-03-05"}""")).Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That((await PostAsync(Student, Held)).Status, Is.EqualTo(HttpStatusCode.Forbidden));

        Assert.That(await MembershipTestKit.CountAsync("classes.class_sessions"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_attendance"), Is.EqualTo(3));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_failed_attendance_write_rolls_back_the_session_and_the_event()
    {
        await TestDatabase.ExecuteAsync(
            "create function classes.cd_fail() returns trigger language plpgsql as $$ begin if new.token = 4242 then raise exception 'cd_fail'; end if; return new; end $$; "
            + "create trigger cd_fail before insert on classes.class_attendance for each row execute function classes.cd_fail()");
        try
        {
            var body = Held.Replace("\"token\": 1,", "\"token\": 4242,", StringComparison.Ordinal);
            Assert.That((await PostAsync(Teacher, body)).Status, Is.EqualTo(HttpStatusCode.InternalServerError));
            Assert.That(await MembershipTestKit.CountAsync("classes.class_sessions"), Is.EqualTo(0));
            Assert.That(await MembershipTestKit.CountAsync("classes.class_attendance"), Is.EqualTo(0));
            Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("drop trigger cd_fail on classes.class_attendance; drop function classes.cd_fail()");
        }
    }

    [Test]
    public async Task Editing_replaces_the_fields_and_attendance_keeps_the_author_and_teacher_and_writes_one_more_event()
    {
        Assert.That((await PostAsync(Admin, Held)).Status, Is.EqualTo(HttpStatusCode.Created));
        var id = (await TestDatabase.RowAsync("select id from classes.class_sessions"))!["id"];
        const string Edit = """{"conductedOn": "2026-03-06", "conducted": false, "nonConductionReason": "Rain", "students": [{"token": 901311, "present": true, "recitation": 2}]}""";

        var reply = await kit.SendAsync(Teacher, HttpMethod.Put, $"/classes/{ClassId}/conduction/{id}", Edit);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var row = await TestDatabase.RowAsync("select teacher, created_by, updated_by, updated_at is not null as touched, conducted, non_conduction_reason, attendance, aqaed_conducted, aqaed_topic, conducted_on::text as day from classes.class_sessions");
        Assert.That(row!["teacher"], Is.EqualTo(Text(Teacher)));
        Assert.That(row["created_by"], Is.EqualTo(Text(Admin)), "the author stays");
        Assert.That(row["updated_by"], Is.EqualTo(Text(Teacher)));
        Assert.That(row["touched"], Is.EqualTo("True").IgnoreCase);
        Assert.That(row["conducted"], Is.EqualTo("0"));
        Assert.That(row["non_conduction_reason"], Is.EqualTo("Rain"));
        Assert.That(row["attendance"], Is.EqualTo("1"));
        Assert.That(row["aqaed_conducted"], Is.EqualTo("0"));
        Assert.That(row["aqaed_topic"], Is.Null.Or.Empty);
        Assert.That(row["day"], Is.EqualTo("2026-03-06"));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_attendance"), Is.EqualTo(1), "the old rows are replaced whole");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type = 'classes.session_updated'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(2));
    }

    [Test]
    public async Task A_refused_edit_changes_nothing_and_writes_no_event()
    {
        Assert.That((await PostAsync(Admin, Held)).Status, Is.EqualTo(HttpStatusCode.Created));
        Assert.That((await PostAsync(Admin, Held.Replace("2026-03-04", "2026-03-11", StringComparison.Ordinal))).Status, Is.EqualTo(HttpStatusCode.Created));
        var id = (await TestDatabase.RowAsync("select id from classes.class_sessions where conducted_on = date '2026-03-04'"))!["id"];
        await TestDatabase.ExecuteAsync("update classes.class_sessions set created_at = now() - interval '30 days' where conducted_on = date '2026-03-11'");
        var old = (await TestDatabase.RowAsync("select id from classes.class_sessions where conducted_on = date '2026-03-11'"))!["id"];

        var clash = await kit.SendAsync(Teacher, HttpMethod.Put, $"/classes/{ClassId}/conduction/{id}", Held.Replace("2026-03-04", "2026-03-11", StringComparison.Ordinal));
        var stale = await kit.SendAsync(Admin, HttpMethod.Put, $"/classes/{ClassId}/conduction/{old}", Held);
        var invalid = await kit.SendAsync(Teacher, HttpMethod.Put, $"/classes/{ClassId}/conduction/{id}", "{}");

        Assert.That(clash.Status, Is.EqualTo(HttpStatusCode.Conflict));
        Assert.That(stale.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(invalid.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_sessions", "conducted_on = date '2026-03-04' and updated_at is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_attendance"), Is.EqualTo(6));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(2), "only the two recordings");
    }
}
