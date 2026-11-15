using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The write of a conduction record, shared by POST and PUT (PHP SessionsModel add and edit), in one transaction with its outbox row. The class row is locked first (five seconds at most), so the replay and
/// duplicate-day checks cannot be raced by a second request for the same class. Attendance: PHP's <c>keepClassMembers</c> silently drops body students who never had an enrolment row in this class (removed members
/// stay), the session's <c>attendance</c> counts the present ones that remain plus the present extras, a student who is absent gets recitation 0, and the five flags are stored as '0'/'1' as PHP's API does.
/// Not in the outbox: a replay, a refused duplicate.
/// </summary>
internal static class ConductionWriter
{
    private const int MaxEnrolments = 20000;

    internal sealed record Recorded(int ClassId, int SessionId, int RecordedBy);

    internal sealed record Updated(int ClassId, int SessionId, int UpdatedBy);

    internal sealed record Created(int SessionId, bool Replayed, bool Duplicate);

    public static async Task<Created> CreateAsync(
        ClassesContext db, TimeProvider clock, int classId, int by, ConductionRules.Payload payload, DateTimeOffset? recordedAt, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await LockClassAsync(db, classId, ct);
        if (recordedAt is not null)
        {
            var replay = await db.Database
                .SqlQuery<int>($"""
                    select id as "Value" from classes.class_sessions
                    where class_id = {classId} and conducted_on = {payload.ConductedOn} and created_by = {by} and created_at = {recordedAt.Value}
                    order by id limit 1
                    """)
                .ToListAsync(ct);
            if (replay.Count > 0)
            {
                return new Created(replay[0], Replayed: true, Duplicate: false);
            }
        }

        if ((await ConductionData.CheckDayAsync(db, classId, payload.ConductedOn, 0, ct)).AlreadyConducted)
        {
            return new Created(0, Replayed: false, Duplicate: true);
        }

        var attendance = await KeepMembersAsync(db, classId, payload, ct);
        var teacher = await db.Database.SqlQuery<int>($"""select coalesce(teacher, 0) as "Value" from classes.classes where id = {classId}""").SingleAsync(ct);
        var created = recordedAt ?? clock.GetUtcNow();
        var held = payload.Held;
        var topics = payload.Topics;
        var ids = await db.Database
            .SqlQuery<int>($"""
                insert into classes.class_sessions (class_id, teacher, conducted_on, conducted, non_conduction_reason, duration, attendance, quran_recitation_surah, quran_recitation_verse,
                    arabic_conducted, aqaed_conducted, ahkam_conducted, akhlaq_conducted, other_conducted, arabic_topic, aqaed_topic, ahkam_topic, akhlaq_topic, other_topic, created_by, created_at)
                values ({classId}, {teacher}, {payload.ConductedOn}, {(payload.Conducted ? 1 : 0)}, {payload.Reason}, {payload.Duration}, {attendance.Count}, {payload.Surah}, {payload.Verse},
                    {Flag(held[0])}, {Flag(held[1])}, {Flag(held[2])}, {Flag(held[3])}, {Flag(held[4])}, {topics[0]}, {topics[1]}, {topics[2]}, {topics[3]}, {topics[4]}, {by}, {created})
                returning id as "Value"
                """)
            .ToListAsync(ct);
        var sessionId = ids[0];
        await InsertAttendanceAsync(db, sessionId, attendance, ct);
        await Outbox.WriteAsync(db, "classes.session_recorded", new Recorded(classId, sessionId, by), clock, ct);
        await transaction.CommitAsync(ct);
        return new Created(sessionId, Replayed: false, Duplicate: false);
    }

    /// <summary>PHP SessionsModel::edit after the route's checks: false when another session of the class is already on the new day (nothing is written).</summary>
    public static async Task<bool> UpdateAsync(ClassesContext db, TimeProvider clock, int classId, int sessionId, int by, ConductionRules.Payload payload, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await LockClassAsync(db, classId, ct);
        if ((await ConductionData.CheckDayAsync(db, classId, payload.ConductedOn, sessionId, ct)).AlreadyConducted)
        {
            return false;
        }

        var attendance = await KeepMembersAsync(db, classId, payload, ct);
        var held = payload.Held;
        var topics = payload.Topics;
        await db.Database.ExecuteSqlAsync(
            $"""
            update classes.class_sessions set
                conducted_on = {payload.ConductedOn}, conducted = {(payload.Conducted ? 1 : 0)}, non_conduction_reason = {payload.Reason}, duration = {payload.Duration}, attendance = {attendance.Count},
                quran_recitation_surah = {payload.Surah}, quran_recitation_verse = {payload.Verse},
                arabic_conducted = {Flag(held[0])}, aqaed_conducted = {Flag(held[1])}, ahkam_conducted = {Flag(held[2])}, akhlaq_conducted = {Flag(held[3])}, other_conducted = {Flag(held[4])},
                arabic_topic = {topics[0]}, aqaed_topic = {topics[1]}, ahkam_topic = {topics[2]}, akhlaq_topic = {topics[3]}, other_topic = {topics[4]},
                updated_at = now(), updated_by = {by}
            where id = {sessionId}
            """,
            ct);
        await db.Database.ExecuteSqlAsync($"delete from classes.class_attendance where session_id = {sessionId}", ct);
        await InsertAttendanceAsync(db, sessionId, attendance, ct);
        await Outbox.WriteAsync(db, "classes.session_updated", new Updated(classId, sessionId, by), clock, ct);
        await transaction.CommitAsync(ct);
        return true;
    }

    private static string Flag(bool held) => held ? "1" : "0";

    private static async Task LockClassAsync(ClassesContext db, int classId, CancellationToken ct)
    {
        await db.Database.ExecuteSqlAsync($"select set_config('lock_timeout', '5s', true)", ct);
        await db.Database.SqlQuery<int>($"""select id as "Value" from classes.classes where id = {classId} for update""").ToListAsync(ct);
    }

    private sealed record Rows(IReadOnlyList<ConductionRules.Student> Students, IReadOnlyList<ConductionRules.Extra> Extras)
    {
        // PHP: present students that stay plus present extras.
        public int Count => Students.Count(s => s.Present) + Extras.Count(e => e.Present);
    }

    private static async Task<Rows> KeepMembersAsync(ClassesContext db, int classId, ConductionRules.Payload payload, CancellationToken ct)
    {
        var enrolled = (await db.Database
            .SqlQuery<int>($"""select distinct token_no as "Value" from classes.class_students where class_id = {classId} and token_no is not null limit {MaxEnrolments}""")
            .ToListAsync(ct)).ToHashSet();
        return new Rows(payload.Students.Where(s => enrolled.Contains(s.Token)).ToList(), payload.Extras);
    }

    private static async Task InsertAttendanceAsync(ClassesContext db, int sessionId, Rows rows, CancellationToken ct)
    {
        var tokens = rows.Students.Select(s => s.Token).ToArray();
        var present = rows.Students.Select(s => (short)(s.Present ? 1 : 0)).ToArray();
        var recitation = rows.Students.Select(s => s.Present ? s.Recitation : 0).ToArray();
        await db.Database.ExecuteSqlAsync(
            $"""
            insert into classes.class_attendance (session_id, token, present, recitation)
            select {sessionId}, t.token, t.present, t.recitation from unnest({tokens}, {present}, {recitation}) as t (token, present, recitation)
            """,
            ct);
        var extraTokens = rows.Extras.Select(e => e.Token).ToArray();
        var names = rows.Extras.Select(e => e.Name).ToArray();
        var extraPresent = rows.Extras.Select(e => (short)(e.Present ? 1 : 0)).ToArray();
        await db.Database.ExecuteSqlAsync(
            $"""
            insert into classes.class_attendance (session_id, token, name, extra_student, present)
            select {sessionId}, t.token, t.name, 1, t.present from unnest({extraTokens}, {names}, {extraPresent}) as t (token, name, present)
            """,
            ct);
    }
}
