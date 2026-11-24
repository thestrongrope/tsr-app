using Npgsql;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// The writes of teacher training, shared by the training and the import routes (PHP TeachersModel::writeBatch): per teacher, the record is updated (a teacher who had one) or inserted, with status A and the batch
/// comment, one <c>teachers_history</c> row is added, and one outbox row says the training changed. The caller owns the transaction. The caller's gender rule (genderLock) is also here: PHP api_teachers_gender.
/// </summary>
internal static class TeacherWriter
{
    internal sealed record TrainingChanged(int Token, int Salman, int Abuzar, int Miqdad, int Ammar, int Bilal, int ChangedBy, string BatchId);

    private const int Gents = 1;
    private const int Ladies = 2;

    private sealed record Stored(int Salman, int Abuzar, int Miqdad, int Ammar, int Bilal);

    /// <summary>PHP api_teachers_gender: a gender administrator's own gender, else the one asked for (exactly "2" is ladies, anything else gents).</summary>
    public static async Task<int> GenderAsync(Permissions permissions, Caller caller, string asked, CancellationToken ct)
    {
        var reach = await permissions.ReachAsync(caller, "teachers:read", ct);
        return reach.GenderLock ?? (asked == "2" ? Ladies : Gents);
    }

    /// <summary>The current flags of a teacher's record, or null when they have none.</summary>
    public static async Task<TeacherTraining.Flags?> ExistingAsync(DbTx tx, int token, CancellationToken ct)
    {
        var rows = await tx.ListAsync(
            $"""select salman as "Salman", abuzar as "Abuzar", miqdad as "Miqdad", ammar as "Ammar", bilal as "Bilal" from classes.teachers where token = {token} limit 1""",
            row => new Stored(row.Int("Salman"), row.Int("Abuzar"), row.Int("Miqdad"), row.Int("Ammar"), row.Int("Bilal")),
            ct);
        return rows.Count == 0 ? null : new TeacherTraining.Flags(rows[0].Salman, rows[0].Abuzar, rows[0].Miqdad, rows[0].Ammar, rows[0].Bilal);
    }

    /// <summary>The same read on the data source, for a caller that holds no transaction yet.</summary>
    public static async Task<TeacherTraining.Flags?> ExistingAsync(NpgsqlDataSource source, int token, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""select salman as "Salman", abuzar as "Abuzar", miqdad as "Miqdad", ammar as "Ammar", bilal as "Bilal" from classes.teachers where token = {token} limit 1""",
            row => new Stored(row.Int("Salman"), row.Int("Abuzar"), row.Int("Miqdad"), row.Int("Ammar"), row.Int("Bilal")),
            ct);
        return rows.Count == 0 ? null : new TeacherTraining.Flags(rows[0].Salman, rows[0].Abuzar, rows[0].Miqdad, rows[0].Ammar, rows[0].Bilal);
    }

    public static async Task WriteBatchAsync(
        DbTx tx,
        IReadOnlyList<(int Token, TeacherTraining.Flags Flags)> teachers,
        string note,
        int by,
        TimeProvider clock,
        CancellationToken ct)
    {
        var batchId = TeacherTraining.BatchId(clock.GetUtcNow());
        foreach (var (token, flags) in teachers)
        {
            var existing = await ExistingAsync(tx, token, ct);
            var comment = TeacherTraining.Comment(existing, flags, note, batchId);
            if (existing is not null)
            {
                await tx.ExecuteAsync(
                    $"""
                    update classes.teachers set salman = {flags.Salman}, abuzar = {flags.Abuzar}, miqdad = {flags.Miqdad}, ammar = {flags.Ammar}, bilal = {flags.Bilal},
                           status = 'A', comments = {comment}, updated_by = {by}, updated_at = now()
                    where token = {token}
                    """,
                    ct);
            }
            else
            {
                await tx.ExecuteAsync(
                    $"""
                    insert into classes.teachers (token, salman, abuzar, miqdad, ammar, bilal, status, comments, created_by, created_at)
                    values ({token}, {flags.Salman}, {flags.Abuzar}, {flags.Miqdad}, {flags.Ammar}, {flags.Bilal}, 'A', {comment}, {by}, now())
                    """,
                    ct);
            }

            await tx.ExecuteAsync(
                $"""
                insert into classes.teachers_history (token, salman, abuzar, miqdad, ammar, bilal, status, comments, created_by, created_at)
                values ({token}, {flags.Salman}, {flags.Abuzar}, {flags.Miqdad}, {flags.Ammar}, {flags.Bilal}, 'A', {comment}, {by}, now())
                """,
                ct);
            await Outbox.WriteAsync(tx, "classes.teacher_training_changed", new TrainingChanged(token, flags.Salman, flags.Abuzar, flags.Miqdad, flags.Ammar, flags.Bilal, by, batchId), ClassesJson.Default.TeacherTrainingChanged, clock, ct);
        }
    }
}

