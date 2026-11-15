using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class QuizRulesTests
{
    [TestCase("a", "a", true)]
    [TestCase("  A\t", "a", true)]
    [TestCase("A", " a\n", true)]
    [TestCase("\0a\v", "a", true)]
    [TestCase("a", "b", false)]
    [TestCase("a b", "a  b", false)]
    [TestCase(" a", "a", false)]
    [TestCase("1.0", "1", false)]
    [TestCase("01", "1", false)]
    [TestCase("1e2", "100", false)]
    [TestCase("&amp;", "&", false)]
    [TestCase("&amp;", "&AMP;", true)]
    [TestCase("نعم", "نعم", true)]
    [TestCase("نعم", "لا", false)]
    [TestCase("ÉCOLE", "école", true)]
    [TestCase("", "", false)]
    [TestCase("  ", "a", false)]
    [TestCase("a", "   ", false)]
    [TestCase(null, "a", false)]
    [TestCase("a", null, false)]
    [TestCase(null, null, false)]
    public void Scoring_trims_with_PHPs_set_ignores_case_and_nothing_else(string? selected, string? correct, bool expected) =>
        Assert.That(QuizRules.Score(selected, correct), Is.EqualTo(expected));

    [Test]
    public void The_correct_answer_is_the_option_the_answer_number_names()
    {
        string?[] options = ["one", "two", "three", null, "five"];

        Assert.That(QuizRules.CorrectAnswerFor(2, options), Is.EqualTo("two"));
        Assert.That(QuizRules.CorrectAnswerFor(5, options), Is.EqualTo("five"));
        Assert.That(QuizRules.CorrectAnswerFor(null, options), Is.EqualTo("one"), "PHP: a missing answer number is 1");
        Assert.That(QuizRules.CorrectAnswerFor(4, options), Is.Null, "the named option is empty");
        Assert.That(QuizRules.CorrectAnswerFor(0, options), Is.Null);
        Assert.That(QuizRules.CorrectAnswerFor(6, options), Is.Null);
        Assert.That(QuizRules.CorrectAnswerFor(-1, options), Is.Null);
    }

    [TestCase("A", true)]
    [TestCase("abc123XYZ", true)]
    [TestCase("", false)]
    [TestCase("abc-123", false)]
    [TestCase("abc def", false)]
    [TestCase("abcé", false)]
    [TestCase("abc\0", false)]
    [TestCase("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6", true)]
    [TestCase("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q", false)]
    public void A_link_code_is_one_to_32_ASCII_letters_and_digits(string code, bool expected) =>
        Assert.That(QuizRules.IsLinkCode(code), Is.EqualTo(expected));

    [Test]
    public void An_unknown_code_is_not_found_whoever_asks() =>
        Assert.That(QuizRules.Resolve(null, enrolled: true, attempted: true), Is.EqualTo(new QuizRules.LinkState("not_found", null)));

    [TestCase(true, false, false)]
    [TestCase(false, false, false)]
    [TestCase(true, true, true)]
    [TestCase(false, true, true)]
    public void A_member_who_is_not_enrolled_is_told_only_that(bool published, bool deactivated, bool attempted) =>
        Assert.That(QuizRules.Resolve(new QuizRules.LinkFacts(7, published, deactivated), enrolled: false, attempted), Is.EqualTo(new QuizRules.LinkState("not_eligible", null)));

    [TestCase(true, false)]
    [TestCase(false, true)]
    public void An_unpublished_quiz_is_not_released_even_when_deactivated_or_answered(bool deactivated, bool attempted) =>
        Assert.That(QuizRules.Resolve(new QuizRules.LinkFacts(7, false, deactivated), enrolled: true, attempted), Is.EqualTo(new QuizRules.LinkState("not_released", null)));

    [TestCase(false)]
    [TestCase(true)]
    public void An_answered_quiz_shows_the_result_even_when_deactivated(bool deactivated) =>
        Assert.That(QuizRules.Resolve(new QuizRules.LinkFacts(7, true, deactivated), enrolled: true, attempted: true), Is.EqualTo(new QuizRules.LinkState("attempted", 7)));

    [Test]
    public void A_released_live_quiz_not_yet_answered_is_open() =>
        Assert.That(QuizRules.Resolve(new QuizRules.LinkFacts(7, true, false), enrolled: true, attempted: false), Is.EqualTo(new QuizRules.LinkState("open", 7)));

    [Test]
    public void A_released_deactivated_quiz_not_yet_answered_is_closed_and_gives_no_id() =>
        Assert.That(QuizRules.Resolve(new QuizRules.LinkFacts(7, true, true), enrolled: true, attempted: false), Is.EqualTo(new QuizRules.LinkState("closed", null)));
}
