using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// POST /classes/{id}/students/bulk creates a member through identity's and membership's published commands (token = highest + 1, the placeholder address, no Firebase link, no role, the class's gender), enrols them
/// through classes, and writes one outbox row per command and per enrolment, all in one transaction. Hurl cannot reach this (the synthetic-stack guard forbids placeholder members), so it goes through the API.
/// </summary>
public sealed class BulkAddTests
{
    private const int Admin = 901401;
    private const int Teacher = 901402;
    private const int Existing = 901411;
    private const int ClassId = 9941;
    private const string Gents = "9941";

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
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Bulk Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Bulk Teacher", "1");
        await MembershipTestKit.AddMemberAsync(Existing, "Existing Member", "1");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({admin}, 1)");
        await TestDatabase.ExecuteAsync("update membership.member_profiles set mobile = '+910000091411' where user_id = (select id from identity.users where token = " + Existing + ")");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'BA-1', 1, 'balink1', 'Bulk Class', 3, {Teacher}, 1, 'Offline', 'A', {Admin})");
    }

    private Task<MembershipTestKit.Reply> BulkAsync(string body) => kit.SendAsync(Admin, HttpMethod.Post, $"/classes/{Gents}/students/bulk", body);

    private static Task<long> EventsAsync(string type) => MembershipTestKit.CountAsync("platform.outbox", $"event_type = '{type}'");

    [Test]
    public async Task A_new_line_creates_a_placeholder_member_with_the_class_gender_and_enrols_them_with_one_event_per_command()
    {
        var reply = await BulkAsync("""{"lines": ["New Person, +910000099001", "Other Person"], "email": "x@example.invalid", "roleid": 1, "gender": "2", "token": 5}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await MembershipTestKit.CountAsync("identity.users", "email = token || '@thestrongrope.com' and firebase_uid is null and token > " + Existing), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("identity.users", "token = 5 or email = 'x@example.invalid'"), Is.EqualTo(0), "a line or a body field cannot set the token or email");
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "name = 'New Person' and gender = '1' and mobile = '+910000099001'"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("membership.member_profiles", "name = 'Other Person' and gender = '1' and mobile = ''"), Is.EqualTo(1));
        Assert.That(await MembershipTestKit.CountAsync("access.user_roles", "roleid = 1"), Is.EqualTo(1), "no role for a created member");
        Assert.That(await MembershipTestKit.CountAsync("membership.class_registrations", $"status = 'Accepted' and for_classid = {ClassId}"), Is.EqualTo(2));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {ClassId} and added_by = {Admin} and status = 'A'"), Is.EqualTo(2));
        Assert.That(await EventsAsync("identity.member_created"), Is.EqualTo(2));
        Assert.That(await EventsAsync("membership.member_created"), Is.EqualTo(2));
        Assert.That(await EventsAsync("classes.student_enrolled"), Is.EqualTo(2));
    }

    [Test]
    public async Task Tokens_follow_the_highest_token_one_after_another()
    {
        await BulkAsync("""{"lines": ["First New", "Second New"]}""");

        var highest = await TestDatabase.ScalarAsync<int>("select max(token) from identity.users where email like '%@thestrongrope.com'", TestDatabase.OwnerConnection);
        Assert.That(await MembershipTestKit.CountAsync("identity.users", $"token = {highest} - 1 and email = token || '@thestrongrope.com'"), Is.EqualTo(1));
        Assert.That(highest, Is.EqualTo(Existing + 2), "the highest member token was " + Existing);
    }

    [Test]
    public async Task A_flagged_line_writes_nothing_until_it_is_answered()
    {
        var reply = await BulkAsync("""{"lines": ["Fresh Person", "Mobile Match, 0000091411"]}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Body, Does.Contain("mobile_match").And.Contain("Existing M."));
        Assert.That(reply.Body, Does.Not.Contain("901411").And.Not.Contain("0000091411"));
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students"), Is.EqualTo(0));
        Assert.That(await MembershipTestKit.CountAsync("platform.outbox", "event_type like '%created' or event_type like 'classes.%'"), Is.EqualTo(0));
    }

    [Test]
    public async Task An_enrol_answer_enrols_the_existing_member_without_creating_one()
    {
        var reply = await BulkAsync("""{"lines": ["Mobile Match, 0000091411"], "resolutions": {"1": "enrol"}}""");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await MembershipTestKit.CountAsync("classes.class_students", $"class_id = {ClassId} and token_no = {Existing}"), Is.EqualTo(1));
        Assert.That(await EventsAsync("identity.member_created"), Is.EqualTo(0));
        Assert.That(await EventsAsync("classes.student_enrolled"), Is.EqualTo(1));
    }
}
