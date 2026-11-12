using NUnit.Framework;

namespace Tsr.Notifications.Api.Domain;

public sealed class ScheduleNextRunTests
{
    private static readonly DateTimeOffset Now = new(2026, 11, 12, 10, 0, 0, TimeSpan.Zero); // a Thursday

    [Test]
    public void A_wall_time_the_clocks_skip_lands_forward_on_the_same_offset()
    {
        var zone = WallClock.Zone("America/New_York")!;
        var moment = WallClock.At(new DateTime(2026, 3, 8, 2, 30, 0), zone);
        Assert.That(moment.UtcDateTime, Is.EqualTo(new DateTime(2026, 3, 8, 7, 30, 0, DateTimeKind.Utc)));
        Assert.That(moment.Hour, Is.EqualTo(3));
    }

    [Test]
    public void A_wall_time_that_happens_twice_is_the_first()
    {
        var zone = WallClock.Zone("America/New_York")!;
        var moment = WallClock.At(new DateTime(2026, 11, 1, 1, 30, 0), zone);
        Assert.That(moment.UtcDateTime, Is.EqualTo(new DateTime(2026, 11, 1, 5, 30, 0, DateTimeKind.Utc)));
    }

    [TestCase("Not/AZone")]
    [TestCase("../etc/passwd")]
    [TestCase("")]
    public void An_unknown_zone_is_refused(string name) => Assert.That(WallClock.Zone(name), Is.Null);

    [Test]
    public void Weekly_fires_at_the_next_listed_weekday()
    {
        var row = new NextRunInput("active", "WEEKLY", null, "UTC", "1,5", new TimeOnly(18, 30), null, null);
        var next = ScheduleNextRun.Of(row, Now);
        Assert.That(next!.Value.UtcDateTime, Is.EqualTo(new DateTime(2026, 11, 13, 18, 30, 0, DateTimeKind.Utc)));
    }

    [Test]
    public void Weekly_today_before_its_time_fires_today()
    {
        var row = new NextRunInput("active", "WEEKLY", null, "UTC", "4", new TimeOnly(18, 30), null, null);
        Assert.That(ScheduleNextRun.Of(row, Now)!.Value.UtcDateTime, Is.EqualTo(new DateTime(2026, 11, 12, 18, 30, 0, DateTimeKind.Utc)));
    }

    [Test]
    public void Once_in_the_past_or_done_has_no_next_run()
    {
        var past = new NextRunInput("active", "ONCE", new DateTime(2026, 11, 1, 9, 0, 0), "UTC", null, null, null, null);
        var done = new NextRunInput("done", "ONCE", new DateTime(2026, 12, 1, 9, 0, 0), "UTC", null, null, null, null);
        Assert.That(ScheduleNextRun.Of(past, Now), Is.Null);
        Assert.That(ScheduleNextRun.Of(done, Now), Is.Null);
    }

    [Test]
    public void A_reminder_is_its_slot_shifted_by_the_offset()
    {
        var slot = new SlotRef(7, 9, 0, "UTC"); // Sunday 09:00, latest is 8 Nov, next 15 Nov
        var row = new NextRunInput("active", "REMINDER", null, "UTC", null, null, -60, slot);
        Assert.That(ScheduleNextRun.Of(row, Now)!.Value.UtcDateTime, Is.EqualTo(new DateTime(2026, 11, 15, 8, 0, 0, DateTimeKind.Utc)));
    }

    [Test]
    public void A_reminder_without_a_live_slot_has_no_next_run() =>
        Assert.That(ScheduleNextRun.Of(new NextRunInput("active", "REMINDER", null, "UTC", null, null, 0, null), Now), Is.Null);

    [TestCase("1,3,,9,x,3", "1,3")]
    public void Weekdays_keep_only_valid_days_once(string value, string expected) =>
        Assert.That(string.Join(",", ScheduleNextRun.Weekdays(value)), Is.EqualTo(expected));
}
