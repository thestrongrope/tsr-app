using System.Globalization;
using Tsr.Classes.Api.Domain;

namespace Tsr.Classes.Api.Features.ReportThisWeek;

internal static class ThisWeekRules
{
    internal const int FlagWeeks = 2;
    internal const int CallWeeks = 4;
    internal const double LowAttendance = 0.5;

    internal readonly record struct WeekRef(DateOnly Start, DateOnly End, int Position);

    internal sealed record Quiet(string Subject, int Weeks);

    internal sealed record Row(
        int ClassId, string Code, string Level, string? Teacher, int? TeacherToken, string? TeacherMobile, string Detail, string? Action, IReadOnlyList<Quiet> Quiet);

    internal sealed record ClassInput(
        int Id, string Code, string Level, string? Teacher, int? TeacherToken, string? TeacherMobile, DateOnly StartedOn, IReadOnlyList<string> Cells, IReadOnlyDictionary<string, bool[]> Subjects);

    internal sealed record Summary(int Met, int Of, int FormsMissing, PhpFloat? Attendance, int Flagged);

    internal sealed record Stages(IReadOnlyList<Row> Cform, IReadOnlyList<Row> Conduction, IReadOnlyList<Row> Attendance, IReadOnlyList<Row> Alignment, IReadOnlyList<Row> Met, IReadOnlyList<Row> Attended);

    internal sealed record Screen(Summary Summary, Stages Stages);

    internal static int MissedStreak(IReadOnlyList<string> cells)
    {
        var streak = 0;
        for (var i = cells.Count - 1; i >= 0 && cells[i] == "No"; i--)
        {
            streak++;
        }

        return streak;
    }

    internal static int QuietStreak(IReadOnlyList<bool> taught)
    {
        var streak = 0;
        for (var i = taught.Count - 1; i >= 0 && !taught[i]; i--)
        {
            streak++;
        }

        return streak;
    }

    internal static string? ConductionAction(int streak) => streak >= CallWeeks ? "call" : streak >= FlagWeeks ? "message" : null;

    /// <summary>PHP <c>recentWeeks</c>: the last <paramref name="count"/> weeks that end on or before <paramref name="lastEnd"/>; the position is the week's index among all the weeks (where its cell sits).</summary>
    internal static IReadOnlyList<WeekRef> RecentWeeks(IReadOnlyList<WeeklyGrid.Month> months, DateOnly lastEnd, int count)
    {
        var weeks = new List<WeekRef>();
        var position = 0;
        foreach (var days in months.SelectMany(m => m.Weeks))
        {
            if (days[^1] <= lastEnd)
            {
                weeks.Add(new WeekRef(days[0], days[^1], position));
            }

            position++;
        }

        return [.. weeks.Skip(Math.Max(0, weeks.Count - count))];
    }

    /// <summary>PHP <c>taughtFlags</c>: per class and subject (arabic, aqaed, ahkam, akhlaq) one flag per week; a class with no session in the window is absent.</summary>
    internal static Dictionary<int, Dictionary<string, bool[]>> TaughtFlags(IReadOnlyList<(int ClassId, DateOnly On, IReadOnlySet<string> Subjects)> sessions, IReadOnlyList<WeekRef> weeks)
    {
        var flags = new Dictionary<int, Dictionary<string, bool[]>>();
        foreach (var (classId, on, taught) in sessions)
        {
            if (!flags.TryGetValue(classId, out var bySubject))
            {
                bySubject = Subjects.ToDictionary(s => s, _ => new bool[weeks.Count]);
                flags[classId] = bySubject;
            }

            for (var i = 0; i < weeks.Count; i++)
            {
                if (on < weeks[i].Start || on > weeks[i].End)
                {
                    continue;
                }

                foreach (var subject in Subjects.Where(taught.Contains))
                {
                    bySubject[subject][i] = true;
                }
            }
        }

        return flags;
    }

    internal static readonly string[] Subjects = ["arabic", "aqaed", "ahkam", "akhlaq"];

    /// <summary>
    /// PHP <c>assemble</c>: the summary strip and the six lists. The cells of weeks that ended before the class started are "n/a" (they end a streak and flag nothing); a class whose newest cell is n/a is only in the alignment list.
    /// The conduction list is by streak, longest first, then class id (PHP's array_multisort compares the rows, whose first key is the class id).
    /// </summary>
    internal static Screen Assemble(IReadOnlyList<DateOnly> weekStarts, IReadOnlyList<ClassInput> classes, IReadOnlyDictionary<int, double> attendance)
    {
        var cform = new List<Row>();
        var conduction = new List<(int Streak, Row Row)>();
        var lowAttendance = new List<Row>();
        var alignment = new List<Row>();
        var met = new List<Row>();
        var attended = new List<Row>();
        var fractions = new List<double>();
        var flagged = new HashSet<int>();
        var (metCount, of, formsMissing) = (0, 0, 0);

        foreach (var c in classes)
        {
            var cells = CellsFromStart(c.Cells, weekStarts, c.StartedOn);
            alignment.Add(RowOf(c, string.Empty, null, [], keepMobile: true));
            var newest = cells.Count == 0 ? "n/a" : cells[^1];
            if (newest == "n/a")
            {
                continue;
            }

            var held = newest.StartsWith("Yes", StringComparison.Ordinal);
            if (newest == "NF")
            {
                formsMissing++;
                cform.Add(RowOf(c, "Form not submitted", "message", [], keepMobile: true));
                flagged.Add(c.Id);
            }
            else
            {
                of++;
                metCount += held ? 1 : 0;
                if (held)
                {
                    met.Add(RowOf(c, "Met", null, [], keepMobile: false));
                }
            }

            var streak = MissedStreak(cells);
            var action = ConductionAction(streak);
            var quiet = held ? QuietSubjects(c, cells) : [];
            if (action is not null || quiet.Count > 0)
            {
                var detail = action is not null ? "No class for " + streak.ToString(CultureInfo.InvariantCulture) + " weeks" : string.Empty;
                conduction.Add((streak, RowOf(c, detail, action ?? "message", quiet, keepMobile: true)));
                flagged.Add(c.Id);
            }

            if (!attendance.TryGetValue(c.Id, out var fraction))
            {
                continue;
            }

            fractions.Add(fraction);
            var percent = "Attendance " + Math.Round((decimal)(fraction * 100), 0, MidpointRounding.AwayFromZero).ToString(CultureInfo.InvariantCulture) + "%";
            attended.Add(RowOf(c, percent, null, [], keepMobile: false));
            if (fraction < LowAttendance)
            {
                lowAttendance.Add(RowOf(c, percent, "message", [], keepMobile: true));
                flagged.Add(c.Id);
            }
        }

        var average = fractions.Count == 0 ? (PhpFloat?)null : PhpFloat.Round((decimal)(fractions.Sum() / fractions.Count), 2);
        var ordered = conduction.OrderByDescending(x => x.Streak).ThenBy(x => x.Row.ClassId).Select(x => x.Row).ToList();
        return new Screen(new Summary(metCount, of, formsMissing, average, flagged.Count), new Stages(cform, ordered, lowAttendance, alignment, met, attended));
    }

    private static List<string> CellsFromStart(IReadOnlyList<string> cells, IReadOnlyList<DateOnly> weekStarts, DateOnly startedOn) =>
        [.. cells.Select((cell, i) => weekStarts[i].AddDays(6) < startedOn ? "n/a" : cell)];

    private static List<Quiet> QuietSubjects(ClassInput c, IReadOnlyList<string> cells)
    {
        var before = cells.Count(cell => cell == "n/a");
        var quiet = new List<Quiet>();
        foreach (var (subject, taught) in c.Subjects)
        {
            var weeks = QuietStreak(taught.Skip(before).ToArray());
            if (weeks >= FlagWeeks)
            {
                quiet.Add(new Quiet(subject, weeks));
            }
        }

        return quiet;
    }

    private static Row RowOf(ClassInput c, string detail, string? action, IReadOnlyList<Quiet> quiet, bool keepMobile) =>
        new(c.Id, c.Code, c.Level, c.Teacher, c.TeacherToken, keepMobile ? c.TeacherMobile : null, detail, action, quiet);
}
