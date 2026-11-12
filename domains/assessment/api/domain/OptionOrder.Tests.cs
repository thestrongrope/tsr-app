using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class OptionOrderTests
{
    private sealed class Fixed(params int[] draws) : IQuizRandom
    {
        private int _next;

        public int Next(int maxExclusive) => draws[_next++] % maxExclusive;
    }

    [Test]
    public void A_new_order_holds_the_numbers_of_the_filled_options_one_to_four()
    {
        var order = OptionOrder.NewOrder(["a", "", null, "d"], new Fixed(0));
        Assert.That(order.Split(',').Order(), Is.EqualTo(new List<string> { "1", "4" }));
    }

    [Test]
    public void Zero_text_and_missing_options_count_as_empty_when_filling()
    {
        Assert.That(OptionOrder.NewOrder(["0", "x", "0", null], new Fixed(0)), Is.EqualTo("2"));
        Assert.That(OptionOrder.NewOrder(["", null, null, null], new Fixed()), Is.EqualTo(string.Empty));
    }

    [Test]
    public void The_shuffle_uses_the_draws()
    {
        Assert.That(OptionOrder.NewOrder(["a", "b", "c", "d"], new Fixed(0, 0, 0)), Is.EqualTo("2,3,4,1"));
    }

    [Test]
    public void A_stored_order_is_followed_and_option_one_is_the_correct_one()
    {
        var shown = OptionOrder.Ordered("3,1,2", ["right", "w1", "w2", null, null]);
        Assert.That(shown.Select(s => s.Text), Is.EqualTo(new List<string> { "w2", "right", "w1" }));
        Assert.That(shown.Select(s => s.IsCorrect), Is.EqualTo(new List<bool> { false, true, false }));
    }

    [Test]
    public void Numbers_outside_one_to_five_and_empty_options_are_left_out()
    {
        var shown = OptionOrder.Ordered("9,4,2, 1,x", ["right", "w1", null, null, null]);
        Assert.That(shown.Select(s => s.Text), Is.EqualTo(new List<string> { "w1", "right" }));
    }

    [Test]
    public void With_no_usable_order_the_natural_order_shows_options_one_to_five_with_zero_text()
    {
        var shown = OptionOrder.Ordered(null, ["a", "0", null, "d", "e"]);
        Assert.That(shown.Select(s => s.Text), Is.EqualTo(new List<string> { "a", "0", "d", "e" }));
        Assert.That(OptionOrder.Ordered(string.Empty, ["a", null, null, null, null]), Has.Count.EqualTo(1));
    }
}
