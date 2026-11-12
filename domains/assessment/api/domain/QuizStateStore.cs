using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The quiz competition's state documents (table <c>assessment.quiz_state</c>), replacing PHP's JSON files (models/quizadmin.php filenames(), state/quiz_settings.json). Each document keeps PHP's JSON shape:
/// settings (object), participants (object: episode to [{token, score}]), quiz_day (number), timestamps (object), scoreboard (list of rows), winners (object: episode to [winner], plus mega and mega_student),
/// winners_replaced (list, append only). Callers hold the quiz admin lock for every change.
/// </summary>
internal static class QuizStateStore
{
    public const string Settings = "settings";
    public const string Participants = "participants";
    public const string QuizDay = "quiz_day";
    public const string Timestamps = "timestamps";
    public const string Scoreboard = "scoreboard";
    public const string Winners = "winners";
    public const string WinnersReplaced = "winners_replaced";

    /// <summary>The five documents of a cycle: what delete-all clears (PHP filenames()). The settings and the replaced-winners record are not among them.</summary>
    public static readonly IReadOnlyList<string> CycleDocuments = [Scoreboard, QuizDay, Timestamps, Winners, Participants];

    /// <summary>The document, or null when it does not exist (PHP: the file is absent).</summary>
    public static async Task<JsonNode?> LoadAsync(AssessmentContext db, string name, CancellationToken ct)
    {
        var text = await db.Database
            .SqlQuery<string>($"""select document::text as "Value" from assessment.quiz_state where name = {name}""")
            .FirstOrDefaultAsync(ct);
        return text is null ? null : JsonNode.Parse(text);
    }

    public static async Task<JsonObject> LoadObjectAsync(AssessmentContext db, string name, CancellationToken ct) =>
        await LoadAsync(db, name, ct) as JsonObject ?? new JsonObject();

    public static async Task<JsonArray> LoadArrayAsync(AssessmentContext db, string name, CancellationToken ct) =>
        await LoadAsync(db, name, ct) as JsonArray ?? new JsonArray();

    public static async Task<long> LoadQuizDayAsync(AssessmentContext db, CancellationToken ct) =>
        await LoadAsync(db, QuizDay, ct) is JsonValue value && value.TryGetValue<long>(out var day) ? day : 0;

    public static async Task<bool> ExistsAsync(AssessmentContext db, string name, CancellationToken ct) =>
        await db.Database.SqlQuery<int>($"""select 1 as "Value" from assessment.quiz_state where name = {name}""").AnyAsync(ct);

    public static async Task SaveAsync(AssessmentContext db, string name, JsonNode document, TimeProvider clock, CancellationToken ct)
    {
        var json = document.ToJsonString();
        var now = clock.GetUtcNow();
        await db.Database.ExecuteSqlAsync(
            $"""
            insert into assessment.quiz_state (name, document, updated_at) values ({name}, {json}::jsonb, {now})
            on conflict (name) do update set document = excluded.document, updated_at = excluded.updated_at
            """,
            ct);
    }

    public static async Task DeleteAsync(AssessmentContext db, IReadOnlyList<string> names, CancellationToken ct)
    {
        var wanted = names.ToArray();
        await db.Database.ExecuteSqlAsync($"delete from assessment.quiz_state where name = any({wanted})", ct);
    }
}
