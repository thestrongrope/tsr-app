using NUnit.Framework;
using Tsr.Search.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The search feed's document source (PHP searchsource.php allDocs) against a real database as the limited role: which documents exist for each kind, read through published views only.
/// Elasticsearch is not involved (no index exists in any stack).
/// </summary>
public sealed class TestSearchFeedTests
{
    private const string ClassInsert = "insert into classes.classes (id, code, language_id, link, name, class_level_id, teacher, gender, format, status, created_by) values ";

    private SearchDocumentSource source = null!;

    [SetUp]
    public async Task SeedAsync()
    {
        source = new SearchDocumentSource(new DbSettings(TestDatabase.AppConnection));
        await MembershipTestKit.ResetAsync();
        await TestDatabase.ExecuteAsync(
            "truncate classes.class_students, classes.class_schedules, classes.classes, classes.teachers, classes.guides restart identity cascade; "
            + "insert into platform.genders (id, name) values (1, 'Male'), (2, 'Female') on conflict do nothing; "
            + "insert into classes.class_levels (id, code, name, sort_order) values (2, 'AZ', 'ABUZAR', 2), (3, 'MK', 'MIQDAD', 3), (6, 'NP', 'NOPAGE', 6) "
            + "on conflict (id) do update set name = excluded.name");
    }

    private async Task<List<SearchDocument>> AllAsync()
    {
        await using var run = await source.TryOpenAsync(CancellationToken.None) ?? throw new AssertionException("the lock was held");
        var documents = new List<SearchDocument>();
        await foreach (var document in run.DocumentsAsync(CancellationToken.None))
        {
            documents.Add(document);
        }

        return documents;
    }

    private static Task<int> MemberAsync(int token, string name, string? gender = "1") => MembershipTestKit.AddMemberAsync(token, name, gender);

    private static Task AddClassAsync(int id, string code, int gender, string status, int level = 3) =>
        TestDatabase.ExecuteAsync(ClassInsert + $"({id}, {MembershipTestKit.Quote(code)}, 1, 'sf{id}', 'Class {id}', {level}, 900001, {gender}, 'Offline', '{status}', 900001)");

    private static Task EnrolAsync(int classId, int token, bool removed = false) =>
        TestDatabase.ExecuteAsync(
            "insert into classes.class_students (class_id, token_no, joined_on, mcq_admin, status, removed_at) values "
            + $"({classId}, {token}, date '2025-01-06', 0, 'A', {(removed ? "now()" : "null")})");

    private static SearchDocument Of(List<SearchDocument> all, string kind, long id) => all.Single(d => d.Kind == kind && d.Id == id);

    [Test]
    public async Task An_active_class_is_a_document_with_its_decoded_code_level_and_gender_and_a_closed_one_is_not()
    {
        await AddClassAsync(98801, "SF-A &amp; B", 2, "A");
        await AddClassAsync(98802, "SF-CLOSED", 1, "I");

        var all = await AllAsync();

        var document = Of(all, "class", 98801);
        Assert.That(document.Name, Is.EqualTo("SF-A & B"));
        Assert.That(document.Gender, Is.EqualTo(2));
        Assert.That(document.Level, Is.EqualTo("MIQDAD"));
        Assert.That(document.LevelId, Is.EqualTo(3));
        Assert.That(document.ClassIds, Is.EqualTo(new List<long> { 98801 }));
        Assert.That(document.ClassGenders, Is.EqualTo(new List<int> { 2 }));
        Assert.That(document.Token, Is.Zero);
        Assert.That(document.DocId, Is.EqualTo("class:98801"));
        Assert.That(all.Any(d => d.Kind == "class" && d.Id == 98802), Is.False);
    }

    [Test]
    public async Task Only_a_member_with_an_active_teacher_row_is_a_teacher_with_the_gender_mapped()
    {
        await MemberAsync(900101, "Active Teacher", "Male");
        await MemberAsync(900102, "Inactive Teacher");
        await MemberAsync(900103, "Not A Teacher");
        foreach (var (token, status) in new[] { (900101, "A"), (900102, "I") })
        {
            await TestDatabase.ExecuteAsync($"insert into classes.teachers (token, salman, abuzar, miqdad, ammar, bilal, status, created_at) values ({token}, 0, 0, 0, 0, 0, '{status}', now())");
        }

        var all = await AllAsync();

        var teacher = Of(all, "teacher", 900101);
        Assert.That(teacher.Name, Is.EqualTo("Active Teacher"));
        Assert.That(teacher.Gender, Is.EqualTo(1));
        Assert.That(teacher.Token, Is.EqualTo(900101));
        Assert.That(all.Any(d => d.Kind == "teacher" && d.Id == 900102), Is.False);
        Assert.That(all.Any(d => d.Kind == "teacher" && d.Id == 900103), Is.False);
    }

    [Test]
    public async Task A_guide_exists_for_a_non_blank_language_one_guide_of_a_level_with_a_page_with_the_level_id_as_its_id()
    {
        await TestDatabase.ExecuteAsync(
            "insert into classes.guides (level_id, language_id, guide, created_by) values (2, 1, 'A real guide', 1), (3, 1, '   ', 1), (6, 1, 'No public page', 1), (3, 2, 'Other language', 1)");

        var guides = (await AllAsync()).Where(d => d.Kind == "guide").ToList();

        Assert.That(guides, Has.Count.EqualTo(1));
        Assert.That(guides[0].Id, Is.EqualTo(2));
        Assert.That(guides[0].Name, Is.EqualTo("ABUZAR guide"));
        Assert.That(guides[0].Level, Is.EqualTo("ABUZAR"));
        Assert.That(guides[0].LevelId, Is.EqualTo(2));
        Assert.That(guides[0].Gender, Is.Zero);
    }

    [Test]
    public async Task A_person_in_an_active_class_is_a_student_with_every_current_active_class_and_never_also_a_subscriber()
    {
        await MemberAsync(900201, "Both Classes");
        await AddClassAsync(98811, "SF-M", 1, "A");
        await AddClassAsync(98812, "SF-F", 2, "A");
        await AddClassAsync(98813, "SF-CLOSED", 1, "I");
        await EnrolAsync(98811, 900201);
        await EnrolAsync(98812, 900201);
        await EnrolAsync(98813, 900201);

        var all = await AllAsync();

        var student = Of(all, "student", 900201);
        Assert.That(student.ClassIds, Is.EquivalentTo(new List<long> { 98811, 98812 }));
        Assert.That(student.ClassGenders, Is.EquivalentTo(new List<int> { 1, 2 }));
        Assert.That(student.Token, Is.EqualTo(900201));
        Assert.That(all.Any(d => d.Kind == "subscriber" && d.Id == 900201), Is.False);
    }

    [Test]
    public async Task A_person_with_only_a_closed_class_or_a_removed_enrolment_or_none_is_a_subscriber()
    {
        await MemberAsync(900211, "Closed Only");
        await MemberAsync(900212, "Removed Only");
        await MemberAsync(900213, "No Class");
        await AddClassAsync(98821, "SF-OPEN", 1, "A");
        await AddClassAsync(98822, "SF-CLOSED", 1, "I");
        await EnrolAsync(98822, 900211);
        await EnrolAsync(98821, 900212, removed: true);

        var all = await AllAsync();

        foreach (var token in new[] { 900211, 900212, 900213 })
        {
            var subscriber = Of(all, "subscriber", token);
            Assert.That(subscriber.ClassIds, Is.Empty);
            Assert.That(all.Any(d => d.Kind == "student" && d.Id == token), Is.False, "token " + token);
        }
    }

    [Test]
    public async Task A_member_with_a_token_of_zero_is_never_indexed_and_the_gender_text_is_mapped_to_0_1_or_2()
    {
        await MemberAsync(0, "Zero Token");
        await MemberAsync(900301, "Male Word", "Male");
        await MemberAsync(900302, "Female Number", "2");
        await MemberAsync(900303, "Unknown", "x");
        await MemberAsync(900304, "No Gender", null);

        var all = await AllAsync();

        Assert.That(all.Any(d => d.Id == 0 && d.Kind is "student" or "subscriber" or "teacher"), Is.False);
        Assert.That(Of(all, "subscriber", 900301).Gender, Is.EqualTo(1));
        Assert.That(Of(all, "subscriber", 900302).Gender, Is.EqualTo(2));
        Assert.That(Of(all, "subscriber", 900303).Gender, Is.Zero);
        Assert.That(Of(all, "subscriber", 900304).Gender, Is.Zero);
    }

    [Test]
    public async Task The_source_pages_past_1000_rows_and_yields_each_document_once()
    {
        await TestDatabase.ExecuteAsync(
            "insert into identity.users (token, email, firebase_uid) select 910000 + n, 'pg' || n || '@example.invalid', 'pg-uid-' || n from generate_series(1, 2300) n; "
            + "insert into membership.member_profiles (user_id, name, gender) select id, 'Paged ' || token, '1' from identity.users where token >= 910001; "
            + ClassInsert.Replace(" values ", " select ", StringComparison.Ordinal) + "98900 + n, 'PG-' || n, 1, 'pglink' || n, 'Paged', 3, 900001, 1, 'Offline', 'A', 900001 from generate_series(1, 1100) n");

        var all = await AllAsync();

        Assert.That(all.Count(d => d.Kind == "subscriber"), Is.EqualTo(2300));
        Assert.That(all.Count(d => d.Kind == "class"), Is.EqualTo(1100));
        Assert.That(all.Select(d => d.DocId).Distinct().Count(), Is.EqualTo(all.Count));
    }

    [Test]
    public async Task Only_one_run_holds_the_lock_at_a_time_and_it_is_free_again_after_dispose()
    {
        await using (var first = await source.TryOpenAsync(CancellationToken.None))
        {
            Assert.That(first, Is.Not.Null);
            Assert.That(await source.TryOpenAsync(CancellationToken.None), Is.Null);
        }

        await using var again = await source.TryOpenAsync(CancellationToken.None);
        Assert.That(again, Is.Not.Null);
    }
}
