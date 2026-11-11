using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class PhpFloatTests
{
    [TestCase(100.0, "100.0")]
    [TestCase(0.0, "0.0")]
    [TestCase(66.7, "66.7")]
    public void A_float_is_written_as_PHP_writes_it(double value, string expected) =>
        Assert.That(JsonSerializer.Serialize(new PhpFloat(value)), Is.EqualTo(expected));

    [TestCase(2, 3, 1, "66.7")]
    [TestCase(1, 8, 2, "12.5")]
    [TestCase(1, 8, 1, "12.5")]
    [TestCase(1, 16, 2, "6.25")]
    public void Round_goes_half_away_from_zero(int attended, int total, int places, string expected)
    {
        var percent = PhpFloat.Round(attended * 100m / total, places);

        Assert.That(JsonSerializer.Serialize(percent), Is.EqualTo(expected));
    }

    [Test]
    public void A_summary_with_no_sessions_has_no_percentage() =>
        Assert.That(StudentAttendance.Percent(new StudentAttendance.Summary(0, 0, 0), 1), Is.EqualTo(new PhpFloat(0)));

    [TestCase(1, false)]
    [TestCase(2, true)]
    [TestCase(5, true)]
    [TestCase(6, false)]
    public void A_level_has_a_guide_slug_only_from_2_to_5(int level, bool has) =>
        Assert.That(GuideSlugs.ForLevel(level) is not null, Is.EqualTo(has));
}
