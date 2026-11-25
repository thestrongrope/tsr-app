using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>The outbox payload of classes.student_transferred: who moved whom from which class to which, and the kind of move.</summary>
internal sealed record StudentTransferred(int FromClassId, int ToClassId, int Token, string Type, int TransferredBy);

/// <summary>
/// The writes of moving one student between classes, shared by the single transfer (POST .../students/{token}/transfer) and the admin batch (POST /admin/transfers); PHP ClassStudentsModel::transferStudent. The
/// source's live rows are removed (status I, removed_reason "&lt;Type&gt; to class #&lt;to&gt;[: reason]", mcq_admin untouched) unless the student is being re-homed from a deactivated class (those rows stay as the audit
/// trail); a NEW destination row (joined today, no added_by); a student_transfers row; one outbox row. The caller owns the transaction and the checks.
/// </summary>
internal static class StudentMove
{
    public static async Task WriteAsync(DbTx tx, TimeProvider clock, int from, int to, int student, string type, string reason, int by, bool removeFromSource, CancellationToken ct)
    {
        if (removeFromSource)
        {
            var removal = EnrolmentRules.TransferReason(type, reason, to);
            await tx.ExecuteAsync(
                $"update classes.class_students set removed_at = now(), removed_by = {by}, status = 'I', removed_reason = {removal} where class_id = {from} and token_no = {student} and removed_at is null",
                ct);
        }

        await tx.ExecuteAsync(
            $"insert into classes.class_students (class_id, token_no, joined_on) values ({to}, {student}, (now() at time zone 'UTC')::date)", ct);
        await tx.ExecuteAsync(
            $"insert into classes.student_transfers (token_no, from_class_id, to_class_id, type, reason, transferred_by) values ({student}, {from}, {to}, {type}, {reason}, {by})",
            ct);
        await Outbox.WriteAsync(tx, "classes.student_transferred", new StudentTransferred(from, to, student, type, by), ClassesJson.Default.StudentTransferred, clock, ct);
    }
}
