using System.Net;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Search.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>
/// GET /search of the edge lane against a FAKE index (no Elasticsearch in any stack): what the engine ASKS the index (the reach filter) and what the database re-check KEEPS of the hits it gets back.
/// Callers: 927020 super admin, 927021 gents admin (role 3, gender 1), 927022 ladies admin (role 4, gender 2), 927023 plain member, 927024 member without a gender.
/// Teachers: 927030 active gents, 927031 gents whose teacher row is now inactive, 927032 a member now female (the index still says gents), 927033 a member with no gender, 927034 a member who never taught.
/// </summary>
public sealed class TestEdgeSearchTests
{
    private const int Super = 927020;
    private const int GentsAdmin = 927021;
    private const int LadiesAdmin = 927022;
    private const int Plain = 927023;
    private const int NoGender = 927024;

    private sealed class FakeIndex : ISearchIndex
    {
        public List<(string Kind, string Text, SearchScope Scope)> Asked { get; } = [];

        public Dictionary<string, List<SearchHit>> Hits { get; } = [];

        public Task<IReadOnlyList<SearchHit>> SearchAsync(string kind, string text, SearchScope scope, int size, CancellationToken ct)
        {
            Asked.Add((kind, text, scope));
            return Task.FromResult<IReadOnlyList<SearchHit>>(Hits.TryGetValue(kind, out var hits) ? hits : []);
        }
    }

    private readonly FakeIndex index = new();
    private MembershipTestKit kit = null!;

    [OneTimeSetUp]
    public void Start() => kit = new MembershipTestKit(services => services.AddSingleton<ISearchIndex>(index));

    [OneTimeTearDown]
    public void Stop() => kit.Dispose();

    [SetUp]
    public async Task SeedAsync()
    {
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync("truncate classes.class_students, classes.class_schedules, classes.classes, classes.teachers restart identity cascade");
        foreach (var (token, gender, role) in new (int, string?, int)[]
        {
            (Super, "1", 1), (GentsAdmin, "1", 3), (LadiesAdmin, "2", 4), (Plain, "1", 0), (NoGender, null, 1),
            (927030, "1", 0), (927031, "1", 0), (927032, "2", 0), (927033, null, 0), (927034, "1", 0),
        })
        {
            var id = await MembershipTestKit.AddMemberAsync(token, "Edge Member " + token, gender);
            if (role != 0)
            {
                await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({id}, {role})");
            }
        }

        foreach (var (token, status) in new[] { (927030, "A"), (927031, "I"), (927032, "A"), (927033, "A") })
        {
            await TestDatabase.ExecuteAsync($"insert into classes.teachers (token, salman, abuzar, miqdad, ammar, bilal, status, created_at) values ({token}, 0, 0, 0, 0, 0, '{status}', now())");
        }

        index.Asked.Clear();
        index.Hits.Clear();
    }

    private async Task<(HttpStatusCode Status, string Body, List<long> Ids)> SearchAsync(int caller, string kind)
    {
        var reply = await kit.SendAsync(caller, HttpMethod.Get, "/search?q=edge&kinds=" + kind);
        var ids = reply.Status == HttpStatusCode.OK
            ? reply.Json!["groups"]!.AsArray().SelectMany(g => g!["results"]!.AsArray().Select(r => r!["id"]!.GetValue<long>())).ToList()
            : [];
        return (reply.Status, reply.Body, ids);
    }

    private void IndexReturns(string kind, params long[] ids) => index.Hits[kind] = [.. ids.Select(id => new SearchHit(id, "stale name"))];

    private static string Filter(SearchScope scope) =>
        scope.AnyOf is null ? "everything" : string.Join(" | ", scope.AnyOf.Select(c => c.Field + " in " + string.Join(",", c.Values.Order())));

    [Test]
    public async Task A_stale_teacher_hit_of_the_wrong_gender_a_former_teacher_and_a_non_teacher_are_dropped()
    {
        IndexReturns("teacher", 927030, 927031, 927032, 927033, 927034);

        var gents = await SearchAsync(GentsAdmin, "teacher");
        var super = await SearchAsync(Super, "teacher");
        var ladies = await SearchAsync(LadiesAdmin, "teacher");

        Assert.That(gents.Ids, Is.EqualTo(new List<long> { 927030 }), gents.Body);
        Assert.That(super.Ids, Is.EqualTo(new List<long> { 927030, 927032, 927033 }), super.Body);
        Assert.That(ladies.Ids, Is.EqualTo(new List<long> { 927030, 927032 }), ladies.Body);
    }

    [Test]
    public async Task The_teacher_filter_sent_to_the_index_follows_the_callers_reach()
    {
        await SearchAsync(Super, "teacher");
        await SearchAsync(GentsAdmin, "teacher");
        await SearchAsync(LadiesAdmin, "teacher");

        Assert.That(index.Asked.Select(a => a.Kind), Is.All.EqualTo("teacher"));
        Assert.That(index.Asked.Select(a => Filter(a.Scope)), Is.EqualTo(new List<string> { "everything", "gender in 1", "gender in 1,2" }));
        Assert.That(index.Asked.Select(a => a.Text), Is.All.EqualTo("edge"));
    }

    [Test]
    public async Task A_class_that_closed_is_dropped_and_a_removed_enrolment_hides_the_student_from_a_gents_admin()
    {
        await TestDatabase.ExecuteAsync(
            "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (3, 'MK', 'MIQDAD', 3) on conflict do nothing; "
            + "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values "
            + "(98701, 'EDGE-OPEN', 1, 'edgelink1', 'Open', 3, 927030, 1, 'Offline', 'A', 927020), "
            + "(98702, 'EDGE-CLOSED', 1, 'edgelink2', 'Closed', 3, 927030, 1, 'Offline', 'I', 927020), "
            + "(98703, 'EDGE-LADIES', 1, 'edgelink3', 'Ladies', 3, 927030, 2, 'Offline', 'A', 927020); "
            + "insert into classes.class_students (id, class_id, token_no, joined_on, mcq_admin, status, removed_at) values "
            + "(9770001, 98701, 927034, date '2025-01-06', 0, 'A', null), (9770002, 98701, 927031, date '2025-01-06', 0, 'A', now()), (9770003, 98703, 927032, date '2025-01-06', 0, 'A', null)");
        IndexReturns("class", 98701, 98702, 98703);
        IndexReturns("student", 927034, 927031, 927032);

        var classes = await SearchAsync(GentsAdmin, "class");
        var students = await SearchAsync(GentsAdmin, "student");
        var superStudents = await SearchAsync(Super, "student");

        Assert.That(classes.Ids, Is.EqualTo(new List<long> { 98701 }), classes.Body);
        Assert.That(students.Ids, Is.EqualTo(new List<long> { 927034 }), students.Body);
        Assert.That(superStudents.Ids, Is.EqualTo(new List<long> { 927034, 927032 }), superStudents.Body);
        Assert.That(Filter(index.Asked.First(a => a.Kind == "class").Scope), Does.Contain("class_genders in 1"));
    }

    [Test]
    public async Task The_guards_400_for_no_gender_422_for_bad_text_and_kinds_and_a_plain_member_gets_no_student_teacher_or_subscriber_group()
    {
        var noGender = await kit.SendAsync(NoGender, HttpMethod.Get, "/search?q=edge");
        var shortText = await kit.SendAsync(Super, HttpMethod.Get, "/search?q=e");
        var badKind = await kit.SendAsync(Super, HttpMethod.Get, "/search?q=edge&kinds=class,nope");
        var nul = await kit.SendAsync(Super, HttpMethod.Get, "/search?q=ab%00cd");
        var plain = await kit.SendAsync(Plain, HttpMethod.Get, "/search?q=edge&kinds=student,teacher,subscriber");
        var nobody = await kit.SendUnsignedAsync(HttpMethod.Get, "/search?q=edge");

        Assert.That(noGender.Status, Is.EqualTo(HttpStatusCode.BadRequest), noGender.Body);
        Assert.That(noGender.Detail, Is.EqualTo("User gender not set; update profile first"));
        Assert.That(shortText.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(badKind.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity));
        Assert.That(plain.Status, Is.EqualTo(HttpStatusCode.OK), plain.Body);
        Assert.That(plain.Json!["groups"]!.AsArray(), Is.Empty, "a plain member has no way in to students, teachers or subscribers");
        Assert.That(nobody.Status, Is.EqualTo(HttpStatusCode.Unauthorized));
        Assert.That(nul.Status, Is.EqualTo(HttpStatusCode.UnprocessableEntity), nul.Body);
        Assert.That(index.Asked, Is.Empty);
    }
}
