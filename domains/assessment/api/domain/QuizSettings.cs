using System.Text.Json.Nodes;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The quiz settings as PHP keeps them (state/quiz_settings.json): a JSON object read from the settings sheet, values mostly text. <see cref="FromSheets"/> is PHP QuizAdminModel::fetchSettings (models/quizadmin.php:~815):
/// the Technical tab (A1:B) is key and value (a row of any other width is the key and a list of the cells after it), the Functional tab (A1:D) is key and value rows plus tables (a header row, then one row per entry:
/// <c>settings[firstHeader][rowKey][header_i] = cell_i</c>; the header list keeps growing across tables, as PHP's does). The accessors read text and whole numbers as PHP's intval and string casts.
/// </summary>
internal sealed class QuizSettings(JsonObject values)
{
    /// <summary>Most episodes a quiz may have: the sheets are read once per episode and the cross-day check is exponential in the started ones.</summary>
    public const int MaxEpisodes = 30;

    public JsonObject Values { get; } = values;

    /// <summary>A quiz whose mode and episode count are known (PHP settingsLoaded: both keys set).</summary>
    public bool Loaded => Values["mode"] is not null && Values["total_quizzes"] is not null;

    public bool IsMega => Str("quiz_type") == "MEGA";

    public int TotalQuizzes => (int)Math.Clamp(Int("total_quizzes"), 0, int.MaxValue);

    /// <summary>The text of a setting; null when absent or not text (a list or table).</summary>
    public string? Str(string key) => Values[key] is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;

    public long Int(string key) => PhpValue.IntOfText(Str(key) ?? string.Empty);

    /// <summary>The settings key for the mode: "live" reads the plain keys, any other mode its prefix (PHP sheetIds: <c>uat_responses_sheet_id</c>).</summary>
    public string ModePrefix()
    {
        var mode = (Str("mode") ?? string.Empty).ToLowerInvariant();
        return mode == "live" ? string.Empty : mode + "_";
    }

    /// <summary>PHP isLiveMode: any mode but empty, "offline" and "UAT".</summary>
    public static bool IsLiveMode(string? mode)
    {
        var m = (mode ?? string.Empty).Trim().ToLowerInvariant();
        return m != string.Empty && m != "offline" && m != "uat";
    }

    public static QuizSettings FromSheets(IReadOnlyList<IReadOnlyList<string>> technical, IReadOnlyList<IReadOnlyList<string>> functional)
    {
        var settings = new JsonObject();
        foreach (var row in technical.Where(r => r.Count > 0))
        {
            settings[row[0]] = row.Count == 2 ? JsonValue.Create(row[1]) : new JsonArray(row.Skip(1).Select(c => (JsonNode?)JsonValue.Create(c)).ToArray());
        }

        var inTable = false;
        var headers = new List<string>();
        foreach (var row in functional.Where(r => r.Count > 0))
        {
            if (row.Count == 2)
            {
                settings[row[0]] = JsonValue.Create(row[1]);
                inTable = false;
            }
            else if (!inTable)
            {
                headers.AddRange(row);
                inTable = true;
            }
            else
            {
                AddTableRow(settings, headers, row);
            }
        }

        return new QuizSettings(settings);
    }

    private static void AddTableRow(JsonObject settings, List<string> headers, IReadOnlyList<string> row)
    {
        var table = settings[headers[0]] as JsonObject ?? new JsonObject();
        settings[headers[0]] = table;
        var entry = table[row[0]] as JsonObject ?? new JsonObject();
        table[row[0]] = entry;
        for (var i = 1; i < row.Count; i++)
        {
            entry[i < headers.Count ? headers[i] : string.Empty] = JsonValue.Create(row[i]);
        }
    }
}
