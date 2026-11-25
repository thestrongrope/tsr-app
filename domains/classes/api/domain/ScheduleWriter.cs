using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP's <c>ClassesModel::replaceSchedules</c>: the submitted slots replace the class's live slots, inside the caller's transaction. A slot naming the id of a live slot of this class edits it in place
/// (day, hour, minute, timezone, updated_at, updated_by); any other becomes a new slot; live slots not named are soft-deleted with their topics. An id is used once: its second mention inserts.
/// </summary>
internal static class ScheduleWriter
{
    private const int MaxSlots = 1000;

    public static async Task ReplaceAsync(DbTx tx, int classId, IReadOnlyList<ScheduleInput.Slot> slots, int by, CancellationToken ct)
    {
        var unsent = (await tx.ListAsync(
            $"""select id as "Value" from classes.class_schedules where class_id = {classId} and deleted_at is null limit {MaxSlots}""",
            row => row.Int("Value"),
            ct)).ToHashSet();

        foreach (var slot in slots)
        {
            if (IdOf(slot.Id) is int edited && unsent.Remove(edited))
            {
                await tx.ExecuteAsync(
                    $"""
                    update classes.class_schedules set day = {slot.Day}, hour = {slot.Hour}, minute = {slot.Minute}, timezone = {slot.Timezone}, updated_at = now(), updated_by = {by}
                    where id = {edited}
                    """,
                    ct);
            }
            else
            {
                await tx.ExecuteAsync(
                    $"""
                    insert into classes.class_schedules (class_id, day, hour, minute, timezone, created_by)
                    values ({classId}, {slot.Day}, {slot.Hour}, {slot.Minute}, {slot.Timezone}, {by})
                    """,
                    ct);
            }
        }

        foreach (var id in unsent)
        {
            await tx.ExecuteAsync(
                $"update classes.class_schedule_topics set deleted_at = now(), deleted_by = {by} where class_schedule_id = {id} and deleted_at is null",
                ct);
            await tx.ExecuteAsync($"update classes.class_schedules set deleted_at = now(), deleted_by = {by} where id = {id}", ct);
        }
    }

    public static async Task ApplyAsync(DbTx tx, int classId, IReadOnlyList<ScheduleInput.Slot> slots, int by, CancellationToken ct)
    {
        var unsent = (await tx.ListAsync(
            $"""select id as "Value" from classes.class_schedules where class_id = {classId} limit {MaxSlots}""",
            row => row.Int("Value"),
            ct)).ToHashSet();

        foreach (var slot in slots)
        {
            var submitted = IdOf(slot.Id);
            if (submitted is int existing && unsent.Remove(existing))
            {
                await tx.ExecuteAsync(
                    $"""
                    update classes.class_schedules set day = {slot.Day}, hour = {slot.Hour}, minute = {slot.Minute}, timezone = {slot.Timezone}, updated_at = now(), updated_by = {by}
                    where id = {existing}
                    """,
                    ct);
                await SyncTopicsAsync(tx, existing, slot.Topics, by, ct);
                continue;
            }

            var created = await tx.ScalarAsync<int>($"""select nextval(pg_get_serial_sequence('classes.class_schedules', 'id'))::int as "Value" """, ct)
                ?? throw new InvalidOperationException("The class_schedules sequence returned no value.");
            await tx.ExecuteAsync(
                $"""
                insert into classes.class_schedules (id, class_id, day, hour, minute, timezone, created_by)
                values ({created}, {classId}, {slot.Day}, {slot.Hour}, {slot.Minute}, {slot.Timezone}, {by})
                """,
                ct);
            await SyncTopicsAsync(tx, created, slot.Topics, by, ct);
        }

        foreach (var id in unsent)
        {
            await tx.ExecuteAsync($"update classes.class_schedule_topics set deleted_at = now(), deleted_by = {by} where class_schedule_id = {id}", ct);
            await tx.ExecuteAsync($"update classes.class_schedules set deleted_at = now(), deleted_by = {by} where id = {id}", ct);
        }
    }

    private static async Task SyncTopicsAsync(DbTx tx, int scheduleId, IReadOnlyList<ScheduleInput.Topic> topics, int by, CancellationToken ct)
    {
        var unsent = (await tx.ListAsync(
            $"""select id as "Value" from classes.class_schedule_topics where class_schedule_id = {scheduleId} limit {MaxSlots}""",
            row => row.Int("Value"),
            ct)).ToHashSet();

        foreach (var topic in topics)
        {
            if (IdOf(topic.Id) is int existing && unsent.Remove(existing))
            {
                await tx.ExecuteAsync(
                    $"update classes.class_schedule_topics set topic_id = {topic.TopicId}, updated_at = now(), updated_by = {by} where id = {existing}",
                    ct);
                continue;
            }

            await tx.ExecuteAsync(
                $"insert into classes.class_schedule_topics (class_schedule_id, topic_id, created_by) values ({scheduleId}, {topic.TopicId}, {by})",
                ct);
        }

        foreach (var id in unsent)
        {
            await tx.ExecuteAsync($"update classes.class_schedule_topics set deleted_at = now(), deleted_by = {by} where id = {id}", ct);
        }
    }

    /// <summary>PHP's <c>intval($id)</c> of the submitted id (null and missing are 0); a value outside an int matches nothing.</summary>
    private static int? IdOf(System.Text.Json.JsonElement raw)
    {
        var number = raw.ValueKind is System.Text.Json.JsonValueKind.Null or System.Text.Json.JsonValueKind.Undefined ? 0 : PhpValue.ToInteger(raw);
        return number is >= int.MinValue and <= int.MaxValue ? (int)number : null;
    }
}
