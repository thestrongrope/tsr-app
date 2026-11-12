using NUnit.Framework;
using Tsr.Access.Api;

namespace Tsr.Search.Api.Domain;

[TestFixture]
internal sealed class SearchPlansTests
{
    private static readonly SearchReach Nothing = new(false, null, [], null);

    private static SearchAccess Access(SearchReach classesSearch, bool all = false, int? gender = null, int[]? ids = null, SearchReach? teachers = null, int[]? teacherGenders = null) =>
        new(new Reach(all, gender, ids ?? [], null, null, classesSearch), teachers ?? Nothing, teacherGenders ?? []);

    private static string Describe(SearchScope scope) =>
        scope.AnyOf is null ? "everything" : string.Join(";", scope.AnyOf.Select(c => c.Field + "=" + string.Join(",", c.Values)));

    [TestCase("class")]
    [TestCase("guide")]
    [TestCase("student")]
    [TestCase("teacher")]
    [TestCase("subscriber")]
    public void A_caller_with_no_reach_has_no_plan_for_any_kind(string kind) =>
        Assert.That(SearchPlans.PlanFor(kind, Access(Nothing)), Is.Null);

    [Test]
    public void An_unknown_kind_has_no_plan() =>
        Assert.That(SearchPlans.PlanFor("member", Access(new SearchReach(true, null, [], null), all: true)), Is.Null);

    [Test]
    public void A_class_plan_filters_by_gender_assigned_classes_and_self()
    {
        var plan = SearchPlans.PlanFor("class", Access(new SearchReach(false, 2, [4, 9], 900001)))!;
        Assert.That(Describe(plan.Scope!), Is.EqualTo("class_genders=2;class_ids=4,9;token=900001"));
    }

    [Test]
    public void A_class_plan_for_all_is_not_filtered() =>
        Assert.That(SearchPlans.PlanFor("class", Access(new SearchReach(true, null, [], null), all: true))!.Scope, Is.SameAs(SearchScope.Everything));

    [Test]
    public void A_student_plan_ignores_self_so_a_student_cannot_find_classmates()
    {
        var plan = SearchPlans.PlanFor("student", Access(new SearchReach(false, null, [4], 900001), ids: [4]))!;
        Assert.That(Describe(plan.Scope!), Is.EqualTo("class_ids=4"));
    }

    [Test]
    public void A_student_plan_uses_the_managed_classes_not_the_ones_the_caller_only_attends() =>
        Assert.That(SearchPlans.PlanFor("student", Access(new SearchReach(false, null, [7], null))), Is.Null);

    [Test]
    public void A_subscriber_plan_needs_every_class()
    {
        Assert.That(SearchPlans.PlanFor("subscriber", Access(new SearchReach(false, 1, [], null), gender: 1)), Is.Null);
        Assert.That(SearchPlans.PlanFor("subscriber", Access(new SearchReach(true, null, [], null), all: true))!.Scope, Is.SameAs(SearchScope.Everything));
    }

    // PHP sends no filter for teachers (searchRaw with an empty filter, then canView on every hit): a stale indexed gender cannot hide a teacher the caller may see now.
    [TestCase(false, 2, null)]
    [TestCase(false, null, 3)]
    [TestCase(true, null, null)]
    public void A_teacher_plan_asks_without_a_filter_whenever_the_caller_has_a_way_in(bool all, int? gender, int? classId)
    {
        var plan = SearchPlans.PlanFor("teacher", Access(Nothing, teachers: new SearchReach(all, gender, classId is { } id ? [id] : [], null)))!;
        Assert.That(plan.Scope, Is.SameAs(SearchScope.Everything));
    }

    [Test]
    public void A_teacher_plan_without_a_way_in_is_no_group() =>
        Assert.That(SearchPlans.PlanFor("teacher", Access(Nothing, teachers: new SearchReach(false, null, [], null))), Is.Null);

    [Test]
    public void A_limited_scope_needs_a_clause() =>
        Assert.Throws<ArgumentException>(() => SearchScope.Limited([]));

    [Test]
    public void Allows_matches_all_gender_class_or_self()
    {
        var reach = new SearchReach(false, 1, [5], 77);
        Assert.That(SearchPlans.Allows(reach, [9], [1], 0), Is.True);
        Assert.That(SearchPlans.Allows(reach, [5], [2], 0), Is.True);
        Assert.That(SearchPlans.Allows(reach, [9], [2], 77), Is.True);
        Assert.That(SearchPlans.Allows(reach, [9], [2], 78), Is.False);
        Assert.That(SearchPlans.Allows(new SearchReach(true, null, [], null), [], [], 0), Is.True);
    }
}
