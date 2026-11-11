using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The enrolment writes of the classes domain leave exactly one outbox row per state change and, for a new enrolment, membership's published accepted-registration command writes the class request PHP's
/// writeEnrolment wrote (a member with no request gets an Accepted one; one who has any request keeps it). Hurl cannot see these tables, so this goes through the API as the limited role.
/// </summary>
public sealed class EnrolmentWritesTests
{
    private const int Admin = 901101;
    private const int Teacher = 901102;
    private const int Fresh = 901111;
    private const int Registered = 901112;
    private const int Ladies = 901113;
    private const int ClassId = 9911;
    private const string Gents = "9911";

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate platform.outbox, classes.student_transfers, classes.class_students, classes.class_schedules, classes.classes restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Enrol Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Enrol Teacher", "1");
        await MembershipTestKit.AddMemberAsync(Fresh, "Fresh Member", "1");
        await MembershipTestKit.AddMemberAsync(Registered, "Registered Member", "1");
        await MembershipTestKit.AddMemberAsync(Ladies, "Ladies Member", "2");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({admin}, 1)");
        await TestDatabase.ExecuteAsync($"insert into membership.class_registrations (token, status) values ({Registered}, 'Pending')");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'EN-1', 1, 'enlink1', 'Enrol Class', 3, {Teacher}, 1, 'Offline', 'A', {Admin})");
    }

    private static Task<long> EventsAsync(string type) => MembershipTestKit.CountAsync("platform.outbox", $"event_type = '{type}'");

    private Task<MembershipTestKit.Reply> AddAsync(int token) => kit.SendAsync(Admin, HttpMethod.Post, $"/classes/{Gents}/students", $$"""{"token": {{token}}}""");

    [Test]
    public async Task Adding_a_member_without_a_class_request_records_an_accepted_one_and_one_event()
    {
        var reply = await AddAsync(Fresh);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var row = await TestDatabase.RowAsync($"select status, for_classid from membership.class_registrations where token = {Fresh}");
        Assert.That(row, Is.Not.Null);
        Assert.That(row!["status"], Is.EqualTo("Accepted"));
        Assert.That(row["for_classid"], Is.EqualTo(ClassId.ToString(System.Globalization.CultureInfo.InvariantCulture)));
        Assert.That(await EventsAsync("classes.student_enrolled"), Is.EqualTo(1));
    }

    [Test]
    public async Task Adding_a_member_who_already_has_a_request_keeps_it_and_adding_twice_writes_one_event()
    {
        await AddAsync(Registered);
        await AddAsync(Registered);

        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = {Registered}"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = {Registered} and status = 'Pending'"), Is.EqualTo(1));
        Assert.That(await EventsAsync("classes.student_enrolled"), Is.EqualTo(1), "the repeat is a no-op");
    }

    [Test]
    public async Task A_refused_add_writes_neither_a_row_nor_an_event()
    {
        var reply = await AddAsync(Ladies);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"token = {Ladies}"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    [Test]
    public async Task Remove_and_restore_each_write_one_event_and_remove_touches_every_row_of_the_pair()
    {
        await TestDatabase.ExecuteAsync(
            $"insert into classes.class_students (class_id, token_no, joined_on, mcq_admin) values ({ClassId}, {Fresh}, current_date, 1), ({ClassId}, {Fresh}, current_date, 0)");

        var removed = await kit.SendAsync(Admin, HttpMethod.Post, $"/classes/{Gents}/students/{Fresh}/remove", """{"reason": "left"}""");
        Assert.That(removed.Status, Is.EqualTo(HttpStatusCode.OK), removed.Body);
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"token_no = {Fresh} and status = 'I' and removed_by = {Admin} and mcq_admin = 0 and removed_reason = 'left'"), Is.EqualTo(2));
        Assert.That(await EventsAsync("classes.student_removed"), Is.EqualTo(1));

        var restored = await kit.SendAsync(Admin, HttpMethod.Post, $"/classes/{Gents}/students/{Fresh}/restore", "{}");
        Assert.That(restored.Status, Is.EqualTo(HttpStatusCode.OK), restored.Body);
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"token_no = {Fresh} and status = 'A' and removed_at is null and removed_by is null and removed_reason is null"), Is.EqualTo(2));
        Assert.That(await EventsAsync("classes.student_restored"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_transfer_moves_the_member_logs_it_and_writes_one_event()
    {
        await TestDatabase.ExecuteAsync(
            $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values (9912, 'EN-2', 1, 'enlink2', 'Second Class', 3, {Teacher}, 1, 'Offline', 'A', {Admin}); "
            + $"insert into classes.class_students (class_id, token_no, joined_on, mcq_admin) values ({ClassId}, {Fresh}, current_date, 1)");

        var reply = await kit.SendAsync(Admin, HttpMethod.Post, $"/classes/{Gents}/students/{Fresh}/transfer", """{"toClassId": 9912, "type": "promotion", "reason": "0"}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        var source = await TestDatabase.RowAsync($"select status, removed_reason, mcq_admin from classes.class_students where class_id = {ClassId} and token_no = {Fresh}");
        Assert.That(source!["status"], Is.EqualTo("I"));
        Assert.That(source["removed_reason"], Is.EqualTo("Promotion to class #9912"), "a reason of 0 is false in PHP, so no suffix");
        Assert.That(source["mcq_admin"], Is.EqualTo("1"), "the flag of the old row is left as it was");
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = 9912 and token_no = {Fresh} and status = 'A' and added_by is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("classes.student_transfers", $"token_no = {Fresh} and from_class_id = {ClassId} and to_class_id = 9912 and type = 'promotion' and transferred_by = {Admin}"), Is.EqualTo(1));
        Assert.That(await EventsAsync("classes.student_transferred"), Is.EqualTo(1));
    }
}
