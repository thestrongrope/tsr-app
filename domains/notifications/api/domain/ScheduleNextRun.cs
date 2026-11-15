namespace Tsr.Notifications.Api.Domain;

/// <summary>A class schedule slot a reminder is timed from: ISO weekday, hour, minute and the slot's own zone.</summary>
internal sealed record SlotRef(int Day, int Hour, int Minute, string Timezone);

/// <summary>What the next-run rule reads of a scheduled notification. <c>Slot</c> is null for a deleted or absent slot.</summary>
internal sealed record NextRunInput(string Status, string Kind, DateTime? SendAt, string? Tz, string? Weekdays, TimeOnly? SendTime, int? OffsetMinutes, SlotRef? Slot);

/// <summary>
/// PHP's <c>ClassScheduledNotificationsModel::nextRun</c> and <c>ReminderScheduleModel::latestSlot</c>: when a scheduled notification fires next, or null (done, or nothing sensible).
/// Pure: the caller passes the clock.
/// </summary>
internal static class ScheduleNextRun
{
    private const int ReminderWeeksAhead = 4;

    public static DateTimeOffset? Of(NextRunInput row, DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(row);
        if (row.Status != "active")
        {
            return null;
        }

        return row.Kind switch
        {
            "ONCE" => Once(row, now),
            "WEEKLY" => Weekly(row, now),
            "REMINDER" => Reminder(row, now),
            _ => null,
        };
    }

    /// <summary>The ISO weekdays (1 to 7) of a comma separated list, each once, in first-seen order; anything else is skipped.</summary>
    public static IReadOnlyList<int> Weekdays(string? value)
    {
        var days = new List<int>();
        foreach (var part in (value ?? string.Empty).Split(','))
        {
            var day = (int)Math.Clamp(PhpValue.IntOfText(part), -1, 9);
            if (day is >= 1 and <= 7 && !days.Contains(day))
            {
                days.Add(day);
            }
        }

        return days;
    }

    /// <summary>The most recent moment at or before <paramref name="now"/> that is this weekday and time in the zone.</summary>
    public static DateTimeOffset LatestSlot(int weekday, int hour, int minute, TimeZoneInfo zone, DateTimeOffset now)
    {
        var local = WallClock.Local(now, zone);
        var isoToday = local.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)local.DayOfWeek;
        var daysBack = (isoToday - weekday + 7) % 7;
        var wall = local.Date.AddDays(-daysBack).AddHours(hour).AddMinutes(minute);
        var slot = WallClock.At(wall, zone);
        return slot > now ? WallClock.AddDays(slot, -7, zone) : slot;
    }

    private static DateTimeOffset? Once(NextRunInput row, DateTimeOffset now)
    {
        var zone = WallClock.Zone(row.Tz);
        if (row.SendAt is null || zone is null)
        {
            return null;
        }

        var moment = WallClock.At(row.SendAt.Value, zone);
        return moment > now ? moment : null;
    }

    private static DateTimeOffset? Weekly(NextRunInput row, DateTimeOffset now)
    {
        var zone = WallClock.Zone(row.Tz);
        if (zone is null || row.SendTime is null)
        {
            return null;
        }

        DateTimeOffset? next = null;
        foreach (var weekday in Weekdays(row.Weekdays))
        {
            var slot = LatestSlot(weekday, row.SendTime.Value.Hour, row.SendTime.Value.Minute, zone, now);
            while (slot <= now)
            {
                slot = WallClock.AddDays(slot, 7, zone);
            }

            if (next is null || slot < next)
            {
                next = slot;
            }
        }

        return next;
    }

    private static DateTimeOffset? Reminder(NextRunInput row, DateTimeOffset now)
    {
        var zone = row.Slot is null ? null : WallClock.Zone(row.Slot.Timezone);
        if (row.Slot is null || zone is null)
        {
            return null;
        }

        var baseSlot = LatestSlot(row.Slot.Day, row.Slot.Hour, row.Slot.Minute, zone, now);
        var offset = row.OffsetMinutes ?? 0;
        for (var week = 0; week <= ReminderWeeksAhead; week++)
        {
            var shifted = WallClock.AddDays(baseSlot, week * 7, zone).AddMinutes(offset);
            if (shifted > now)
            {
                return TimeZoneInfo.ConvertTime(shifted, zone);
            }
        }

        return null;
    }
}
