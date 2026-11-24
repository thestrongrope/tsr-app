using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// The order a question's options are shown in on paper and in the offline entry screen, PHP's McqModel::fillMissingOptionOrders and orderedOptions. option1 is the right answer by convention, so a question whose order was never
/// stored would print its answer first: publish and the sheet fix the order first. The two rules look at the options differently and are ported as they are:
/// fill takes options 1 to 4 only and PHP's <c>empty()</c> (so "0" counts as empty); showing takes options 1 to 5 with a plain non-empty test (so "0" is shown, but option 5 is shown only when no order is stored).
/// </summary>
internal static class OptionOrder
{
    internal sealed record Row(int Id, string? Option1, string? Option2, string? Option3, string? Option4);

    internal sealed record Shown(string Text, bool IsCorrect);

    /// <summary>The numbers of options 1 to 4 that PHP's empty() calls filled, in random order, as the text stored in <c>option_display_order</c> ("" when none).</summary>
    public static string NewOrder(IReadOnlyList<string?> options, IQuizRandom random)
    {
        var numbers = new List<int>();
        for (var i = 0; i < Math.Min(4, options.Count); i++)
        {
            if (!string.IsNullOrEmpty(options[i]) && options[i] != "0")
            {
                numbers.Add(i + 1);
            }
        }

        for (var i = numbers.Count - 1; i > 0; i--)
        {
            var j = random.Next(i + 1);
            (numbers[i], numbers[j]) = (numbers[j], numbers[i]);
        }

        return string.Join(',', numbers);
    }

    /// <summary>The options as a student sees them: the stored order (numbers 1 to 5 whose option is not empty), else the natural order of the non-empty options. Option 1 is the correct one.</summary>
    public static IReadOnlyList<Shown> Ordered(string? order, IReadOnlyList<string?> options)
    {
        var numbers = new List<int>();
        foreach (var part in (order ?? string.Empty).Split(','))
        {
            var n = PhpValue.IntOfText(part);
            if (n is >= 1 and <= 5 && !string.IsNullOrEmpty(options[(int)n - 1]))
            {
                numbers.Add((int)n);
            }
        }

        if (numbers.Count == 0)
        {
            numbers.AddRange(Enumerable.Range(1, 5).Where(n => !string.IsNullOrEmpty(options[n - 1])));
        }

        return numbers.Select(n => new Shown(options[n - 1]!, n == 1)).ToList();
    }

    /// <summary>Stores an order for every question of the quiz that has none. Only a question still without one is written, so two callers at once keep the first order. At most 5000 questions.</summary>
    public static async Task FillMissingAsync(NpgsqlDataSource source, long quizId, IQuizRandom random, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"""
            select id as "Id", option1::text as "Option1", option2::text as "Option2", option3::text as "Option3", option4::text as "Option4"
            from assessment.spot_quiz_questions where spot_quiz_id = {quizId} and option_display_order is null order by id limit 5000
            """,
            row => new Row(row.Int("Id"), row.TextOrNull("Option1"), row.TextOrNull("Option2"), row.TextOrNull("Option3"), row.TextOrNull("Option4")),
            ct);
        foreach (var row in rows)
        {
            var order = NewOrder([row.Option1, row.Option2, row.Option3, row.Option4], random);
            await source.ExecuteAsync($"update assessment.spot_quiz_questions set option_display_order = {order} where id = {row.Id} and option_display_order is null", ct);
        }
    }
}
