using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class DeactivationRulesTests
{
    [Test]
    public void A_valid_request_keeps_the_type_the_date_and_the_trimmed_reason()
    {
        var result = DeactivationRules.Parse("completed", "2026-02-28", "  Course finished  ");

        Assert.That(result.IsSuccess, Is.True);
        Assert.That(result.Value!.Type, Is.EqualTo("completed"));
        Assert.That(result.Value.EffectiveDate, Is.EqualTo(new DateOnly(2026, 2, 28)));
        Assert.That(result.Value.Reason, Is.EqualTo("Course finished"));
    }

    [TestCase("", "2026-01-01", "x", "Invalid type; expected completed or shutdown")]
    [TestCase("Completed", "2026-01-01", "x", "Invalid type; expected completed or shutdown")]
    [TestCase("closed", "", "x", "Invalid type; expected completed or shutdown")]
    [TestCase("shutdown", "", "x", "Invalid effective date; expected YYYY-MM-DD")]
    [TestCase("shutdown", "2026-02-30", "x", "Invalid effective date; expected YYYY-MM-DD")]
    [TestCase("shutdown", "2026-1-05", "x", "Invalid effective date; expected YYYY-MM-DD")]
    [TestCase("shutdown", "2026-01-05 ", "x", "Invalid effective date; expected YYYY-MM-DD")]
    [TestCase("shutdown", "05-01-2026", "x", "Invalid effective date; expected YYYY-MM-DD")]
    [TestCase("shutdown", "2026-01-05", "", "Reason is required")]
    [TestCase("shutdown", "2026-01-05", " \t\n ", "Reason is required")]
    public void A_bad_field_is_refused_with_PHPs_message_in_PHPs_order(string type, string date, string reason, string expected)
    {
        var result = DeactivationRules.Parse(type, date, reason);

        Assert.That(result.IsSuccess, Is.False);
        Assert.That(result.Error, Is.EqualTo(expected));
    }

    [Test]
    public void The_reason_limit_is_300_bytes_not_characters()
    {
        Assert.That(DeactivationRules.Parse("completed", "2026-01-05", new string('a', 300)).IsSuccess, Is.True);
        Assert.That(DeactivationRules.Parse("completed", "2026-01-05", new string('a', 301)).Error, Is.EqualTo("Reason must be 300 characters or fewer"));
        Assert.That(DeactivationRules.Parse("completed", "2026-01-05", new string('é', 150)).IsSuccess, Is.True, "150 two-byte letters are 300 bytes");
        Assert.That(DeactivationRules.Parse("completed", "2026-01-05", new string('é', 151)).Error, Is.EqualTo("Reason must be 300 characters or fewer"));
    }

    [Test]
    public void The_students_removal_reason_is_the_prefix_and_the_reason_cut_to_300_bytes_on_a_character_boundary()
    {
        Assert.That(DeactivationRules.StudentReason("Course finished"), Is.EqualTo("Class deactivated: Course finished"));

        var cut = DeactivationRules.StudentReason(new string('a', 300));
        Assert.That(cut, Has.Length.EqualTo(300));
        Assert.That(cut, Does.StartWith("Class deactivated: aaa"));

        var multi = DeactivationRules.StudentReason(new string('é', 150));
        Assert.That(System.Text.Encoding.UTF8.GetByteCount(multi), Is.LessThanOrEqualTo(300));
        Assert.That(multi, Does.EndWith("é"), "never a half character");
    }
}
