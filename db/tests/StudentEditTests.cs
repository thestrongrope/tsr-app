using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// PUT /classes/{id}/students/{token} changes the email (identity's command), the name and mobile (membership's command) and the class note (classes), each with its own outbox row, in one transaction.
/// A placeholder member that never signed in may be given a real address; a member with a Firebase link, or a real address, may not. Hurl cannot reach these cases (the synthetic-stack guard forbids
/// placeholder members), so this goes through the API as the limited role.
/// </summary>
public sealed class StudentEditTests
{
    private const int Admin = 901301;
    private const int Teacher = 901302;
    private const int Placeholder = 901311;
    private const int Linked = 901312;
    private const int Real = 901313;
    private const int ClassId = 9931;
    private const string Gents = "9931";

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate platform.outbox, classes.class_students, classes.classes restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Edit Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Edit Teacher", "1");
        await MembershipTestKit.AddMemberAsync(Placeholder, "Placeholder Member", "1");
        await MembershipTestKit.AddMemberAsync(Linked, "Linked Member", "1");
        await MembershipTestKit.AddMemberAsync(Real, "Real Member", "1");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({admin}, 1)");
        await TestDatabase.ExecuteAsync($"update identity.users set email = '{Placeholder}@thestrongrope.com', firebase_uid = null where token = {Placeholder}");
        await TestDatabase.ExecuteAsync($"update identity.users set email = '{Linked}@thestrongrope.com' where token = {Linked}");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'SE-1', 1, 'selink1', 'Edit Class', 3, {Teacher}, 1, 'Offline', 'A', {Admin}); "
            + $"insert into classes.class_students (class_id, token_no, joined_on) values ({ClassId}, {Placeholder}, current_date), ({ClassId}, {Linked}, current_date), ({ClassId}, {Real}, current_date)");
    }

    private Task<MembershipTestKit.Reply> EditAsync(int token, string body) => kit.SendAsync(Admin, HttpMethod.Put, $"/classes/{Gents}/students/{token}", body);

    private static Task<long> EventsAsync(string type) => MembershipTestKit.CountAsync("platform.outbox", $"event_type = '{type}'");

    [Test]
    public async Task A_placeholder_that_never_signed_in_gets_the_new_address_name_mobile_and_note_with_one_event_each()
    {
        var reply = await EditAsync(Placeholder, """{"name": "New Name", "email": "new.address@example.invalid", "mobile": "+91000009999", "notes": "hello", "gender": "2", "roleid": 1}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await MembershipTestKit.CountAsync("identity.users", $"token = {Placeholder} and email = 'new.address@example.invalid' and firebase_uid is null"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", $"name = 'New Name' and mobile = '+91000009999' and gender = '1' and user_id = (select id from identity.users where token = {Placeholder})"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("access.user_roles", $"roleid = 1 and user_id = (select id from identity.users where token = {Placeholder})"), Is.EqualTo(0), "no mass assignment");
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"token_no = {Placeholder} and notes = 'hello'"), Is.EqualTo(1));
        Assert.That(await EventsAsync("identity.member_email_changed"), Is.EqualTo(1));
        Assert.That(await EventsAsync("membership.member_contact_changed"), Is.EqualTo(1));
        Assert.That(await EventsAsync("classes.student_edited"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(3));
    }

    [Test]
    public async Task A_member_with_a_firebase_link_or_a_real_address_keeps_the_email_and_the_refusal_writes_nothing()
    {
        await TestDatabase.ExecuteAsync($"update identity.users set email = '{Linked}@thestrongrope.com' where token = {Linked}");

        foreach (var token in new[] { Linked, Real })
        {
            var reply = await EditAsync(token, """{"name": "Must Not Save", "email": "other@example.invalid", "notes": "no"}""");

            Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), reply.Body);
            Assert.That(reply.Body, Does.Contain("This member signs in with their own email; it cannot be changed here."));
        }

        Assert.That(await MembershipTestKit.CountAsync("identity.users", "email = 'other@example.invalid'"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "name = 'Must Not Save'"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", "notes = 'no'"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    [Test]
    public async Task An_edit_without_an_email_leaves_it_and_writes_no_email_event()
    {
        var reply = await EditAsync(Real, """{"mobile": "+91000001111"}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await EventsAsync("identity.member_email_changed"), Is.EqualTo(0));
        Assert.That(await EventsAsync("membership.member_contact_changed"), Is.EqualTo(1));
        Assert.That(await EventsAsync("classes.student_edited"), Is.EqualTo(1));
    }

    [Test]
    public async Task A_value_a_column_cannot_hold_is_a_failed_update_and_rolls_everything_back()
    {
        var reply = await EditAsync(Placeholder, $$"""{"email": "ok.address@example.invalid", "name": "{{new string('n', 201)}}"}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), reply.Body);
        Assert.That(reply.Body, Does.Contain("Failed to update student"));
        Assert.That(await MembershipTestKit.CountAsync("identity.users", "email = 'ok.address@example.invalid'"), Is.EqualTo(0), "the email change rolled back with the rest");
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox"), Is.EqualTo(0));
    }

    [Test]
    public async Task A_token_shared_with_a_signed_in_row_is_not_given_a_new_address()
    {
        // A token is not unique in identity.users. The check must cover every row the update would touch: here the first row is a placeholder, the second has signed in.
        await TestDatabase.ExecuteAsync($"insert into identity.users (token, email, firebase_uid) values ({Placeholder}, 'signed.in@example.invalid', 'uid-shared-token')");

        await EditAsync(Placeholder, """{"email": "new.address@example.invalid"}""");

        Assert.That(await MembershipTestKit.CountAsync("identity.users", $"token = {Placeholder} and email = 'signed.in@example.invalid'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("identity.users", "email = 'new.address@example.invalid'"), Is.EqualTo(0));
        Assert.That(await EventsAsync("identity.member_email_changed"), Is.EqualTo(0));
    }
}
