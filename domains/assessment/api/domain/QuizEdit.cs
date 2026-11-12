using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The body of PUT /mcq/manage/{quiz_id} as PHP reads it (routes/mcq_admin.php route_mcq_manage_update, McqModel addQuestions): a trimmed name and topic (both required, the name first), then the rows of <c>questions</c>.
/// Rows: skipped when not an object or list, or when question and answer are both blank; refused ("Question N needs both a question and an answer", N = (int) key + 1) when only one is blank. The answer is stored as option1,
/// a missing option is the empty text, the text "null" is a database null, and a question whose text is "0" passes the check, is counted, and is NOT inserted (PHP's falsy string). <c>questions</c> missing or not an array is
/// no rows at all (PHP warns and loops over nothing, so an edit wipes the quiz's questions). <c>restrictToClass</c> is left alone when absent or null, else 0 when (int) of it is 0 and 1 otherwise.
/// Added (PHP would answer 500 "Failed to save quiz" on a strict database, or accept a NUL): after PHP's own rules, a name or topic over 300 characters or a question or option over 1000 is a refusal, a NUL byte is a refusal,
/// and more than 500 rows is refused before any is read. All refusals are 422.
/// </summary>
internal static class QuizEdit
{
    internal const int MaxQuestions = 500;
    private const int MaxTitle = 300;
    private const int MaxText = 1000;
    private static readonly string[] OptionFields = ["option2", "option3", "option4", "option5"];

    internal sealed record Question(string Text, string? Option1, string? Option2, string? Option3, string? Option4, string? Option5);

    /// <summary><paramref name="Insert"/> is what is stored; <paramref name="QuestionCount"/> is what PHP reports (it counts the "0" question it does not insert).</summary>
    internal sealed record Edit(string Name, string Topic, int? RestrictToClass, IReadOnlyList<Question> Insert, int QuestionCount);

    private sealed record Row(int Position, Question Question);

    public static Result<Edit> Parse(JsonBody body)
    {
        var name = Field(body.Get("name"));
        if (name.Length == 0)
        {
            return Result.Fail<Edit>("name is required");
        }

        var topic = Field(body.Get("topic"));
        if (topic.Length == 0)
        {
            return Result.Fail<Edit>("topic is required");
        }

        var entries = JsonBody.Entries(body.Get("questions"));
        if (entries.Count > MaxQuestions)
        {
            return Result.Fail<Edit>($"A quiz holds at most {MaxQuestions} questions");
        }

        var rows = new List<Row>();
        var counted = 0;
        foreach (var (key, row) in entries)
        {
            var position = (int)Math.Clamp(PhpValue.IntOfText(key), 0, int.MaxValue - 1) + 1;
            var read = ReadRow(row, position);
            if (read.Error is not null)
            {
                return Result.Fail<Edit>(read.Error);
            }

            if (read.Value is null)
            {
                continue;
            }

            counted++;
            if (read.Value.Question.Text != "0")
            {
                rows.Add(read.Value);
            }
        }

        var refusal = Refusal("name", name, MaxTitle) ?? Refusal("topic", topic, MaxTitle) ?? rows.Select(RowRefusal).FirstOrDefault(r => r is not null);
        return refusal is not null ? Result.Fail<Edit>(refusal) : Result.Ok(new Edit(name, topic, Restriction(body.Get("restrictToClass")), rows.Select(r => r.Question).ToList(), counted));
    }

    private static string Field(JsonElement value) => PhpText.Trim(PhpValue.Text(value));

    private static int? Restriction(JsonElement value) =>
        value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null ? null : PhpValue.ToInteger(value) == 0 ? 0 : 1;

    private static JsonElement Property(IReadOnlyList<KeyValuePair<string, JsonElement>> entries, string name) =>
        entries.FirstOrDefault(e => e.Key == name).Value;

    private static (Row? Value, string? Error) ReadRow(JsonElement row, int position)
    {
        if (row.ValueKind is not (JsonValueKind.Array or JsonValueKind.Object))
        {
            return (null, null);
        }

        var entries = JsonBody.Entries(row);
        var text = Field(Property(entries, "question"));
        var answer = Field(Property(entries, "answer"));
        if (text.Length == 0 && answer.Length == 0)
        {
            return (null, null);
        }

        if (text.Length == 0 || answer.Length == 0)
        {
            return (null, $"Question {position} needs both a question and an answer");
        }

        var options = OptionFields.Select(f => Stored(Field(Property(entries, f)))).ToArray();
        return (new Row(position, new Question(text, Stored(answer), options[0], options[1], options[2], options[3])), null);
    }

    private static string? Stored(string text) => text == "null" ? null : text;

    private static string? RowRefusal(Row row)
    {
        var q = row.Question;
        string?[] texts = [q.Text, q.Option1, q.Option2, q.Option3, q.Option4, q.Option5];
        if (texts.Any(t => t is not null && t.Contains('\0', StringComparison.Ordinal)))
        {
            return $"Question {row.Position} contains an invalid character";
        }

        return texts.Any(t => t is not null && PhpText.CodePointCount(t) > MaxText)
            ? $"Question {row.Position} is too long (the question and each option are at most {MaxText} characters)"
            : null;
    }

    private static string? Refusal(string field, string value, int max)
    {
        if (value.Contains('\0', StringComparison.Ordinal))
        {
            return $"{field} contains an invalid character";
        }

        return PhpText.CodePointCount(value) > max ? $"{field} is too long (at most {max} characters)" : null;
    }
}
