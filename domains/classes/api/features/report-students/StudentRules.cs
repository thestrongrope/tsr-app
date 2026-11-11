using Tsr.Classes.Api.Domain;

namespace Tsr.Classes.Api.Features.ReportStudents;

/// <summary>PHP <c>MisModel::studentPerformance</c>'s arithmetic, <c>api_reports_student</c>'s rounding and the level and class pickers of <c>route_reports_students</c>.</summary>
internal static class StudentRules
{
    /// <summary>One student's sums in one class: attendance marks and present marks of the held sessions, the quizzes and questions the class published in the range, the quizzes the student answered and their right answers.</summary>
    internal sealed record Sums(int Sessions, long Present, int Quizzes, long Questions, int Responded, long Correct);

    internal sealed record Figures(int Attendance, int Attempted, int QuizPercent, int Performance, decimal PerformanceExact);

    internal sealed record Pick(string Class, string Level);

    // Each part is a MariaDB decimal at four decimals; the score divides their sum by 3 at eight.
    public static Figures Of(Sums sums)
    {
        ArgumentNullException.ThrowIfNull(sums);
        var attendance = ReportFigures.Quotient(sums.Present, sums.Sessions);
        var attempted = ReportFigures.Quotient(sums.Responded, sums.Quizzes);
        var quiz = ReportFigures.Quotient(sums.Correct, sums.Questions);
        var score = Math.Round((attendance + attempted + quiz) / 3, 8, MidpointRounding.AwayFromZero);
        return new Figures(ReportFigures.WholePercent(attendance), ReportFigures.WholePercent(attempted), ReportFigures.WholePercent(quiz), ReportFigures.WholePercent(score), score);
    }

    /// <summary>PHP <c>round((float) $avg, 2)</c> of the recitation per session; 0 for no recitation.</summary>
    public static PhpFloat AverageRecitation(long total, int sessions) =>
        total == 0 ? new PhpFloat(0) : PhpFloat.Round((decimal)total / sessions, 2);

    /// <summary>The classes the pickers list (one per class code, the last student's level wins) ordered by the level's usual position (an unknown level is 99), then natural order of the code; and the levels in that order, once each.</summary>
    public static (List<string> Levels, List<Pick> Classes) Pickers(IEnumerable<Pick> students, IReadOnlyList<string> levelOrder)
    {
        ArgumentNullException.ThrowIfNull(students);
        ArgumentNullException.ThrowIfNull(levelOrder);
        var position = new Dictionary<string, int>();
        for (var i = 0; i < levelOrder.Count; i++)
        {
            position[levelOrder[i]] = i;
        }

        var byClass = new Dictionary<string, Pick>();
        foreach (var s in students)
        {
            byClass[s.Class] = s;
        }

        int Rank(Pick p) => position.GetValueOrDefault(p.Level, 99);
        var classes = byClass.Values.OrderBy(Rank).ThenBy(c => c.Class, Comparer<string>.Create(NaturalCompare.Compare)).ToList();
        return ([.. classes.Select(c => c.Level).Distinct()], classes);
    }
}
