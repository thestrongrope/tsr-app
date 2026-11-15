using NUnit.Framework;
using Tsr.Access.Api;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class ReportScopeTests
{
    [TestCase(2, "1", 2)]
    [TestCase(1, "2", 1)]
    [TestCase(1, null, 1)]
    [TestCase(null, "2", 2)]
    [TestCase(null, "1", 1)]
    [TestCase(null, null, 1)]
    [TestCase(null, "", 1)]
    [TestCase(null, "02", 1)]
    [TestCase(null, " 2", 1)]
    [TestCase(null, "3", 1)]
    public void The_gender_lock_overrides_the_gender_asked_for_and_only_the_text_2_asks_for_ladies(int? locked, string? asked, int expected) =>
        Assert.That(ReportScope.GenderOf(locked, asked), Is.EqualTo(expected));

    private static Reach ReachOf(bool all, int? gender, params int[] ids) => new(all, gender, ids, null, null, new SearchReach(all, gender, ids, null));

    [Test]
    public void The_scope_carries_the_reach_as_the_query_reads_it()
    {
        var scope = ReportScope.Of(ReachOf(false, 2, 7, 9), 2);
        Assert.That(scope.All, Is.False);
        Assert.That(scope.HasGenderLimit, Is.True);
        Assert.That(scope.GenderLimit, Is.EqualTo(2));
        Assert.That(scope.ClassIds, Is.EqualTo((int[])[7, 9]));
        Assert.That(ReportScope.Of(ReachOf(true, null), 1).HasGenderLimit, Is.False);
    }
}
