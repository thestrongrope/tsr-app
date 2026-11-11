using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// PHP writes an admin_access_log row (platform's table) when a privileged caller manages a class: GET /classes/{id}/manage, PUT /classes/{id} and POST /classes, after the permission
/// check and before the body is validated. Hurl cannot see the table, so these go through the API as the limited role and read it back. Role 0 and refused calls leave no row.
/// </summary>
public sealed class AdminAuditTests
{
    private const int Admin = 901001;
    private const int Teacher = 901002;
    private const int ClassId = 9901;

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit();

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate platform.admin_access_log, classes.class_students, classes.class_schedules, classes.classes restart identity cascade");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Audit Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Audit Teacher", "1");
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({admin}, 1)");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + $"insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ({ClassId}, 'AU-1', 1, 'aulink1', 'Audit Class', 3, {Teacher}, 1, 'Offline', 'A', {Admin})");
    }

    private static Task<long> RowsAsync(string where = "true") => MembershipTestKit.CountAsync("platform.admin_access_log", where);

    [Test]
    public async Task Managing_a_class_as_an_admin_writes_one_row_with_the_request_details()
    {
        var reply = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{ClassId}/manage");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(await RowsAsync(), Is.EqualTo(1));
        var row = await TestDatabase.RowAsync("select token, roleid, page, method, session_id from platform.admin_access_log");
        Assert.That(row!["token"], Is.EqualTo(Admin.ToString(System.Globalization.CultureInfo.InvariantCulture)));
        Assert.That(row["roleid"], Is.EqualTo("1"));
        Assert.That(row["page"], Is.EqualTo($"/classes/{ClassId}/manage"));
        Assert.That(row["method"], Is.EqualTo("GET"));
        Assert.That(row["session_id"], Is.Null);
    }

    [Test]
    public async Task A_refused_caller_leaves_no_row()
    {
        var reply = await kit.SendAsync(Teacher, HttpMethod.Get, $"/classes/{ClassId}/manage");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(await RowsAsync(), Is.EqualTo(0));
    }

    [Test]
    public async Task An_update_that_fails_validation_still_leaves_its_row_because_PHP_logs_before_the_body_is_read()
    {
        var reply = await kit.SendAsync(Admin, HttpMethod.Put, $"/classes/{ClassId}", "{}");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), reply.Body);
        Assert.That(await RowsAsync("method = 'PUT' and page = '/classes/" + ClassId + "'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Creating_a_class_logs_after_the_gender_and_permission_checks_and_before_the_rest_of_the_body()
    {
        var invalidGender = await kit.SendAsync(Admin, HttpMethod.Post, "/classes", """{"gender": 5}""");
        Assert.That(invalidGender.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await RowsAsync(), Is.EqualTo(0), "refused before the log");

        var invalidLevel = await kit.SendAsync(Admin, HttpMethod.Post, "/classes", """{"gender": 1}""");
        Assert.That(invalidLevel.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(await RowsAsync("method = 'POST' and page = '/classes'"), Is.EqualTo(1));
    }

    [Test]
    public async Task Only_the_privileged_roles_are_logged_and_long_values_are_cut_to_the_columns()
    {
        await TestDatabase.ExecuteAsync("insert into access.user_permissions (user_id, permission, reason) select id, 'classes:update:all', 'audit test' from identity.users where token = " + Teacher);
        var granted = await kit.SendAsync(Teacher, HttpMethod.Get, $"/classes/{ClassId}/manage");
        Assert.That(granted.Status, Is.EqualTo(HttpStatusCode.OK), "the grant lets this role-0 caller manage");
        Assert.That(await RowsAsync(), Is.EqualTo(0), "role 0 is not privileged");

        var reply = await kit.SendAsync(Admin, HttpMethod.Get, $"/classes/{ClassId}/manage?x={new string('q', 400)}", userAgent: new string('a', 600));
        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        var row = await TestDatabase.RowAsync("select char_length(user_agent) as ua, char_length(page) as pg from platform.admin_access_log");
        Assert.That(row!["ua"], Is.EqualTo("512"));
        Assert.That(row["pg"], Is.EqualTo($"/classes/{ClassId}/manage".Length.ToString(System.Globalization.CultureInfo.InvariantCulture)), "the query string is not part of the page");
    }
}
