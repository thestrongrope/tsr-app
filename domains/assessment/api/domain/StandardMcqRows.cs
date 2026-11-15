namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// PHP McqModel::groupStandardMcqRows (models/mcq.php:~340): sheet rows (code, topic, subject, lesson no, name, question, answer, three options, three reasons, columns A to M)
/// become quizzes with their questions. A row whose topic is empty or "0" (PHP's falsy) is skipped. Rows with the same topic, subject, lesson and name are one quiz, in the order first seen;
/// its code is the code of the LAST such row (PHP overwrites the header on every row). A row shorter than 13 cells reads as null for the rest (the Sheets API drops trailing empty cells).
/// </summary>
internal static class StandardMcqRows
{
    internal sealed record Question(string? Text, string? Answer, string? Option1, string? Option2, string? Option3, string? Reason1, string? Reason2, string? Reason3);

    internal sealed record Quiz(string? Code, string Topic, string? Subject, string? Lesson, string? Name, IReadOnlyList<Question> Questions);

    public static IReadOnlyList<Quiz> Group(IReadOnlyList<IReadOnlyList<string>> rows)
    {
        var order = new List<string>();
        var headers = new Dictionary<string, Quiz>(StringComparer.Ordinal);
        var questions = new Dictionary<string, List<Question>>(StringComparer.Ordinal);
        foreach (var row in rows)
        {
            var topic = Cell(row, 1);
            if (string.IsNullOrEmpty(topic) || topic == "0")
            {
                continue;
            }

            var key = topic + "::" + Cell(row, 2) + "::" + Cell(row, 3) + Cell(row, 4);
            if (!headers.ContainsKey(key))
            {
                order.Add(key);
                questions[key] = [];
            }

            headers[key] = new Quiz(Cell(row, 0), topic, Cell(row, 2), Cell(row, 3), Cell(row, 4), questions[key]);
            questions[key].Add(new Question(Cell(row, 5), Cell(row, 6), Cell(row, 7), Cell(row, 8), Cell(row, 9), Cell(row, 10), Cell(row, 11), Cell(row, 12)));
        }

        return order.Select(key => headers[key]).ToList();
    }

    private static string? Cell(IReadOnlyList<string> row, int index) => index < row.Count ? row[index] : null;
}
