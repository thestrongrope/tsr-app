using NUnit.Framework;
using Tsr.Access.Api;

namespace Tsr.Search.Api.Domain;

[TestFixture]
internal sealed class SearchEngineTests
{
    private sealed class FakeIndex(Func<string, IReadOnlyList<SearchHit>> hitsOf) : ISearchIndex
    {
        public List<(string Kind, string Text, SearchScope Scope)> Asked { get; } = [];

        public bool Down { get; init; }

        public Task<IReadOnlyList<SearchHit>> SearchAsync(string kind, string text, SearchScope scope, int size, CancellationToken ct)
        {
            Asked.Add((kind, text, scope));
            return Down ? throw new SearchUnavailableException("down") : Task.FromResult(hitsOf(kind));
        }
    }

    private sealed class FakeFacts : ISearchFacts
    {
        public List<ClassFact> Classes { get; } = [];

        public Dictionary<long, string> Members { get; } = [];

        public Dictionary<long, IReadOnlyList<ClassFact>> Enrolled { get; } = [];

        public Task<bool> HasNumericGenderAsync(int userId, CancellationToken ct) => Task.FromResult(true);

        public Task<IReadOnlyList<ClassFact>> ActiveClassesAsync(IReadOnlyCollection<long> classIds, CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<ClassFact>>(Classes.Where(c => classIds.Contains(c.Id)).ToList());

        public Task<IReadOnlyList<ClassFact>> ActiveClassesOfLevelsAsync(IReadOnlyCollection<long> levelIds, CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<ClassFact>>(Classes.Where(c => levelIds.Contains(c.LevelId)).ToList());

        public Task<IReadOnlyDictionary<long, IReadOnlyList<ClassFact>>> CurrentClassesAsync(IReadOnlyCollection<long> tokens, CancellationToken ct) =>
            Task.FromResult<IReadOnlyDictionary<long, IReadOnlyList<ClassFact>>>(Enrolled.Where(p => tokens.Contains(p.Key)).ToDictionary());

        public Dictionary<long, TeacherFact> Teachers { get; } = [];

        public Dictionary<long, string> Guides { get; } = [];

        public Task<IReadOnlyDictionary<long, string>> GuideLevelsAsync(IReadOnlyCollection<long> levelIds, CancellationToken ct) =>
            Task.FromResult<IReadOnlyDictionary<long, string>>(Guides.Where(p => levelIds.Contains(p.Key)).ToDictionary());

        public Task<IReadOnlyDictionary<long, TeacherFact>> TeachersAsync(IReadOnlyCollection<long> tokens, CancellationToken ct) =>
            Task.FromResult<IReadOnlyDictionary<long, TeacherFact>>(Teachers.Where(p => tokens.Contains(p.Key)).ToDictionary());

        public Task<IReadOnlyDictionary<long, string>> MemberNamesAsync(IReadOnlyCollection<long> tokens, CancellationToken ct) =>
            Task.FromResult<IReadOnlyDictionary<long, string>>(Members.Where(p => tokens.Contains(p.Key)).ToDictionary());
    }

    private static SearchAccess AccessOf(bool all = false, int? gender = null, int[]? ids = null) =>
        new(new Reach(all, gender, ids ?? [], null, null, new SearchReach(all, gender, ids ?? [], null)), new SearchReach(false, null, [], null), []);

    private static SearchAccess TeacherAccess(bool all = false, int[]? genders = null, bool gentsWhoTeach = false) =>
        new(AccessOf().Classes, new SearchReach(all, all ? null : 1, [], null), genders ?? [], gentsWhoTeach);

    private static async Task<IReadOnlyList<long>> TeacherIdsAsync(SearchAccess access, FakeFacts facts, params long[] hits)
    {
        var index = new FakeIndex(_ => [.. hits.Select(h => new SearchHit(h, "x"))]);
        var answer = await new SearchEngine(index, facts).SearchAsync(access, "ab", ["teacher"], CancellationToken.None);
        return [.. answer.Groups.Single().Results.Select(r => r.Id)];
    }

    // Finding 14: PHP re-reads the teacher (still an active teacher) and runs canView on the fresh gender; the port only checked the member exists.
    [Test]
    public async Task A_stale_teacher_hit_of_another_gender_is_dropped_by_the_recheck()
    {
        var facts = new FakeFacts();
        facts.Teachers[1] = new TeacherFact("Was gents", 2, true, true);
        facts.Teachers[2] = new TeacherFact("Gents", 1, true, true);
        Assert.That(await TeacherIdsAsync(TeacherAccess(genders: [1]), facts, 1, 2), Is.EqualTo(new long[] { 2 }));
    }

    [Test]
    public async Task A_former_teacher_is_dropped_even_for_a_caller_who_may_see_every_teacher()
    {
        var facts = new FakeFacts();
        facts.Teachers[1] = new TeacherFact("Former", 1, false, true);
        facts.Teachers[2] = new TeacherFact("Current", 1, true, true);
        Assert.That(await TeacherIdsAsync(TeacherAccess(all: true), facts, 1, 2), Is.EqualTo(new long[] { 2 }));
    }

    [Test]
    public async Task A_member_with_no_gender_is_shown_only_to_a_caller_who_may_see_every_teacher()
    {
        var facts = new FakeFacts();
        facts.Teachers[1] = new TeacherFact("No gender", 0, true, true);
        Assert.That(await TeacherIdsAsync(TeacherAccess(genders: [1, 2]), facts, 1), Is.Empty);
        Assert.That(await TeacherIdsAsync(TeacherAccess(all: true), facts, 1), Is.EqualTo(new long[] { 1 }));
    }

    [Test]
    public async Task A_caller_who_may_look_up_gents_only_through_the_teacher_gender_rule_sees_gents_who_teach_and_no_other_gents()
    {
        var facts = new FakeFacts();
        facts.Teachers[1] = new TeacherFact("Teaches", 1, true, true);
        facts.Teachers[2] = new TeacherFact("Does not teach", 1, true, false);
        facts.Teachers[3] = new TeacherFact("Lady", 2, true, true);
        Assert.That(await TeacherIdsAsync(TeacherAccess(gentsWhoTeach: true), facts, 1, 2, 3), Is.EqualTo(new long[] { 1 }));
    }

    [Test]
    public async Task A_caller_who_may_look_up_gents_by_gender_sees_gents_who_do_not_teach_a_class()
    {
        var facts = new FakeFacts();
        facts.Teachers[2] = new TeacherFact("Does not teach", 1, true, false);
        Assert.That(await TeacherIdsAsync(TeacherAccess(genders: [1]), facts, 2), Is.EqualTo(new long[] { 2 }));
    }

    [Test]
    public async Task A_teacher_who_left_the_member_table_is_dropped_and_the_title_is_the_fresh_name()
    {
        var facts = new FakeFacts();
        facts.Teachers[2] = new TeacherFact("Fresh name", 1, true, true);
        var index = new FakeIndex(_ => [new SearchHit(1, "gone"), new SearchHit(2, "Old name")]);
        var answer = await new SearchEngine(index, facts).SearchAsync(TeacherAccess(all: true), "ab", ["teacher"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Results, Is.EqualTo(new[] { new SearchResult(2, "Fresh name", "Teacher") }));
    }

    [Test]
    public async Task A_kind_the_index_cannot_answer_is_unavailable_not_empty()
    {
        var engine = new SearchEngine(new FakeIndex(_ => []) { Down = true }, new FakeFacts());
        var answer = await engine.SearchAsync(AccessOf(all: true), "ab", ["class"], CancellationToken.None);
        Assert.That(answer.Unavailable, Is.EqualTo(new List<string> { "class" }));
        Assert.That(answer.Groups, Is.Empty);
    }

    [Test]
    public async Task A_caller_with_no_reach_asks_the_index_nothing_and_gets_no_group()
    {
        var index = new FakeIndex(_ => [new SearchHit(900001, "Someone")]);
        var answer = await new SearchEngine(index, new FakeFacts()).SearchAsync(AccessOf(), "ab", SearchPlans.Kinds, CancellationToken.None);
        Assert.That(index.Asked, Is.Empty);
        Assert.That(answer.Groups, Is.Empty);
        Assert.That(answer.Unavailable, Is.Empty);
    }

    [Test]
    public async Task The_callers_text_and_reach_go_to_the_index_as_values()
    {
        var index = new FakeIndex(_ => []);
        await new SearchEngine(index, new FakeFacts()).SearchAsync(AccessOf(ids: [4]), "x OR *", ["student"], CancellationToken.None);
        Assert.That(index.Asked.Single().Text, Is.EqualTo("x OR *"));
        Assert.That(index.Asked.Single().Scope.AnyOf!.Single().Field, Is.EqualTo("class_ids"));
    }

    [Test]
    public async Task A_stale_class_hit_outside_the_reach_is_dropped_by_the_recheck()
    {
        var facts = new FakeFacts();
        facts.Classes.AddRange([new ClassFact(4, "A4", "Level", 1, 1), new ClassFact(5, "B5", "Level", 2, 1)]);
        var index = new FakeIndex(_ => [new SearchHit(4, "A4"), new SearchHit(5, "B5"), new SearchHit(6, "gone")]);
        var answer = await new SearchEngine(index, facts).SearchAsync(AccessOf(ids: [4]), "ab", ["class"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Results, Is.EqualTo(new[] { new SearchResult(4, "A4", "Level") }));
    }

    [Test]
    public async Task A_student_is_shown_only_through_the_classes_the_caller_manages()
    {
        var facts = new FakeFacts();
        facts.Members[900001] = "Reachable";
        facts.Members[900002] = "Elsewhere";
        facts.Enrolled[900001] = [new ClassFact(4, "A4", "", 1, 1), new ClassFact(5, "B5", "", 2, 1)];
        facts.Enrolled[900002] = [new ClassFact(5, "B5", "", 2, 1)];
        var index = new FakeIndex(_ => [new SearchHit(900001, "Reachable"), new SearchHit(900002, "Elsewhere")]);
        var answer = await new SearchEngine(index, facts).SearchAsync(AccessOf(ids: [4]), "ab", ["student"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Results, Is.EqualTo(new[] { new SearchResult(900001, "Reachable", "A4") }));
    }

    [Test]
    public async Task A_subscriber_with_a_current_class_is_a_student_not_a_subscriber()
    {
        var facts = new FakeFacts();
        facts.Members[900001] = "Plain";
        facts.Members[900002] = "Enrolled";
        facts.Enrolled[900002] = [new ClassFact(4, "A4", "", 1, 1)];
        var index = new FakeIndex(_ => [new SearchHit(900001, "Plain"), new SearchHit(900002, "Enrolled")]);
        var answer = await new SearchEngine(index, facts).SearchAsync(AccessOf(all: true), "ab", ["subscriber"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Results.Select(r => r.Id), Is.EqualTo(new long[] { 900001 }));
    }

    [Test]
    public async Task A_guide_opens_the_first_class_of_its_level_the_caller_reaches_and_is_titled_from_the_database()
    {
        var facts = new FakeFacts();
        facts.Classes.AddRange([new ClassFact(4, "A4", "", 1, 7), new ClassFact(5, "B5", "", 2, 7)]);
        facts.Guides[7] = "Level seven";
        var index = new FakeIndex(_ => [new SearchHit(7, "Stale index title")]);
        var answer = await new SearchEngine(index, facts).SearchAsync(AccessOf(gender: 2), "ab", ["guide"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Results, Is.EqualTo(new[] { new SearchResult(5, "Level seven guide", string.Empty) }));
    }

    [Test]
    public async Task A_guide_hit_is_dropped_when_the_guide_no_longer_counts_in_the_database()
    {
        var facts = new FakeFacts();
        facts.Classes.Add(new ClassFact(4, "A4", "", 1, 7));
        var index = new FakeIndex(_ => [new SearchHit(7, "Level seven guide")]);
        var answer = await new SearchEngine(index, facts).SearchAsync(AccessOf(all: true), "ab", ["guide"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Results, Is.Empty);
    }

    [Test]
    public async Task A_group_is_capped_at_fifty_and_says_so()
    {
        var facts = new FakeFacts();
        var hits = new List<SearchHit>();
        for (var id = 1; id <= 80; id++)
        {
            facts.Classes.Add(new ClassFact(id, "C" + id, "", 1, 1));
            hits.Add(new SearchHit(id, "C" + id));
        }

        var answer = await new SearchEngine(new FakeIndex(_ => hits), facts).SearchAsync(AccessOf(all: true), "ab", ["class"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Count, Is.EqualTo(50));
        Assert.That(answer.Groups.Single().Capped, Is.True);
    }

    [Test]
    public async Task An_empty_name_is_shown_as_unnamed()
    {
        var facts = new FakeFacts();
        facts.Classes.Add(new ClassFact(4, string.Empty, "", 1, 1));
        var answer = await new SearchEngine(new FakeIndex(_ => [new SearchHit(4, "")]), facts).SearchAsync(AccessOf(all: true), "ab", ["class"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Results.Single().Title, Is.EqualTo("(unnamed)"));
    }
}
