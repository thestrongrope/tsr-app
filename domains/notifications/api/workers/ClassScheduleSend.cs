using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Notifications.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api.Workers;

/// <summary>What one tick did, in rows: looked at, queued (<c>Fired</c>), held by a limit, ended with a reason, lapsed (an occurrence recorded as missed), failed (retried next tick).</summary>
internal sealed record ScheduleReport(int Looked, int Fired, int Held, int Ended, int Lapsed, int Failed);

/// <summary>The queued push of a scheduled notification, as the push drain reads it.</summary>
internal sealed record ScheduledPush(
    [property: JsonPropertyName("title")] string Title,
    [property: JsonPropertyName("body")] string Body,
    [property: JsonPropertyName("data")] Dictionary<string, string> Data,
    [property: JsonPropertyName("deadline")] string Deadline);

/// <summary>The audience criteria stored with the inbox notification of a scheduled occurrence; the text is how a retried occurrence finds its notification again.</summary>
internal sealed record ScheduledCriteria(
    [property: JsonPropertyName("type")] string Type,
    [property: JsonPropertyName("class_id")] int ClassId,
    [property: JsonPropertyName("source")] string Source,
    [property: JsonPropertyName("schedule_id")] int ScheduleId,
    [property: JsonPropertyName("slot_key")] string SlotKey);

/// <summary>
/// PHP <c>ClassScheduledNotificationWorker::run</c> as one tick (<c>cli/run_due_class_notifications.php</c>): read the active scheduled class notifications by id cursor (200 a page, 25 pages at most), decide per row
/// in its own time zone whether an occurrence is due (<see cref="ScheduleDue"/>), and send it. NOTHING IS SENT HERE: a due occurrence is queued for the push drain, one push per device of the class's current students
/// (demo members' devices left out), with the dedupe key <c>class-sched-&lt;id&gt;-&lt;slotkey&gt;</c> and a payload deadline of the slot plus 2 hours.
/// Order, so that a failure between steps recovers without a duplicate: (1) queue the pushes (a repeat adds nothing); (2) in ONE transaction, claim the occurrence (the conditional update is also the lock against a second
/// instance), write the inbox notification (found again by its criteria when one exists) and its fan-out, add the run row, and end a ONCE or one-off REMINDER row. A failure in step 2 rolls all of it back; the row stays active and the next tick
/// repeats it. An occurrence already claimed is skipped, so a WEEKLY row is not re-delivered every minute of its grace window (PHP does, and writes nothing new). A limit holds the occurrence, writing nothing, until it passes or its grace ends.
/// Logs hold counts, ids and exception type names only.
/// </summary>
internal static partial class ClassScheduleSend
{
    public const string Channel = "push";

    private enum Outcome
    {
        Quiet,
        Fired,
        Held,
        Ended,
        Lapsed,
        Failed,
    }

    public static async Task<ScheduleReport> TickAsync(NpgsqlDataSource source, Permissions permissions, TimeProvider clock, ILogger log, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(source);
        ArgumentNullException.ThrowIfNull(permissions);
        ArgumentNullException.ThrowIfNull(clock);
        ArgumentNullException.ThrowIfNull(log);
        var now = clock.GetUtcNow();
        var outcomes = new List<Outcome>();
        var afterId = 0;
        for (var page = 0; page < ClassScheduleLedger.MaxPages; page++)
        {
            var rows = await ClassScheduleLedger.PageAsync(source, now, afterId, ct);
            foreach (var row in rows)
            {
                outcomes.Add(await HandleSafelyAsync(source, permissions, row, now, log, ct));
            }

            if (rows.Count < ClassScheduleLedger.PageSize)
            {
                return Report(outcomes, log);
            }

            afterId = rows[^1].Id;
        }

        LogCapReached(log, ClassScheduleLedger.MaxPages);
        return Report(outcomes, log);
    }

    private static ScheduleReport Report(List<Outcome> outcomes, ILogger log)
    {
        int Count(Outcome outcome) => outcomes.Count(o => o == outcome);
        var report = new ScheduleReport(outcomes.Count, Count(Outcome.Fired), Count(Outcome.Held), Count(Outcome.Ended), Count(Outcome.Lapsed), Count(Outcome.Failed));
        if (report.Fired + report.Held + report.Ended + report.Lapsed + report.Failed > 0)
        {
            LogTicked(log, report.Looked, report.Fired, report.Held, report.Ended, report.Lapsed, report.Failed);
        }

        return report;
    }

    // One bad row must not stop the batch: it stays active, is retried next tick, and the ledger says why once.
    private static async Task<Outcome> HandleSafelyAsync(NpgsqlDataSource source, Permissions permissions, DueRow row, DateTimeOffset now, ILogger log, CancellationToken ct)
    {
        try
        {
            return await HandleAsync(source, permissions, row, now, log, ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            LogRowFailed(log, row.Id, e.GetType().Name);
            await RecordFailureAsync(source, row.Id, "dispatch_failed", now, log, ct);
            return Outcome.Failed;
        }
    }

    private static async Task RecordFailureAsync(NpgsqlDataSource source, int id, string reason, DateTimeOffset now, ILogger log, CancellationToken ct)
    {
        try
        {
            await ClassScheduleLedger.RecordFailureOnceAsync(source, id, reason, now, ct);
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            LogRecordFailed(log, id, reason, e.GetType().Name);
        }
    }

    private static async Task<Outcome> HandleAsync(NpgsqlDataSource source, Permissions permissions, DueRow row, DateTimeOffset now, ILogger log, CancellationToken ct)
    {
        var input = row.ToInput();
        if (row.Kind == "REMINDER" && input.Slot is null)
        {
            return await EndAsync(source, row, "schedule_missing", now, ct);
        }

        var zoneProblem = ScheduleDue.ZoneProblem(input);
        if (zoneProblem is not null)
        {
            return await EndAsync(source, row, zoneProblem, now, ct);
        }

        var due = ScheduleDue.DueFor(input, now);
        if (due is null)
        {
            return await LapseAsync(source, row, input, now, ct);
        }

        if (row.LastRunKey == due.Key)
        {
            return Outcome.Quiet;
        }

        if (due.Late)
        {
            return await EndAsync(source, row, "missed_window", now, ct);
        }

        return await SendOrEndAsync(source, permissions, row, due, now, log, ct);
    }

    private static async Task<Outcome> SendOrEndAsync(NpgsqlDataSource source, Permissions permissions, DueRow row, DueSlot due, DateTimeOffset now, ILogger log, CancellationToken ct)
    {
        if (!await ClassScheduleLedger.ClassIsActiveAsync(source, row.ClassId, ct))
        {
            return await EndAsync(source, row, "class_inactive", now, ct);
        }

        if (!await CreatorMaySendAsync(permissions, row, ct))
        {
            return await EndAsync(source, row, "creator_lost_permission", now, ct);
        }

        if (await ClassScheduleLedger.LimitReachedAsync(source, row, now, ct))
        {
            return Outcome.Held;
        }

        return await DeliverAsync(source, row, due, now, log, ct);
    }

    private static async Task<bool> CreatorMaySendAsync(Permissions permissions, DueRow row, CancellationToken ct) =>
        row.CreatedByUserId > 0 && await permissions.CanAsync(new Caller(row.CreatedByUserId, row.CreatedBy), "notifications:send", AccessTarget.ForClass(row.ClassId), ct);

    private static async Task<Outcome> EndAsync(NpgsqlDataSource source, DueRow row, string reason, DateTimeOffset now, CancellationToken ct) =>
        await ClassScheduleLedger.FinishAsync(source, row.Id, reason, now, ct) ? Outcome.Ended : Outcome.Quiet;

    // A WEEKLY or REMINDER occurrence that passed its grace unsent (held by a limit, or the worker was down) leaves one missed_window run; a one-off reminder is over.
    private static async Task<Outcome> LapseAsync(NpgsqlDataSource source, DueRow row, DueInput input, DateTimeOffset now, CancellationToken ct)
    {
        var lapsed = ScheduleDue.LapsedFor(input, now);
        if (lapsed is null)
        {
            return Outcome.Quiet;
        }

        var finished = row.Kind == "REMINDER" && row.RepeatWeekly == 0;
        return await ClassScheduleLedger.RecordMissedAsync(source, row.Id, lapsed.Key, finished, now, ct) ? Outcome.Lapsed : Outcome.Quiet;
    }

    private static async Task<Outcome> DeliverAsync(NpgsqlDataSource source, DueRow row, DueSlot due, DateTimeOffset now, ILogger log, CancellationToken ct)
    {
        var students = await Audience.ClassStudentsAsync(source, row.ClassId, ct);
        var devices = students.Count == 0 || Audience.TooLarge(students.Count) ? [] : await Audience.MemberDevicesAsync(source, [.. students], ct);
        if (Audience.TooLarge(students.Count) || Audience.TooLarge(devices.Count))
        {
            throw new InvalidOperationException("The audience of a scheduled notification is over the recipient limit");
        }

        if (devices.Count > 0 && !await QueueAsync(source, row, due, devices, now, log, ct))
        {
            return Outcome.Failed;
        }

        return await CompleteAsync(source, row, due, students, devices.Count, now, ct) ? Outcome.Fired : Outcome.Quiet;
    }

    // Step 1. One push row per device; the dedupe key makes a repeat (a retry, or a second instance) add nothing, so zero rows queued is not a failure. The queue command throws when it fails.
    private static async Task<bool> QueueAsync(NpgsqlDataSource source, DueRow row, DueSlot due, List<string> devices, DateTimeOffset now, ILogger log, CancellationToken ct)
    {
        try
        {
            await using var tx = await source.BeginAsync(ct);
            await PlatformCommands.QueueMessagesAsync(tx, Channel, devices, PushPayload(row, due), $"class-sched-{row.Id}-{due.Key}", row.CreatedBy, ct);
            await tx.CommitAsync(ct);
            return true;
        }
        catch (Exception e) when (e is not OperationCanceledException)
        {
            LogRowFailed(log, row.Id, e.GetType().Name);
            await RecordFailureAsync(source, row.Id, "queue_failed", now, log, ct);
            return false;
        }
    }

    private static string PushPayload(DueRow row, DueSlot due) =>
        JsonSerializer.Serialize(
            new ScheduledPush(
                row.Title,
                PushBatch.CutBody(row.Body),
                new Dictionary<string, string>
                {
                    ["type"] = "class_announcement",
                    ["sent_at"] = due.Slot.DateTime.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture),
                    ["class_id"] = row.ClassId.ToString(CultureInfo.InvariantCulture),
                    ["action_link"] = row.ActionLink ?? string.Empty,
                },
                due.Slot.AddSeconds(ScheduleDue.GraceSeconds).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:sszzz", CultureInfo.InvariantCulture)),
            NotificationsJson.Default.ScheduledPush);

    // Step 2. Everything in one transaction. The claim comes first: a second instance waits on it, then finds the occurrence claimed and writes nothing. With no device nothing is queued and no notification is written, as PHP.
    private static async Task<bool> CompleteAsync(NpgsqlDataSource source, DueRow row, DueSlot due, List<int> students, int deviceCount, DateTimeOffset now, CancellationToken ct)
    {
        await using var tx = await source.BeginAsync(ct);
        if (!await ClassScheduleLedger.ClaimAsync(tx, row.Id, due.Key, now, ct))
        {
            return false;
        }

        var notificationId = deviceCount == 0 ? null : await WriteInboxAsync(tx, row, due, students, deviceCount, now, ct);
        await ClassScheduleLedger.AddRunAsync(tx, row.Id, now, notificationId, students.Count, deviceCount, null, ct);
        if (row.EndsAfterSend)
        {
            await ClassScheduleLedger.MarkDoneAsync(tx, row.Id, now, ct);
        }

        await tx.CommitAsync(ct);
        return true;
    }

    private static async Task<int?> WriteInboxAsync(DbTx tx, DueRow row, DueSlot due, List<int> students, int deviceCount, DateTimeOffset now, CancellationToken ct)
    {
        var criteria = JsonSerializer.Serialize(new ScheduledCriteria("CLASS", row.ClassId, "scheduled", row.Id, due.Key), NotificationsJson.Default.ScheduledCriteria);
        var link = row.ActionLink ?? $"/classes/{row.ClassId.ToString(CultureInfo.InvariantCulture)}/dashboard";
        var notification = new NewNotification(row.Title, row.Body, criteria, deviceCount, 0, 0, link, row.CreatedBy);
        var written = await NotificationWriter.WriteAsync(tx, new FixedClock(now), notification, students, "class", reuseSameCriteria: true, ct);
        return written.NotificationId;
    }

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    [LoggerMessage(Level = LogLevel.Information, Message = "Scheduled class notifications: {Looked} rows looked at, {Fired} queued, {Held} held by a limit, {Ended} ended, {Lapsed} missed, {Failed} failed")]
    private static partial void LogTicked(ILogger logger, int looked, int fired, int held, int ended, int lapsed, int failed);

    [LoggerMessage(Level = LogLevel.Error, Message = "Scheduled class notification {Id} failed: {Kind}")]
    private static partial void LogRowFailed(ILogger logger, int id, string kind);

    [LoggerMessage(Level = LogLevel.Error, Message = "Scheduled class notification {Id}: could not record {Reason}: {Kind}")]
    private static partial void LogRecordFailed(ILogger logger, int id, string reason, string kind);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Scheduled class notifications: the tick cap of {Pages} pages was reached, later rows are not looked at")]
    private static partial void LogCapReached(ILogger logger, int pages);
}
