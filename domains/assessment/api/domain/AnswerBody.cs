using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The body of POST /mcq/quizzes/{id}/responses as PHP reads it (routes/mcq.php route_quiz_submit): <c>responses</c> is a non-empty array (or object) of items; an item counts only when it is an object whose
/// <c>questionId</c> is present and not null; the key is <c>(int) questionId</c>, a repeated id keeps its first position and its last item. <c>selectedText</c> is stored as PHP's (string) of it (null stays null),
/// <c>option</c> is echoed as an int (0 unless numeric).
/// </summary>
internal static class AnswerBody
{
    internal sealed record Answer(long QuestionId, string? SelectedText, int Selected);

    /// <summary>The answers in the order their ids first appeared, or null when <c>responses</c> is missing, not an array or object, or empty.</summary>
    public static IReadOnlyList<Answer>? Parse(JsonBody body)
    {
        var responses = body.Get("responses");
        if (responses.ValueKind is not (JsonValueKind.Array or JsonValueKind.Object))
        {
            return null;
        }

        var items = JsonBody.Entries(responses);
        if (items.Count == 0)
        {
            return null;
        }

        var byId = new Dictionary<long, Answer>();
        var order = new List<long>();
        foreach (var (_, item) in items)
        {
            if (item.ValueKind != JsonValueKind.Object || !item.TryGetProperty("questionId", out var id) || id.ValueKind == JsonValueKind.Null)
            {
                continue;
            }

            var key = PhpValue.ToInteger(id);
            if (!byId.ContainsKey(key))
            {
                order.Add(key);
            }

            byId[key] = new Answer(key, SelectedText(item), Selected(item));
        }

        return order.Select(k => byId[k]).ToList();
    }

    /// <summary>PostgreSQL text cannot hold a NUL, so it is dropped (PHP's trim would strip an edge one before scoring anyway).</summary>
    private static string? SelectedText(JsonElement item)
    {
        if (!item.TryGetProperty("selectedText", out var text) || text.ValueKind == JsonValueKind.Null)
        {
            return null;
        }

        return PhpValue.Text(text).Replace("\0", string.Empty, StringComparison.Ordinal);
    }

    /// <summary>api_cast 'int' of the item's <c>option</c>: a number truncates, numeric text is its value, anything else 0.</summary>
    private static int Selected(JsonElement item)
    {
        if (!item.TryGetProperty("option", out var option))
        {
            return 0;
        }

        var numeric = option.ValueKind == JsonValueKind.Number || (option.ValueKind == JsonValueKind.String && PhpValue.IsNumeric(option.GetString() ?? string.Empty));
        return numeric ? (int)Math.Clamp(PhpValue.ToInteger(option), int.MinValue, int.MaxValue) : 0;
    }
}
