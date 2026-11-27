using System.Text.Json.Nodes;
using Tsr.Shared.Api;

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
    public static async Task<JsonNode?> LoadAsync(DbTx tx, string name, CancellationToken ct)
    {
        var texts = await tx.ListAsync($"""select document::text as "Value" from assessment.quiz_state where name = {name}::citext""", row => row.Text("Value"), ct);
        return texts.Count == 0 ? null : JsonNode.Parse(texts[0]);
    }

    public static async Task<JsonObject> LoadObjectAsync(DbTx tx, string name, CancellationToken ct) =>
        await LoadAsync(tx, name, ct) as JsonObject ?? new JsonObject();

    public static async Task<JsonArray> LoadArrayAsync(DbTx tx, string name, CancellationToken ct) =>
        await LoadAsync(tx, name, ct) as JsonArray ?? new JsonArray();

    public static async Task<long> LoadQuizDayAsync(DbTx tx, CancellationToken ct) =>
        await LoadAsync(tx, QuizDay, ct) is JsonValue value && value.TryGetValue<long>(out var day) ? day : 0;

    /// <summary>When the document was last saved, or null when it does not exist.</summary>
    public static async Task<DateTimeOffset?> UpdatedAtAsync(DbTx tx, string name, CancellationToken ct)
    {
        var times = await tx.ListAsync($"""select updated_at as "Value" from assessment.quiz_state where name = {name}::citext""", row => row.Instant("Value"), ct);
        return times.Count == 0 ? null : times[0];
    }

    public static async Task<bool> ExistsAsync(DbTx tx, string name, CancellationToken ct) =>
        (await tx.ListAsync($"""select 1 as "Value" from assessment.quiz_state where name = {name}::citext""", row => row.Int("Value"), ct)).Count > 0;

    public static async Task SaveAsync(DbTx tx, string name, JsonNode document, TimeProvider clock, CancellationToken ct)
    {
        var json = document.ToJsonString();
        var now = clock.GetUtcNow();
        await tx.ExecuteAsync(
            $"""
            insert into assessment.quiz_state (name, document, updated_at) values ({name}, {json}::jsonb, {now})
            on conflict (name) do update set document = excluded.document, updated_at = excluded.updated_at
            """,
            ct);
    }

    public static async Task DeleteAsync(DbTx tx, IReadOnlyList<string> names, CancellationToken ct)
    {
        var wanted = names.ToArray();
        await tx.ExecuteAsync($"delete from assessment.quiz_state where name = any({wanted}::citext[])", ct);
    }
}
