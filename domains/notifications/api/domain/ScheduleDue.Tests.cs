using NUnit.Framework;

namespace Tsr.Notifications.Api.Domain;

public sealed class ScheduleDueTests
{
    private static readonly DateTimeOffset Created = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    private static DueInput Once(string wall, string tz = "UTC") =>
        new("ONCE", DateTime.Parse(wall, System.Globalization.CultureInfo.InvariantCulture), tz, null, null, null, null, null, Created);

    private static DueInput Weekly(string days, string time, string tz = "UTC", string? lastKey = null) =>
        new("WEEKLY", null, tz, days, TimeOnly.Parse(time, System.Globalization.CultureInfo.InvariantCulture), null, null, lastKey, Created);

    private static DueInput Reminder(SlotRef? slot, int offset, string tz = "UTC", string? lastKey = null) =>
        new("REMINDER", null, tz, null, null, offset, slot, lastKey, Created);

    private static DateTimeOffset Utc(int month, int day, int hour, int minute) => new(2026, month, day, hour, minute, 0, TimeSpan.Zero);

    [Test]
    public void Once_is_not_due_before_its_wall_clock_in_its_own_zone()
    {
        // 10:00 in Asia/Kolkata (UTC+5:30) is 04:30 UTC.
        Assert.That(ScheduleDue.DueFor(Once("2026-11-12T10:00:00", "Asia/Kolkata"), Utc(11, 12, 4, 29)), Is.Null);
        var due = ScheduleDue.DueFor(Once("2026-11-12T10:00:00", "Asia/Kolkata"), Utc(11, 12, 4, 30));
        Assert.That(due!.Slot.UtcDateTime, Is.EqualTo(new DateTime(2026, 11, 12, 4, 30, 0, DateTimeKind.Utc)));
        Assert.That(due.Key, Is.EqualTo("once:" + Utc(11, 12, 4, 30).ToUnixTimeSeconds()));
        Assert.That(due.Late, Is.False);
    }

    [Test]
    public void Once_is_late_only_after_the_grace_window()
    {
        Assert.That(ScheduleDue.DueFor(Once("2026-11-12T10:00:00"), Utc(11, 12, 12, 0))!.Late, Is.False, "exactly 7200 s is still inside");
        Assert.That(ScheduleDue.DueFor(Once("2026-11-12T10:00:00"), Utc(11, 12, 12, 1))!.Late, Is.True);
    }

    [Test]
    public void Once_in_a_new_york_wall_clock_the_clocks_skip_lands_forward()
    {
        var due = ScheduleDue.DueFor(Once("2026-03-08T02:30:00", "America/New_York"), Utc(3, 8, 7, 30));
        Assert.That(due!.Slot.UtcDateTime, Is.EqualTo(new DateTime(2026, 3, 8, 7, 30, 0, DateTimeKind.Utc)));
    }

    [Test]
    public void Weekly_keeps_its_wall_clock_time_across_a_daylight_saving_change()
    {
        // Sunday 2026-03-08 the clocks in New York go forward at 02:00. A Saturday 09:00 slot is 14:00 UTC before, a Sunday 09:00 slot is 13:00 UTC after.
        var sunday = ScheduleDue.DueFor(Weekly("7", "09:00", "America/New_York"), Utc(3, 8, 13, 5));
        Assert.That(sunday!.Slot.UtcDateTime, Is.EqualTo(new DateTime(2026, 3, 8, 13, 0, 0, DateTimeKind.Utc)));
        var saturday = ScheduleDue.DueFor(Weekly("6", "09:00", "America/New_York"), Utc(3, 7, 14, 5));
        Assert.That(saturday!.Slot.UtcDateTime, Is.EqualTo(new DateTime(2026, 3, 7, 14, 0, 0, DateTimeKind.Utc)));
        Assert.That(saturday.Key, Does.StartWith("week:"));
    }

    [Test]
    public void Weekly_is_not_due_outside_its_grace_and_picks_the_latest_listed_weekday()
    {
        // Thursday 2026-11-12. Wednesday 09:00 is a day old: not due. Thursday 09:00 is due at 09:30.
        Assert.That(ScheduleDue.DueFor(Weekly("3", "09:00"), Utc(11, 12, 9, 30)), Is.Null);
        var due = ScheduleDue.DueFor(Weekly("3,4", "09:00"), Utc(11, 12, 9, 30));
        Assert.That(due!.Slot, Is.EqualTo(Utc(11, 12, 9, 0)));
        Assert.That(ScheduleDue.DueFor(Weekly("4", "09:00"), Utc(11, 12, 11, 1)), Is.Null);
    }

    [Test]
    public void Reminder_follows_the_class_slot_and_its_offset()
    {
        // The class meets Thursday (4) 18:00 UTC; the reminder is 30 minutes before.
        var row = Reminder(new SlotRef(4, 18, 0, "UTC"), -30);
        Assert.That(ScheduleDue.DueFor(row, Utc(11, 12, 17, 29)), Is.Null);
        var due = ScheduleDue.DueFor(row, Utc(11, 12, 17, 31));
        Assert.That(due!.Slot, Is.EqualTo(Utc(11, 12, 17, 30)));
        Assert.That(due.Key, Is.EqualTo("rem:" + Utc(11, 12, 17, 30).ToUnixTimeSeconds()));
    }

    [Test]
    public void A_negative_offset_reminder_for_next_weeks_class_is_found_while_this_weeks_class_is_still_ahead()
    {
        // Class Friday (5) 00:10 UTC, reminder 20 minutes before = Thursday 23:50. At Thursday 23:55 the latest class slot is last Friday.
        var row = Reminder(new SlotRef(5, 0, 10, "UTC"), -20);
        var due = ScheduleDue.DueFor(row, Utc(11, 12, 23, 55));
        Assert.That(due!.Slot, Is.EqualTo(Utc(11, 12, 23, 50)));
    }

    [Test]
    public void A_zone_that_does_not_exist_is_a_problem_and_never_due()
    {
        Assert.That(ScheduleDue.ZoneProblem(Once("2026-11-12T10:00:00", "Not/AZone")), Is.EqualTo("timezone_invalid"));
        Assert.That(ScheduleDue.ZoneProblem(Weekly("4", "09:00", "")), Is.EqualTo("timezone_invalid"));
        Assert.That(ScheduleDue.ZoneProblem(Reminder(new SlotRef(4, 18, 0, "Not/AZone"), 0)), Is.EqualTo("schedule_timezone_invalid"));
        Assert.That(ScheduleDue.ZoneProblem(Reminder(new SlotRef(4, 18, 0, "UTC"), 0, "Not/AZone")), Is.Null, "a reminder is timed in its slot's zone");
        Assert.That(ScheduleDue.ZoneProblem(Once("2026-11-12T10:00:00")), Is.Null);
        Assert.That(ScheduleDue.DueFor(Once("2026-11-12T10:00:00", "Not/AZone"), Utc(11, 13, 0, 0)), Is.Null);
        Assert.That(ScheduleDue.DueFor(Weekly("4", "09:00", "Not/AZone"), Utc(11, 12, 9, 30)), Is.Null);
    }

    [Test]
    public void A_weekly_or_reminder_occurrence_past_its_grace_and_unsent_has_lapsed()
    {
        var weekly = Weekly("4", "09:00");
        Assert.That(ScheduleDue.LapsedFor(weekly, Utc(11, 12, 11, 0)), Is.Null, "still inside the grace");
        var lapsed = ScheduleDue.LapsedFor(weekly, Utc(11, 12, 11, 1));
        Assert.That(lapsed!.Slot, Is.EqualTo(Utc(11, 12, 9, 0)));
        Assert.That(ScheduleDue.LapsedFor(Weekly("4", "09:00", lastKey: lapsed.Key), Utc(11, 12, 11, 1)), Is.Null, "already sent or recorded");
        Assert.That(ScheduleDue.LapsedFor(Reminder(new SlotRef(4, 18, 0, "UTC"), 0), Utc(11, 12, 20, 1))!.Key, Does.StartWith("rem:"));
    }

    [Test]
    public void An_occurrence_from_before_the_row_was_created_is_not_its_to_miss_and_once_never_lapses()
    {
        var created = Utc(11, 12, 10, 0);
        var row = Weekly("4", "09:00") with { CreatedAt = created };
        Assert.That(ScheduleDue.LapsedFor(row, Utc(11, 12, 12, 0)), Is.Null);
        Assert.That(ScheduleDue.LapsedFor(Once("2026-11-12T10:00:00"), Utc(11, 13, 0, 0)), Is.Null);
    }
}
