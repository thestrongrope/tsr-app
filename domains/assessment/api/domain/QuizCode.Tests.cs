using NUnit.Framework;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class QuizCodeTests
{
    [Test]
    public void A_code_is_eight_characters_of_digits_and_upper_case_letters()
    {
        for (var i = 0; i < 500; i++)
        {
            var code = QuizCode.Generate();
            Assert.That(code, Has.Length.EqualTo(8));
            Assert.That(code.All(c => c is (>= '0' and <= '9') or (>= 'A' and <= 'Z')), Is.True, code);
        }
    }

    [Test]
    public void Codes_are_not_repeated_in_a_run()
    {
        var codes = Enumerable.Range(0, 500).Select(_ => QuizCode.Generate()).ToHashSet();
        Assert.That(codes, Has.Count.EqualTo(500));
    }
}
