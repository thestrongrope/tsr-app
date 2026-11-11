namespace Tsr.Classes.Api.Features.ReportPending;

/// <summary>PHP <c>MisModel::pendingByTeacher</c> and <c>api_reports_pending_in_level</c>: the classes with something pending, grouped under their teacher and ordered, and the narrowing to one level.</summary>
internal static class PendingRules
{
    internal sealed record ClassRow(int Id, string Code, string Level, int Teacher, string TeacherName);

    internal sealed record Mcq(int Expected, int Conducted, int Pending);

    internal sealed record PendingClass(int ClassId, string Level, string Class, int NotFilled, int McqPending, int McqConducted, int McqExpected);

    internal sealed record PendingTeacher(int TeacherToken, string Teacher, int NotFilled, int McqPending, IReadOnlyList<PendingClass> Classes);

    public static List<PendingTeacher> Group(IReadOnlyList<ClassRow> classes, IReadOnlyDictionary<int, int> notFilled, IReadOnlyDictionary<int, Mcq> mcqs)
    {
        ArgumentNullException.ThrowIfNull(classes);
        ArgumentNullException.ThrowIfNull(notFilled);
        ArgumentNullException.ThrowIfNull(mcqs);
        var order = new List<int>();
        var byTeacher = new Dictionary<int, (string Name, List<PendingClass> Classes)>();
        foreach (var c in classes)
        {
            var forms = notFilled.GetValueOrDefault(c.Id);
            var mcq = mcqs.GetValueOrDefault(c.Id) ?? new Mcq(0, 0, 0);
            if (forms <= 0 && mcq.Pending <= 0)
            {
                continue;
            }

            if (!byTeacher.TryGetValue(c.Teacher, out var entry))
            {
                entry = (c.TeacherName, []);
                byTeacher[c.Teacher] = entry;
                order.Add(c.Teacher);
            }

            entry.Classes.Add(new PendingClass(c.Id, c.Level, c.Code, Math.Max(forms, 0), mcq.Pending, mcq.Conducted, mcq.Expected));
        }

        var teachers = order.Select(token => Total(token, byTeacher[token].Name, byTeacher[token].Classes));
        return [.. teachers.OrderByDescending(t => t.NotFilled).ThenByDescending(t => t.McqPending).ThenBy(t => LowerAscii(t.Teacher), StringComparer.Ordinal)];
    }

    /// <summary>The teachers' classes of one level only (compared exactly), totals recounted, teachers with none dropped; the order is kept.</summary>
    public static List<PendingTeacher> InLevel(IReadOnlyList<PendingTeacher> teachers, string level)
    {
        ArgumentNullException.ThrowIfNull(teachers);
        var kept = new List<PendingTeacher>();
        foreach (var t in teachers)
        {
            var classes = t.Classes.Where(c => c.Level == level).ToList();
            if (classes.Count > 0)
            {
                kept.Add(Total(t.TeacherToken, t.Teacher, classes));
            }
        }

        return kept;
    }

    private static PendingTeacher Total(int token, string name, List<PendingClass> classes) =>
        new(token, name, classes.Sum(c => c.NotFilled), classes.Sum(c => c.McqPending), classes);

    // PHP strtolower (PHP 8) lowers ASCII letters only.
    private static string LowerAscii(string text) => string.Create(text.Length, text, static (span, source) =>
    {
        for (var i = 0; i < source.Length; i++)
        {
            span[i] = source[i] is >= 'A' and <= 'Z' ? (char)(source[i] + 32) : source[i];
        }
    });
}
