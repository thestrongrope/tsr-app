using Tsr.Platform.Api.Domain;
using Xunit;

namespace Tsr.Platform.Api.Tests.Domain;

public sealed class FeedbackTextTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Empty_text_is_refused(string? raw)
    {
        var result = FeedbackText.Create(raw);

        Assert.False(result.IsSuccess);
        Assert.Equal("text is required", result.Error);
    }

    [Fact]
    public void Text_is_trimmed()
    {
        var result = FeedbackText.Create("  shukran  ");

        Assert.True(result.IsSuccess);
        Assert.Equal("shukran", result.Value!.Value);
    }

    [Fact]
    public void Exactly_the_limit_is_accepted()
    {
        var result = FeedbackText.Create(new string('a', FeedbackText.MaxLength));

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public void One_over_the_limit_is_refused()
    {
        var result = FeedbackText.Create(new string('a', FeedbackText.MaxLength + 1));

        Assert.False(result.IsSuccess);
    }

    [Fact]
    public void Arabic_marks_count_as_code_points_like_php()
    {
        // "بِسْمِ" is 6 code points (3 letters, 3 marks). PHP's mb_strlen counts 6, so must we:
        // 334 words = 2004 code points, over the limit in both implementations.
        var word = "بِسْمِ";
        var result = FeedbackText.Create(string.Concat(Enumerable.Repeat(word, 334)));

        Assert.False(result.IsSuccess);
    }

    [Fact]
    public void An_emoji_counts_once()
    {
        // One code point, two UTF-16 code units: mb_strlen counts 1.
        var result = FeedbackText.Create(string.Concat(Enumerable.Repeat("\U0001F600", FeedbackText.MaxLength)));

        Assert.True(result.IsSuccess);
    }
}
