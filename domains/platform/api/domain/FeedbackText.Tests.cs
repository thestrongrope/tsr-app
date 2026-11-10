using Tsr.Platform.Api.Domain;
using NUnit.Framework;

namespace Tsr.Platform.Api.Tests.Domain;

public sealed class FeedbackTextTests
{
    [TestCase(null)]
    [TestCase("")]
    [TestCase("   ")]
    public void Empty_text_is_refused(string? raw)
    {
        var result = FeedbackText.Create(raw);

        Assert.That(result.IsSuccess, Is.False);
        Assert.That(result.Error, Is.EqualTo("text is required"));
    }

    [Test]
    public void Text_is_trimmed()
    {
        var result = FeedbackText.Create("  shukran  ");

        Assert.That(result.IsSuccess, Is.True);
        Assert.That(result.Value!.Value, Is.EqualTo("shukran"));
    }

    [Test]
    public void Exactly_the_limit_is_accepted()
    {
        var result = FeedbackText.Create(new string('a', FeedbackText.MaxLength));

        Assert.That(result.IsSuccess, Is.True);
    }

    [Test]
    public void One_over_the_limit_is_refused()
    {
        var result = FeedbackText.Create(new string('a', FeedbackText.MaxLength + 1));

        Assert.That(result.IsSuccess, Is.False);
    }

    [Test]
    public void Arabic_marks_count_as_code_points_like_php()
    {
        // "بِسْمِ" is 6 code points (3 letters, 3 marks). PHP's mb_strlen counts 6, so must we:
        // 334 words = 2004 code points, over the limit in both implementations.
        var word = "بِسْمِ";
        var result = FeedbackText.Create(string.Concat(Enumerable.Repeat(word, 334)));

        Assert.That(result.IsSuccess, Is.False);
    }

    [Test]
    public void An_emoji_counts_once()
    {
        // One code point, two UTF-16 code units: mb_strlen counts 1.
        var result = FeedbackText.Create(string.Concat(Enumerable.Repeat("\U0001F600", FeedbackText.MaxLength)));

        Assert.That(result.IsSuccess, Is.True);
    }
}
