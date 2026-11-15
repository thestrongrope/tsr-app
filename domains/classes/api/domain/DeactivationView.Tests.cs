using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class DeactivationViewTests
{
    private static DeactivationView.ClosedClass Closed(
        string? details = null,
        DateOnly? completedOn = null,
        DateOnly? shutdownOn = null,
        string? comments = null,
        int? deletedBy = null,
        string? performer = null,
        string? deleter = null) =>
        new(1, "C1", "L", 1, "T", details, completedOn, shutdownOn, comments, deletedBy, new DateTime(2025, 8, 2, 9, 0, 0, DateTimeKind.Utc), performer, deleter, null);

    [Test]
    public void The_audit_details_win_over_the_class_columns()
    {
        var s = DeactivationView.Summarise(Closed("""{"type": "shutdown", "effective_date": "2025-10-05", "reason": "r"}""", new DateOnly(2025, 1, 1), null, "c"));
        Assert.That((s.Type, s.EffectiveDate, s.Reason), Is.EqualTo(("shutdown", "2025-10-05", "r")));
    }

    [TestCase("""{"type": ""}""")]
    [TestCase("""{"type": "0"}""")]
    [TestCase("""{"type": null}""")]
    [TestCase("""{}""")]
    [TestCase("not json")]
    [TestCase("")]
    [TestCase("0")]
    [TestCase(null)]
    public void A_missing_or_falsy_type_falls_back_to_completed_then_shutdown(string? details)
    {
        Assert.That(DeactivationView.Summarise(Closed(details, new DateOnly(2025, 8, 1))).Type, Is.EqualTo("completed"));
        Assert.That(DeactivationView.Summarise(Closed(details, null, new DateOnly(2025, 8, 1))).Type, Is.EqualTo("shutdown"));
        Assert.That(DeactivationView.Summarise(Closed(details)).Type, Is.EqualTo(string.Empty));
    }

    [Test]
    public void The_effective_date_falls_back_only_when_the_details_have_none()
    {
        Assert.That(DeactivationView.Summarise(Closed("""{"type": "x"}""", new DateOnly(2025, 8, 1), new DateOnly(2025, 9, 1))).EffectiveDate, Is.EqualTo("2025-08-01"));
        Assert.That(DeactivationView.Summarise(Closed(null, null, new DateOnly(2025, 9, 1))).EffectiveDate, Is.EqualTo("2025-09-01"));
        Assert.That(DeactivationView.Summarise(Closed("""{"effective_date": ""}""", new DateOnly(2025, 8, 1))).EffectiveDate, Is.EqualTo(string.Empty));
        Assert.That(DeactivationView.Summarise(Closed()).EffectiveDate, Is.EqualTo(string.Empty));
    }

    [Test]
    public void The_reason_falls_back_to_the_comment_only_when_the_details_have_no_reason_key()
    {
        Assert.That(DeactivationView.Summarise(Closed("""{"type": "x"}""", comments: "c")).Reason, Is.EqualTo("c"));
        Assert.That(DeactivationView.Summarise(Closed("""{"reason": null}""", comments: "c")).Reason, Is.EqualTo("c"));
        Assert.That(DeactivationView.Summarise(Closed("""{"reason": ""}""", comments: "c")).Reason, Is.EqualTo(string.Empty));
        Assert.That(DeactivationView.Summarise(Closed()).Reason, Is.EqualTo(string.Empty));
    }

    [Test]
    public void The_performer_is_the_audit_name_then_the_deleters_name_then_the_deleters_token()
    {
        Assert.That(DeactivationView.Summarise(Closed(performer: "P", deleter: "D", deletedBy: 7)).PerformedBy, Is.EqualTo("P"));
        Assert.That(DeactivationView.Summarise(Closed(deleter: "D", deletedBy: 7)).PerformedBy, Is.EqualTo("D"));
        Assert.That(DeactivationView.Summarise(Closed(deletedBy: 7)).PerformedBy, Is.EqualTo("#7"));
        Assert.That(DeactivationView.Summarise(Closed(performer: "", deletedBy: 7)).PerformedBy, Is.EqualTo("#7"));
        Assert.That(DeactivationView.Summarise(Closed(performer: "0", deleter: "D", deletedBy: 7)).PerformedBy, Is.EqualTo("#7"));
        Assert.That(DeactivationView.Summarise(Closed()).PerformedBy, Is.EqualTo(string.Empty));
    }

    [Test]
    public void The_time_is_the_audit_time_else_the_deletion_time_in_UTC_with_a_Z()
    {
        var audited = Closed() with { PerformedAt = new DateTime(2025, 10, 5, 12, 0, 0, DateTimeKind.Utc) };
        Assert.That(DeactivationView.Summarise(audited).PerformedAt, Is.EqualTo("2025-10-05T12:00:00Z"));
        Assert.That(DeactivationView.Summarise(Closed()).PerformedAt, Is.EqualTo("2025-08-02T09:00:00Z"));
        Assert.That(DeactivationView.Summarise(Closed() with { DeletedAt = null }).PerformedAt, Is.Null);
    }

    [Test]
    public void A_log_row_reads_its_details_and_names_a_missing_class_and_performer_by_id()
    {
        var entry = DeactivationView.LogOf(new DeactivationView.LogRow(5, 9, null, null, null, """{"type": "completed", "effective_date": "2025-09-15"}""", 3, null, new DateTime(2025, 9, 15, 10, 0, 0, DateTimeKind.Utc)));
        Assert.That((entry.Code, entry.Level, entry.Gender, entry.Type, entry.EffectiveDate, entry.Reason, entry.PerformedBy, entry.PerformedAt),
            Is.EqualTo(("#9", string.Empty, 0, "completed", "2025-09-15", string.Empty, "#3", "2025-09-15T10:00:00Z")));
    }
}
