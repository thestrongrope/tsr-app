using NUnit.Framework;

namespace Tsr.Search.Api.Domain;

/// <summary>TC-SRCH-R10-02: weighted reciprocal rank fusion as tsr-web's <c>rrfFuse</c> does it: each hit at 0-based place i of a list adds weight / (60 + i + 1); the first list's hit is kept; equal scores keep first-met order.</summary>
[TestFixture]
internal sealed class ReciprocalRankTests
{
    private static LectureResult Lecture(string slug, double score = 0) =>
        new(slug, slug, "u", null, [], "en", null, null, "[]", [], [], score, null);

    [Test]
    public void Scores_add_up_over_the_lists_and_the_best_sum_comes_first()
    {
        var keyword = new[] { Lecture("a"), Lecture("b"), Lecture("c") };
        var meaning = new[] { Lecture("c"), Lecture("a"), Lecture("d") };

        var fused = ReciprocalRank.Fuse([(keyword, 1.0), (meaning, 0.25)]);

        // a: 1/61 + 0.25/62 = 0.020425; c: 1/63 + 0.25/61 = 0.019971; b: 1/62 = 0.016129; d: 0.25/63 = 0.003968.
        Assert.That(fused.Select(l => l.Slug), Is.EqualTo((string[])["a", "c", "b", "d"]));
    }

    [Test]
    public void The_scores_are_the_sum_over_the_lists_of_weight_over_60_plus_place_plus_1()
    {
        var keyword = new[] { Lecture("a"), Lecture("b"), Lecture("c") };
        var meaning = new[] { Lecture("c"), Lecture("a"), Lecture("d") };

        var scored = ReciprocalRank.FuseScored([(keyword, 1.0), (meaning, 0.25)]).ToDictionary(s => s.Hit.Slug, s => s.Score);

        Assert.That(scored["a"], Is.EqualTo((1.0 / 61) + (0.25 / 62)).Within(1e-12));
        Assert.That(scored["b"], Is.EqualTo(1.0 / 62).Within(1e-12));
        Assert.That(scored["c"], Is.EqualTo((1.0 / 63) + (0.25 / 61)).Within(1e-12));
        Assert.That(scored["d"], Is.EqualTo(0.25 / 63).Within(1e-12));
        Assert.That(scored["a"], Is.EqualTo(0.0204257).Within(1e-7), "the value written out by hand: 0.016393 + 0.004032");
    }

    [Test]
    public void A_lecture_in_both_lists_keeps_the_first_lists_hit()
    {
        var fused = ReciprocalRank.Fuse([(new[] { Lecture("a", score: 7.5) }, 1.0), (new[] { Lecture("a", score: 0.9) }, 0.25)]);

        Assert.That(fused, Has.Count.EqualTo(1));
        Assert.That(fused[0].Score, Is.EqualTo(7.5));
    }

    [Test]
    public void Equal_scores_keep_the_order_in_which_the_lectures_were_first_met()
    {
        var fused = ReciprocalRank.Fuse([(new[] { Lecture("x"), Lecture("y") }, 0.5), (new[] { Lecture("z") }, 0.5)]);

        // x and z both score 0.5/61; x was met first, then y (0.5/62 is lower), z ties with x and comes after it.
        Assert.That(fused.Select(l => l.Slug), Is.EqualTo((string[])["x", "z", "y"]));
    }

    [Test]
    public void No_lists_or_empty_lists_give_nothing()
    {
        Assert.That(ReciprocalRank.Fuse([]), Is.Empty);
        Assert.That(ReciprocalRank.Fuse([(Array.Empty<LectureResult>(), 1.0)]), Is.Empty);
    }

    [Test]
    public void A_weight_of_zero_adds_the_lecture_but_does_not_lift_it()
    {
        var fused = ReciprocalRank.Fuse([(new[] { Lecture("a") }, 1.0), (new[] { Lecture("b"), Lecture("a") }, 0.0)]);

        Assert.That(fused.Select(l => l.Slug), Is.EqualTo((string[])["a", "b"]));
    }
}
