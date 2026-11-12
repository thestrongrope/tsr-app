using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The body of POST /mcq/manage/{quiz_id}/offline as PHP reads it (routes/mcq_admin.php route_mcq_manage_offline_save and McqModel::saveOfflineBatch) in two steps, so the rules can be tested without a database.
/// <see cref="Read"/> (PHP's route): <c>students</c> must be a non-empty list or object (422 "students is required"), each entry a list or object whose <c>correct</c> is a list or object (422 "each student needs a token and a correct list");
/// the token is (int) of <c>token</c> (0 when missing) and a repeated token keeps its FIRST position and its LAST list. Added: more than <see cref="MaxStudents"/> students or <see cref="MaxCorrect"/> ids in one list is 422.
/// <see cref="Plan"/> (PHP's model), student by student in the order sent: a token that is not above 0 is 400 "Malformed response payload."; one not enrolled is 403 "Student N is not enrolled in this class.";
/// a question id ((int) of each entry) that is not a question of the quiz is 400 "Question N does not belong to this quiz.". The first refusal wins.
/// </summary>
internal static class OfflineBatch
{
    public const int MaxStudents = 500;
    public const int MaxCorrect = 5000;

    internal sealed record Entry(long Token, IReadOnlyList<JsonElement> Correct);

    internal sealed record Student(int Token, IReadOnlySet<long> Correct);

    internal sealed record Refusal(int Status, string Message);

    public static (IReadOnlyList<Entry>? Entries, Refusal? Refusal) Read(JsonBody body)
    {
        var sent = JsonBody.Entries(body.Get("students"));
        if (sent.Count == 0)
        {
            return (null, new Refusal(422, "students is required"));
        }

        if (sent.Count > MaxStudents)
        {
            return (null, new Refusal(422, $"At most {MaxStudents} students can be saved at once"));
        }

        var entries = new List<Entry>();
        var position = new Dictionary<long, int>();
        foreach (var (_, student) in sent)
        {
            var fields = JsonBody.Entries(student);
            var correct = student.ValueKind is JsonValueKind.Array or JsonValueKind.Object ? fields.FirstOrDefault(f => f.Key == "correct").Value : default;
            if (correct.ValueKind is not (JsonValueKind.Array or JsonValueKind.Object))
            {
                return (null, new Refusal(422, "each student needs a token and a correct list"));
            }

            var ids = JsonBody.Entries(correct);
            if (ids.Count > MaxCorrect)
            {
                return (null, new Refusal(422, $"A correct list holds at most {MaxCorrect} question ids"));
            }

            var token = PhpValue.ToInteger(fields.FirstOrDefault(f => f.Key == "token").Value);
            var entry = new Entry(token, ids.Select(i => i.Value).ToList());
            if (position.TryGetValue(token, out var at))
            {
                entries[at] = entry;
                continue;
            }

            position[token] = entries.Count;
            entries.Add(entry);
        }

        return (entries, null);
    }

    public static (IReadOnlyList<Student>? Students, Refusal? Refusal) Plan(IReadOnlyList<Entry> entries, IReadOnlySet<long> questionIds, IReadOnlySet<long> enrolled)
    {
        var students = new List<Student>();
        foreach (var entry in entries)
        {
            if (entry.Token <= 0)
            {
                return (null, new Refusal(400, "Malformed response payload."));
            }

            if (!enrolled.Contains(entry.Token))
            {
                return (null, new Refusal(403, $"Student {entry.Token} is not enrolled in this class."));
            }

            var correct = new HashSet<long>();
            foreach (var id in entry.Correct)
            {
                var questionId = PhpValue.ToInteger(id);
                if (!questionIds.Contains(questionId))
                {
                    return (null, new Refusal(400, $"Question {questionId} does not belong to this quiz."));
                }

                correct.Add(questionId);
            }

            students.Add(new Student((int)entry.Token, correct));
        }

        return (students, null);
    }
}
