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

        public Task<IReadOnlyDictionary<long, string>> MemberNamesAsync(IReadOnlyCollection<long> tokens, CancellationToken ct) =>
            Task.FromResult<IReadOnlyDictionary<long, string>>(Members.Where(p => tokens.Contains(p.Key)).ToDictionary());
    }

    private static SearchAccess AccessOf(bool all = false, int? gender = null, int[]? ids = null) =>
        new(new Reach(all, gender, ids ?? [], null, null, new SearchReach(all, gender, ids ?? [], null)), new SearchReach(false, null, [], null), []);

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
    public async Task A_guide_opens_the_first_class_of_its_level_the_caller_reaches()
    {
        var facts = new FakeFacts();
        facts.Classes.AddRange([new ClassFact(4, "A4", "", 1, 7), new ClassFact(5, "B5", "", 2, 7)]);
        var index = new FakeIndex(_ => [new SearchHit(7, "Level seven guide")]);
        var answer = await new SearchEngine(index, facts).SearchAsync(AccessOf(gender: 2), "ab", ["guide"], CancellationToken.None);
        Assert.That(answer.Groups.Single().Results, Is.EqualTo(new[] { new SearchResult(5, "Level seven guide", string.Empty) }));
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
