namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// What the due decision reads of an active scheduled notification. <c>Slot</c> is the class schedule slot a REMINDER points at, null when it is absent, deleted or belongs to another class.
/// <c>Tz</c> is the row's own zone name; <c>LastRunKey</c> is the occurrence last sent or recorded as missed.
/// </summary>
internal sealed record DueInput(string Kind, DateTime? SendAt, string Tz, string? Weekdays, TimeOnly? SendTime, int? OffsetMinutes, SlotRef? Slot, string? LastRunKey, DateTimeOffset CreatedAt);

/// <summary>An occurrence of a scheduled notification: its key (<c>once:</c>, <c>week:</c> or <c>rem:</c> and the Unix seconds of the slot), the slot and whether a ONCE row found it past its grace.</summary>
internal sealed record DueSlot(string Key, DateTimeOffset Slot, bool Late);

/// <summary>
/// PHP's <c>ClassScheduledNotificationsModel::dueFor</c>, <c>lapsedFor</c> and <c>zoneProblem</c>. Pure: the caller passes the clock. A wall clock is read in the row's own zone each time
/// (a REMINDER in its slot's zone), so a daylight saving change keeps the chosen wall-clock time; there is no default zone.
/// </summary>
internal static class ScheduleDue
{
    /// <summary>A slot the worker was not running for is still fired if it is this fresh.</summary>
    public const int GraceSeconds = 7200;

    /// <summary>Why the row cannot be timed (<c>schedule_timezone_invalid</c> for a REMINDER's slot, <c>timezone_invalid</c> for the others), or null when its zone is fine.</summary>
    public static string? ZoneProblem(DueInput row)
    {
        ArgumentNullException.ThrowIfNull(row);
        if (row.Kind == "REMINDER")
        {
            return WallClock.Zone(row.Slot?.Timezone) is null ? "schedule_timezone_invalid" : null;
        }

        return WallClock.Zone(row.Tz) is null ? "timezone_invalid" : null;
    }

    /// <summary>The occurrence due now, or null. <c>Late</c> marks a ONCE row found past its grace: it is finished as missed, never sent stale.</summary>
    public static DueSlot? DueFor(DueInput row, DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(row);
        return row.Kind switch
        {
            "ONCE" => OnceDue(row, now),
            "WEEKLY" => WeeklyDue(row, now, GraceSeconds),
            "REMINDER" => ReminderDue(row, now, GraceSeconds),
            _ => null,
        };
    }

    /// <summary>
    /// The latest WEEKLY or REMINDER occurrence that is past its grace and was neither sent nor recorded as missed, or null. An occurrence from before the row was created is not its to miss.
    /// ONCE is not handled here: a late ONCE is found by <see cref="DueFor"/>.
    /// </summary>
    public static DueSlot? LapsedFor(DueInput row, DateTimeOffset now)
    {
        ArgumentNullException.ThrowIfNull(row);
        var latest = row.Kind switch
        {
            "WEEKLY" => WeeklyDue(row, now, long.MaxValue),
            "REMINDER" => ReminderDue(row, now, long.MaxValue),
            _ => null,
        };
        if (latest is null || (now - latest.Slot).TotalSeconds <= GraceSeconds)
        {
            return null;
        }

        if (row.LastRunKey == latest.Key || latest.Slot < row.CreatedAt)
        {
            return null;
        }

        return latest;
    }

    private static string KeyOf(string prefix, DateTimeOffset slot) =>
        prefix + slot.ToUnixTimeSeconds().ToString(System.Globalization.CultureInfo.InvariantCulture);

    private static DueSlot? OnceDue(DueInput row, DateTimeOffset now)
    {
        var zone = WallClock.Zone(row.Tz);
        if (row.SendAt is null || zone is null)
        {
            return null;
        }

        var slot = WallClock.At(row.SendAt.Value, zone);
        return slot > now ? null : new DueSlot(KeyOf("once:", slot), slot, (now - slot).TotalSeconds > GraceSeconds);
    }

    private static DueSlot? WeeklyDue(DueInput row, DateTimeOffset now, long grace)
    {
        var zone = WallClock.Zone(row.Tz);
        var weekdays = ScheduleNextRun.Weekdays(row.Weekdays);
        if (zone is null || row.SendTime is null || weekdays.Count == 0)
        {
            return null;
        }

        DateTimeOffset? best = null;
        foreach (var weekday in weekdays)
        {
            var slot = ScheduleNextRun.LatestSlot(weekday, row.SendTime.Value.Hour, row.SendTime.Value.Minute, zone, now);
            if ((now - slot).TotalSeconds > grace)
            {
                continue;
            }

            if (best is null || slot > best)
            {
                best = slot;
            }
        }

        return best is null ? null : new DueSlot(KeyOf("week:", best.Value), best.Value, false);
    }

    // The offset is applied before looking for the latest occurrence: this week's class and next week's, because with a negative offset the next reminder can already be past while the class is still ahead.
    private static DueSlot? ReminderDue(DueInput row, DateTimeOffset now, long grace)
    {
        var zone = row.Slot is null ? null : WallClock.Zone(row.Slot.Timezone);
        if (row.Slot is null || zone is null)
        {
            return null;
        }

        var baseSlot = ScheduleNextRun.LatestSlot(row.Slot.Day, row.Slot.Hour, row.Slot.Minute, zone, now);
        var offset = row.OffsetMinutes ?? 0;
        DateTimeOffset? best = null;
        foreach (var candidate in new[] { baseSlot, WallClock.AddDays(baseSlot, 7, zone) })
        {
            var shifted = candidate.AddMinutes(offset);
            if (shifted > now || (now - shifted).TotalSeconds > grace)
            {
                continue;
            }

            if (best is null || shifted > best)
            {
                best = shifted;
            }
        }

        return best is null ? null : new DueSlot(KeyOf("rem:", best.Value), best.Value, false);
    }
}
