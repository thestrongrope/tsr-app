using System.Net;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// <c>share_url</c> on GET /classes/{class_id}/guide: the public guide page of the class's level (PHP route_class_guide: public_web_base() plus
/// /guide.php?guide= plus the level's slug), null without a public web base, and null with the guide when the level has no guide page, no guide or a blank one.
/// The Hurl file runs without the setting (as the PHP parity stack does), so it only pins the null.
/// </summary>
public sealed class ClassGuideShareUrlTests
{
    private const int Admin = 903201;
    private const int Student = 903202;
    private const int WithGuide = 9321;
    private const int BlankGuide = 9322;
    private const int NoGuidePage = 9323;
    private const int NoGuideRow = 9324;

    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit("TSR_PUBLIC_WEB_BASE", "https://guides.example.invalid/");

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate classes.class_students, classes.class_schedules, classes.classes restart identity cascade; delete from classes.guides");
        await MembershipTestKit.AddMemberAsync(Admin, "Gs Admin", "1");
        await MembershipTestKit.AddMemberAsync(Student, "Gs Student", "1");
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (1, 'SM', 'SALMAN', 1), (2, 'AG', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3), (5, 'B', 'BILAL', 5) "
            + "on conflict (id) do update set code = excluded.code, name = excluded.name, sort_order = excluded.sort_order; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values "
            + $"({WithGuide}, 'GS-1', 1, 'gslink1', 'Gs With Guide', 3, {Admin}, 1, 'Offline', 'A', {Admin}), "
            + $"({BlankGuide}, 'GS-2', 1, 'gslink2', 'Gs Blank Guide', 5, {Admin}, 1, 'Offline', 'A', {Admin}), "
            + $"({NoGuidePage}, 'GS-3', 1, 'gslink3', 'Gs No Guide Page', 1, {Admin}, 1, 'Offline', 'A', {Admin}), "
            + $"({NoGuideRow}, 'GS-4', 1, 'gslink4', 'Gs No Guide Row', 2, {Admin}, 1, 'Offline', 'A', {Admin}); "
            + "insert into classes.class_students (class_id, token_no, joined_on) values "
            + $"({WithGuide}, {Student}, date '2025-01-06'), ({BlankGuide}, {Student}, date '2025-01-06'), "
            + $"({NoGuidePage}, {Student}, date '2025-01-06'), ({NoGuideRow}, {Student}, date '2025-01-06'); "
            + "insert into classes.guides (level_id, language_id, guide, created_by) values "
            + $"(3, 1, '  <p>Gs Miqdad guide</p>\n', {Admin}), (5, 1, E' \\t\\n ', {Admin}), (1, 1, '<p>Gs Salman text</p>', {Admin})");
    }

    [Test]
    public async Task A_class_whose_level_has_a_guide_gets_the_public_guide_page_of_the_levels_slug()
    {
        var reply = await kit.SendAsync(Student, HttpMethod.Get, $"/classes/{WithGuide}/guide");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(
            reply.Body,
            Is.EqualTo("""{"guide":"  <p>Gs Miqdad guide</p>\n","share_url":"https://guides.example.invalid/guide.php?guide=miqdad","level_name":"MIQDAD"}"""),
            "the trailing slash of the base is dropped and the guide is untrimmed");
    }

    [TestCase(BlankGuide, "BILAL", TestName = "A blank guide has no share_url even with a public web base")]
    [TestCase(NoGuidePage, "SALMAN", TestName = "A level without a guide page has no share_url even when a guide row exists")]
    [TestCase(NoGuideRow, "ABUZAR", TestName = "A level with no guide row has no share_url")]
    public async Task No_guide(int classId, string levelName)
    {
        var reply = await kit.SendAsync(Student, HttpMethod.Get, $"/classes/{classId}/guide");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Body, Is.EqualTo($$"""{"guide":null,"share_url":null,"level_name":"{{levelName}}"}"""));
    }

    [Test]
    public async Task Without_a_public_web_base_the_share_url_is_null()
    {
        using var bare = new MembershipTestKit();

        var reply = await bare.SendAsync(Student, HttpMethod.Get, $"/classes/{WithGuide}/guide");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK), reply.Body);
        Assert.That(reply.Body, Is.EqualTo("""{"guide":"  <p>Gs Miqdad guide</p>\n","share_url":null,"level_name":"MIQDAD"}"""));
    }
}
