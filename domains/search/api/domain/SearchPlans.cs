using Tsr.Access.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// What the caller may find, worked out by the slice from <c>access</c>: the reach of <c>classes:read</c> (classes, guides, students,
/// subscribers) and of <c>teachers:lookup</c>, and the genders of teacher the caller may look up (PHP TeachersModel::canView).
/// </summary>
internal sealed record SearchAccess(Reach Classes, SearchReach Teachers, IReadOnlyList<int> TeacherGenders);

/// <summary>How to ask the index for one kind: <see cref="Scope"/> null means the caller may look the kind up but no document can qualify, so there is nothing to ask.</summary>
internal sealed record KindPlan(SearchScope? Scope);

/// <summary>
/// The caller's reach as a filter in the query (PHP SearchModel::plan and SearchFilterModel::toEs). A kind the caller has no way in to has
/// no plan (null): it is not queried and no group is returned for it. The filter is part of the query sent to the index, so the index only
/// ever considers documents the caller could see; the re-check afterwards (<see cref="SearchEngine"/>) only narrows further.
/// </summary>
internal static class SearchPlans
{
    public const string ClassKind = "class";

    public const string TeacherKind = "teacher";

    public const string GuideKind = "guide";

    public const string StudentKind = "student";

    public const string SubscriberKind = "subscriber";

    /// <summary>The kinds, in the order the endpoint answers them when none is named.</summary>
    public static readonly IReadOnlyList<string> Kinds = [ClassKind, TeacherKind, GuideKind, StudentKind, SubscriberKind];

    public static KindPlan? PlanFor(string kind, SearchAccess access)
    {
        ArgumentNullException.ThrowIfNull(access);
        return kind switch
        {
            ClassKind => ClassPlan(access.Classes.Search),
            GuideKind => IsEmpty(access.Classes.Search) ? null : new KindPlan(SearchScope.Everything),
            StudentKind => ClassPlan(Managed(access.Classes)),
            TeacherKind => TeacherPlan(access),
            SubscriberKind => access.Classes.All ? new KindPlan(SearchScope.Everything) : null,
            _ => null,
        };
    }

    /// <summary>PHP managed(): the management scopes only, no self.</summary>
    public static SearchReach Managed(Reach reach)
    {
        ArgumentNullException.ThrowIfNull(reach);
        return new SearchReach(reach.All, reach.Gender, reach.ClassIds, null);
    }

    public static bool IsEmpty(SearchReach reach)
    {
        ArgumentNullException.ThrowIfNull(reach);
        return !reach.All && reach.Gender is null && reach.ClassIds.Count == 0 && reach.Self is null;
    }

    /// <summary>PHP SearchFilterModel::allows: does a document with these class ids, class genders and token lie in the reach?</summary>
    public static bool Allows(SearchReach reach, IReadOnlyCollection<int> classIds, IReadOnlyCollection<int> classGenders, int token)
    {
        ArgumentNullException.ThrowIfNull(reach);
        ArgumentNullException.ThrowIfNull(classIds);
        ArgumentNullException.ThrowIfNull(classGenders);
        return reach.All
            || (reach.Gender is int gender && classGenders.Contains(gender))
            || reach.ClassIds.Any(classIds.Contains)
            || (reach.Self is int self && token == self);
    }

    private static KindPlan? ClassPlan(SearchReach reach)
    {
        if (IsEmpty(reach))
        {
            return null;
        }

        if (reach.All)
        {
            return new KindPlan(SearchScope.Everything);
        }

        var clauses = new List<TermsClause>();
        if (reach.Gender is int gender)
        {
            clauses.Add(new TermsClause("class_genders", [gender]));
        }

        if (reach.ClassIds.Count > 0)
        {
            clauses.Add(new TermsClause("class_ids", reach.ClassIds));
        }

        if (reach.Self is int self)
        {
            clauses.Add(new TermsClause("token", [self]));
        }

        return new KindPlan(SearchScope.Limited(clauses));
    }

    // PHP filters teachers only after the query (canView on every hit); here the genders canView would accept are in the query, so no other teacher is read.
    private static KindPlan? TeacherPlan(SearchAccess access)
    {
        if (IsEmpty(access.Teachers))
        {
            return null;
        }

        if (access.Teachers.All)
        {
            return new KindPlan(SearchScope.Everything);
        }

        return access.TeacherGenders.Count == 0
            ? new KindPlan(null)
            : new KindPlan(SearchScope.Limited([new TermsClause("gender", access.TeacherGenders)]));
    }
}
