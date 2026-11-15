using NUnit.Framework;

namespace Tsr.Shared.Api;

[TestFixture]
internal sealed class PhpDateBoundTests
{
    [TestCase("2025-10-05", "2025-10-05T00:00:00")]
    [TestCase("2025-1-5", "2025-01-05T00:00:00")]
    [TestCase("2025/10/05", "2025-10-05T00:00:00")]
    [TestCase("20251005", "2025-10-05T00:00:00")]
    [TestCase(" 2025-10-05 ", "2025-10-05T00:00:00")]
    [TestCase("2025-10-05 13:14:15", "2025-10-05T13:14:15")]
    [TestCase("2025-10-05T13:14:15", "2025-10-05T13:14:15")]
    [TestCase("2025-10-05 13:14:15.987", "2025-10-05T13:14:15")]
    [TestCase("2025-10-05 7:4:9", "2025-10-05T07:04:09")]
    public void A_readable_date_is_a_point_in_time_a_bare_date_is_its_midnight(string raw, string expected) =>
        Assert.That(PhpDateBound.Bound(raw), Is.EqualTo(DateTime.SpecifyKind(DateTime.Parse(expected, System.Globalization.CultureInfo.InvariantCulture), DateTimeKind.Utc)));

    [TestCase(null)]
    [TestCase("٢٠٢٥-١-٥", Description = "digits of another script: not a date, and never an exception")]
    [TestCase("")]
    [TestCase("   ")]
    [TestCase("yesterday")]
    [TestCase("2025-13-01")]
    [TestCase("2025-02-30")]
    [TestCase("2025-10-05 24:00:00")]
    [TestCase("2025-10-05 12:61:00")]
    [TestCase("2025-10-05\0")]
    [TestCase("\02025-10-05")]
    [TestCase("0000-00-00")]
    public void Text_that_is_not_a_real_date_is_ignored(string? raw) =>
        Assert.That(PhpDateBound.Bound(raw), Is.Null);
}
