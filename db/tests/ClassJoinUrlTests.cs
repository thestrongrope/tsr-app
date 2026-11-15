using System.Net;
using System.Text.Json.Nodes;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// <c>joinUrl</c> on GET /classes, GET /classes/{id} and GET /classes/{id}/manage: the public join page of a class (PHP ClassesModel::joinUrl: public_web_base() plus
/// /join/ plus the class's link), given to the teacher and to whoever manages the class, never to a student, and null without a public web base or without a link.
/// The Hurl files run without the setting (as the PHP parity stack does), so they only pin the null.
/// </summary>
public sealed class ClassJoinUrlTests
{
    private const int Admin = 903101;
    private const int Teacher = 903102;
    private const int Student = 903103;
    private const int Linked = 9311;
    private const int NoLink = 9312;
    private const string LinkedUrl = "https://join.example.invalid/join/julink1";

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit("TSR_PUBLIC_WEB_BASE", "https://join.example.invalid/");

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate classes.class_students, classes.class_schedules, classes.classes restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Ju Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Ju Teacher", "1");
        await MembershipTestKit.AddMemberAsync(Student, "Ju Student", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({admin}, 1); "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values "
            + $"({Linked}, 'JU-1', 1, 'julink1', 'Ju Linked', 3, {Teacher}, 1, 'Offline', 'A', {Admin}), "
            + $"({NoLink}, 'JU-2', 1, '', 'Ju No Link', 3, {Teacher}, 1, 'Offline', 'A', {Admin}); "
            + $"insert into classes.class_students (class_id, token_no, joined_on) values ({Linked}, {Student}, date '2025-01-06')");
    }

    [Test]
    public async Task The_teacher_gets_the_join_page_of_a_class_in_the_list_and_null_for_a_class_without_a_link()
    {
        var reply = await kit.SendAsync(Teacher, HttpMethod.Get, "/classes");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(JoinUrlOf(reply.Json!, Linked), Is.EqualTo(LinkedUrl), "the trailing slash of the base is dropped");
        Assert.That(JoinUrlOf(reply.Json!, NoLink), Is.Null);
    }

    [Test]
    public async Task A_student_gets_no_join_page_in_the_list_or_on_the_class()
    {
        var list = await kit.SendAsync(Student, HttpMethod.Get, "/classes");
        var one = await kit.SendAsync(Student, HttpMethod.Get, $"/classes/{Linked}");

        Assert.That(list.Status, Is.EqualTo(HttpStatusCode.OK), list.Body);
        Assert.That(JoinUrlOf(list.Json!, Linked), Is.Null);
        Assert.That(one.Status, Is.EqualTo(HttpStatusCode.OK), one.Body);
        Assert.That(one.Json!["joinUrl"], Is.Null);
    }

    [Test]
    public async Task Whoever_manages_a_class_gets_its_join_page_in_the_managed_list_but_not_in_the_plain_list()
    {
        var managed = await kit.SendAsync(Admin, HttpMethod.Get, "/classes?include=managed");
        var plain = await kit.SendAsync(Admin, HttpMethod.Get, "/classes");

        Assert.That(managed.Status, Is.EqualTo(HttpStatusCode.OK), managed.Body);
        Assert.That(JoinUrlOf(managed.Json!, Linked), Is.EqualTo(LinkedUrl));
        Assert.That(plain.Json!.AsArray(), Is.Empty, "an admin who neither teaches nor attends has no class of their own");
    }

    [Test]
    public async Task The_teacher_and_the_manager_get_the_join_page_on_the_class()
    {
        var teacher = await kit.SendAsync(Teacher, HttpMethod.Get, $"/classes/{Linked}");
        var manager = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{Linked}");
        var noLink = await kit.SendAsync(Teacher, HttpMethod.Get, $"/classes/{NoLink}");

        Assert.That(teacher.Json!["joinUrl"]?.GetValue<string>(), Is.EqualTo(LinkedUrl), teacher.Body);
        Assert.That(manager.Json!["joinUrl"]?.GetValue<string>(), Is.EqualTo(LinkedUrl), manager.Body);
        Assert.That(noLink.Json!["joinUrl"], Is.Null, noLink.Body);
    }

    [Test]
    public async Task The_manage_screen_gets_the_join_page_and_null_for_a_class_without_a_link()
    {
        var linked = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{Linked}/manage");
        var noLink = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{NoLink}/manage");

        Assert.That(linked.Status, Is.EqualTo(HttpStatusCode.OK), linked.Body);
        Assert.That(linked.Json!["class"]!["joinUrl"]?.GetValue<string>(), Is.EqualTo(LinkedUrl));
        Assert.That(noLink.Json!["class"]!["joinUrl"], Is.Null, noLink.Body);
    }

    [Test]
    public async Task Without_a_public_web_base_the_join_page_is_null_for_everyone()
    {
        using var bare = new MembershipTestKit();

        var list = await bare.SendAsync(Teacher, HttpMethod.Get, "/classes");
        var one = await bare.SendAsync(Teacher, HttpMethod.Get, $"/classes/{Linked}");
        var manage = await bare.SendAsync(Admin, HttpMethod.Get, $"/classes/{Linked}/manage");

        Assert.That(JoinUrlOf(list.Json!, Linked), Is.Null, list.Body);
        Assert.That(one.Json!["joinUrl"], Is.Null, one.Body);
        Assert.That(manage.Json!["class"]!["joinUrl"], Is.Null, manage.Body);
    }

    private static string? JoinUrlOf(JsonNode list, int classId) =>
        list.AsArray().Single(c => c!["id"]!.GetValue<int>() == classId)!["joinUrl"]?.GetValue<string>();
}
