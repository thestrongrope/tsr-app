namespace Tsr.Search.Api.Domain;

internal sealed record SearchResult(long Id, string Title, string Subtitle);

internal sealed record SearchGroup(string Kind, int Count, bool Capped, IReadOnlyList<SearchResult> Results);

internal sealed record SearchAnswer(IReadOnlyList<SearchGroup> Groups, IReadOnlyList<string> Unavailable);

/// <summary>
/// Searching private data for one caller (PHP SearchModel::search), for each kind asked for, in three steps: the caller's reach is a filter
/// in the query (<see cref="SearchPlans"/>); every hit is checked again against the database through published views, so a stale index can
/// hide a hit but not expose one; the counts come from the hits that passed, capped at <see cref="Cap"/>. A kind the index cannot answer is
/// listed as unavailable, never as "nothing found". Titles come from the database, not the index.
/// </summary>
internal sealed class SearchEngine(ISearchIndex index, ISearchFacts facts)
{
    public const int Cap = 50;

    /// <summary>Hits fetched per kind: more than <see cref="Cap"/>, so some can fail the re-check.</summary>
    public const int Fetch = 100;

    public async Task<SearchAnswer> SearchAsync(SearchAccess access, string text, IReadOnlyList<string> kinds, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(access);
        var groups = new List<SearchGroup>();
        var unavailable = new List<string>();
        foreach (var kind in kinds)
        {
            var plan = SearchPlans.PlanFor(kind, access);
            if (plan is null)
            {
                continue;
            }

            IReadOnlyList<SearchHit> hits = [];
            if (plan.Scope is not null)
            {
                try
                {
                    hits = await index.SearchAsync(kind, text, plan.Scope, Fetch, ct);
                }
                catch (SearchUnavailableException)
                {
                    unavailable.Add(kind);
                    continue;
                }
            }

            var results = (await CheckAsync(kind, access, hits, ct)).Take(Cap).ToList();
            groups.Add(new SearchGroup(kind, results.Count, results.Count >= Cap, results));
        }

        return new SearchAnswer(groups, unavailable);
    }

    private async Task<IReadOnlyList<SearchResult>> CheckAsync(string kind, SearchAccess access, IReadOnlyList<SearchHit> hits, CancellationToken ct)
    {
        var ids = hits.Where(h => h.Id > 0).Select(h => h.Id).Distinct().ToList();
        if (ids.Count == 0)
        {
            return [];
        }

        return kind switch
        {
            SearchPlans.ClassKind => await CheckClassesAsync(access, hits, ids, ct),
            SearchPlans.TeacherKind => await CheckTeachersAsync(access, hits, ids, ct),
            SearchPlans.GuideKind => await CheckGuidesAsync(access, hits, ids, ct),
            SearchPlans.StudentKind => await CheckStudentsAsync(access, hits, ids, ct),
            SearchPlans.SubscriberKind => await CheckSubscribersAsync(access, hits, ids, ct),
            _ => [],
        };
    }

    private async Task<IReadOnlyList<SearchResult>> CheckClassesAsync(SearchAccess access, IReadOnlyList<SearchHit> hits, List<long> ids, CancellationToken ct)
    {
        var fresh = (await facts.ActiveClassesAsync(ids, ct)).ToDictionary(c => (long)c.Id);
        return hits
            .Where(h => fresh.TryGetValue(h.Id, out var c) && SearchPlans.Allows(access.Classes.Search, [c.Id], [c.Gender], 0))
            .Select(h => fresh[h.Id])
            .Select(c => new SearchResult(c.Id, Title(c.Code), c.LevelName))
            .ToList();
    }

    // PHP re-reads the teacher (searchsource teacherRow: an active teacher) and asks TeachersModel::canView about the fresh gender, so a stale index can hide a hit, never expose one.
    private async Task<IReadOnlyList<SearchResult>> CheckTeachersAsync(SearchAccess access, IReadOnlyList<SearchHit> hits, List<long> ids, CancellationToken ct)
    {
        var teachers = await facts.TeachersAsync(ids, ct);
        return hits
            .Where(h => teachers.TryGetValue(h.Id, out var teacher) && teacher.Active && MayView(access, teacher))
            .Select(h => new SearchResult(h.Id, Title(teachers[h.Id].Name), "Teacher"))
            .ToList();
    }

    // canView: every teacher for the "all" scope; else a member with a gender, by gender, or (gents only) by the teacher-gender rule, which also needs the member to teach.
    private static bool MayView(SearchAccess access, TeacherFact teacher)
    {
        if (access.Teachers.All)
        {
            return true;
        }

        if (teacher.Gender is not (1 or 2))
        {
            return false;
        }

        return access.TeacherGenders.Contains(teacher.Gender) || (teacher.Gender == 1 && access.GentsWhoTeach && teacher.Teaches);
    }

    // PHP re-reads the guide (guideRow): a hit for a guide that no longer counts is dropped, and the title is the database's level name.
    // It is read through a class of its level: kept when the caller reaches one, and that class is what the result opens.
    private async Task<IReadOnlyList<SearchResult>> CheckGuidesAsync(SearchAccess access, IReadOnlyList<SearchHit> hits, List<long> ids, CancellationToken ct)
    {
        var guides = await facts.GuideLevelsAsync(ids, ct);
        var classes = await facts.ActiveClassesOfLevelsAsync([.. guides.Keys], ct);
        var results = new List<SearchResult>();
        foreach (var hit in hits)
        {
            if (!guides.TryGetValue(hit.Id, out var level))
            {
                continue;
            }

            var reached = classes.FirstOrDefault(c => c.LevelId == hit.Id && SearchPlans.Allows(access.Classes.Search, [c.Id], [c.Gender], 0));
            if (reached is not null)
            {
                results.Add(new SearchResult(reached.Id, Title(level + " guide"), string.Empty));
            }
        }

        return results;
    }

    // A student is shown through the classes of theirs the caller manages; one with none of them is not shown.
    private async Task<IReadOnlyList<SearchResult>> CheckStudentsAsync(SearchAccess access, IReadOnlyList<SearchHit> hits, List<long> ids, CancellationToken ct)
    {
        var managed = SearchPlans.Managed(access.Classes);
        var names = await facts.MemberNamesAsync(ids, ct);
        var current = await facts.CurrentClassesAsync(ids, ct);
        var results = new List<SearchResult>();
        foreach (var hit in hits)
        {
            if (!names.TryGetValue(hit.Id, out var name) || !current.TryGetValue(hit.Id, out var classes))
            {
                continue;
            }

            var reached = classes.Where(c => SearchPlans.Allows(managed, [c.Id], [c.Gender], 0)).ToList();
            if (reached.Count > 0)
            {
                results.Add(new SearchResult(hit.Id, Title(name), string.Join(", ", reached.Select(c => c.Code))));
            }
        }

        return results;
    }

    // A subscriber is a member with no current class, shown to the caller who reaches every class.
    private async Task<IReadOnlyList<SearchResult>> CheckSubscribersAsync(SearchAccess access, IReadOnlyList<SearchHit> hits, List<long> ids, CancellationToken ct)
    {
        if (!access.Classes.All)
        {
            return [];
        }

        var names = await facts.MemberNamesAsync(ids, ct);
        var current = await facts.CurrentClassesAsync(ids, ct);
        return hits
            .Where(h => names.ContainsKey(h.Id) && !current.ContainsKey(h.Id))
            .Select(h => new SearchResult(h.Id, Title(names[h.Id]), string.Empty))
            .ToList();
    }

    private static string Title(string name) => name.Length > 0 ? name : "(unnamed)";
}
