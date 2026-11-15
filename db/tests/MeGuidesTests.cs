using System.Net;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// GET /me/guides and GET /me/guides/{slug}: a student or a teacher reads a class level's guide by the slug of its public page
/// (PHP routes/guides.php route_reader_guides, route_reader_guide). The Hurl files me-guides.hurl and me-guide.hurl hold the contract.
/// </summary>
public sealed class MeGuidesTests
{
    private const int Admin = 902801;
    private const int Teacher = 902802;
    private const int Student = 902803;
    private const int Outsider = 902804;
    private const int Removed = 902805;
    private const int ClosedOnly = 902806;
    private const string NotReader = "Guides are for students and teachers";
    private const string NotFound = "Guide not found";

    private static readonly string[] BilalFirst = ["bilal", "abuzar", "miqdad", "ammar"];

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
            "truncate classes.class_attendance, classes.class_sessions, classes.class_schedules, classes.class_students, classes.classes restart identity cascade; "
            + "delete from classes.guides");
        var admin = await MembershipTestKit.AddMemberAsync(Admin, "Mg Admin", "1");
        await MembershipTestKit.AddMemberAsync(Teacher, "Mg Teacher", "1");
        await MembershipTestKit.AddMemberAsync(Student, "Mg Student", "1");
        await MembershipTestKit.AddMemberAsync(Outsider, "Mg Outsider", "1");
        await MembershipTestKit.AddMemberAsync(Removed, "Mg Removed", "1");
        await MembershipTestKit.AddMemberAsync(ClosedOnly, "Mg Closed Only", "1");
        await TestDatabase.ExecuteAsync(
            $"insert into access.user_roles (user_id, roleid) values ({admin}, 1); "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (2, 'AG', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3), (4, 'AY', 'AMMAR', 4), (5, 'B', 'BILAL', 5) "
            + "on conflict (id) do update set code = excluded.code, name = excluded.name, sort_order = excluded.sort_order; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by, started_on) values "
            + $"(9801, 'MG-G-1', 1, 'mglink1', 'Mg Open', 1, {Teacher}, 1, 'Offline', 'A', {Admin}, date '2025-01-06'), "
            + $"(9802, 'MG-G-2', 1, 'mglink2', 'Mg Closed', 3, {ClosedOnly}, 1, 'Offline', 'I', {Admin}, date '2025-01-06'); "
            + "insert into classes.class_students (class_id, token_no, joined_on) values "
            + $"(9801, {Student}, date '2025-01-06'), (9802, {ClosedOnly}, date '2025-01-06'); "
            + "insert into classes.class_students (class_id, token_no, joined_on, removed_at, removed_by, removed_reason, status) values "
            + $"(9801, {Removed}, date '2025-01-06', now(), {Admin}, 'Mg left', 'I'); "
            + "insert into classes.guides (level_id, language_id, guide, created_by) values "
            + $"(3, 1, '  <p>Mg Miqdad guide</p>\n', {Admin}), (5, 1, E' \\t\\n ', {Admin}), (4, 2, '<p>Mg Ammar in another language</p>', {Admin})");
    }

    [Test]
    public async Task A_signed_out_caller_gets_401_on_both_routes()
    {
        var list = await kit.SendUnsignedAsync(HttpMethod.Get, "/me/guides");
        var one = await kit.SendUnsignedAsync(HttpMethod.Get, "/me/guides/miqdad");

        Assert.That((list.Status, list.Detail), Is.EqualTo((HttpStatusCode.Unauthorized, "Not authenticated")));
        Assert.That((one.Status, one.Detail), Is.EqualTo((HttpStatusCode.Unauthorized, "Not authenticated")));
    }

    [Test]
    public async Task A_student_lists_the_four_levels_that_have_a_guide_page_in_level_order_with_slug_and_name_only()
    {
        var reply = await kit.SendAsync(Student, HttpMethod.Get, "/me/guides");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Body, Is.EqualTo(
            """{"guides":[{"slug":"abuzar","name":"ABUZAR"},{"slug":"miqdad","name":"MIQDAD"},{"slug":"ammar","name":"AMMAR"},{"slug":"bilal","name":"BILAL"}]}"""));
    }

    [Test]
    public async Task The_list_follows_the_levels_sort_order_not_their_ids()
    {
        await TestDatabase.ExecuteAsync("update classes.class_levels set sort_order = 0 where id = 5");
        try
        {
            var reply = await kit.SendAsync(Teacher, HttpMethod.Get, "/me/guides");

            var slugs = reply.Json!["guides"]!.AsArray().Select(g => g!["slug"]!.GetValue<string>()).ToList();
            Assert.That(slugs, Is.EqualTo(BilalFirst));
        }
        finally
        {
            await TestDatabase.ExecuteAsync("update classes.class_levels set sort_order = 5 where id = 5");
        }
    }

    [Test]
    public async Task A_student_reads_a_guide_untrimmed_with_its_level_name_and_no_share_url_without_the_setting()
    {
        var reply = await kit.SendAsync(Student, HttpMethod.Get, "/me/guides/miqdad");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Body, Is.EqualTo("""{"guide":"  <p>Mg Miqdad guide</p>\n","share_url":null,"level_name":"MIQDAD"}"""));
    }

    [Test]
    public async Task A_teacher_reads_the_guide_of_any_level_not_only_the_level_taught()
    {
        var reply = await kit.SendAsync(Teacher, HttpMethod.Get, "/me/guides/miqdad");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Json!["level_name"]!.GetValue<string>(), Is.EqualTo("MIQDAD"));
    }

    [TestCase(Outsider, TestName = "A member in no class is refused on both routes")]
    [TestCase(Admin, TestName = "A super administrator who neither studies nor teaches is refused on both routes")]
    [TestCase(Removed, TestName = "A student removed from the class is refused on both routes")]
    [TestCase(ClosedOnly, TestName = "A teacher and student of a closed class only is refused on both routes")]
    public async Task Refused(int caller)
    {
        var list = await kit.SendAsync(caller, HttpMethod.Get, "/me/guides");
        var one = await kit.SendAsync(caller, HttpMethod.Get, "/me/guides/miqdad");

        Assert.That((list.Status, list.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotReader)));
        Assert.That((one.Status, one.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotReader)));
    }

    [Test]
    public async Task The_refusal_comes_before_the_lookup_so_an_unknown_slug_tells_a_non_reader_nothing()
    {
        var reply = await kit.SendAsync(Outsider, HttpMethod.Get, "/me/guides/no-such-guide");

        Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.Forbidden, NotReader)));
    }

    [TestCase("no-such-guide", TestName = "An unknown slug is 404")]
    [TestCase("salman", TestName = "The level without a guide page is 404")]
    [TestCase("MIQDAD", TestName = "A slug in another case is 404")]
    [TestCase("miqdad%20", TestName = "A slug with a trailing space is 404")]
    [TestCase("3", TestName = "A level id is not a slug: 404")]
    [TestCase("abuzar", TestName = "A level with no guide row is 404")]
    [TestCase("ammar", TestName = "A level whose only guide is in another language is 404")]
    [TestCase("bilal", TestName = "A level whose guide is blank is 404")]
    public async Task Not_found(string slug)
    {
        var reply = await kit.SendAsync(Student, HttpMethod.Get, "/me/guides/" + slug);

        Assert.That((reply.Status, reply.Detail), Is.EqualTo((HttpStatusCode.NotFound, NotFound)));
    }

    [TestCase("https://guides.example.invalid", TestName = "share_url is the public web base plus the guide page of the slug")]
    [TestCase("https://guides.example.invalid/", TestName = "share_url drops a trailing slash of the public web base")]
    public async Task Share_url(string publicWebBase)
    {
        using var factory = TestApi.Create().WithWebHostBuilder(builder => builder.UseSetting("TSR_PUBLIC_WEB_BASE", publicWebBase));
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/me/guides/miqdad");
        foreach (var (name, value) in TestApi.SignedInAs("uid-" + Student, MembershipTestKit.EmailOf(Student)))
        {
            request.Headers.Add(name, value);
        }

        using var response = await client.SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK), body);
        Assert.That(JsonNode.Parse(body)!["share_url"]!.GetValue<string>(), Is.EqualTo("https://guides.example.invalid/guide.php?guide=miqdad"));
    }

    [Test]
    public async Task Reading_a_guide_creates_the_member_PHP_creates_on_these_routes_and_then_refuses()
    {
        using var factory = TestApi.Create();
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/me/guides");
        foreach (var (name, value) in TestApi.SignedInAs("uid-mg-new", "mg.new@example.invalid"))
        {
            request.Headers.Add(name, value);
        }

        using var response = await client.SendAsync(request);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(await MembershipTestKit.CountAsync("identity.users", "email = 'mg.new@example.invalid'"), Is.EqualTo(1));
    }
}
