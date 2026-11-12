using System.Globalization;
using Microsoft.AspNetCore.Http;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

// The pending report as data, for the screen (GET /reports/pending?gender&from&to&level, months MM-YYYY) and the download (its /download) -> {gender, from, to, levels, teachers[{teacherToken, teacher, notFilled, mcqPending, classes[{classId, level, class, notFilled, mcqPending, mcqConducted, mcqExpected}]}]}:
// per teacher, the class forms not filled in the months and the standard MCQs a teacher copied but did not conduct, teachers with something pending, most first.
// PHP: routes/reports.php api_require_pending_report (:785), mis.php pendingReport (:1453) and pendingByTeacher, classes.php getClassMcqAdherence (:1395, called once per class: about 200 queries).
// Queries: the class ids of the scope, the classes, the summary figures (SummaryRows: the "Not Filled" of the summary report), the MCQ figures of every class in one query (PHP: one per class): 4.
// Copied: the classes are those of PHP getAll (the reports:read reach, for an assigned-only classes:read only the assigned classes, a class must have a level; the teacher's name may be missing and is ""); a class's forms not filled are expected minus
// submitted of the summary (a class with no slot in a finished week has none); the MCQ figures ignore the months: standard MCQs not deleted of the class's level and language (language 1 when the class has none), each counted once per row, conducted = a copy
// with a publish time, pending = a copy without one (copies deactivated are ignored, the latest copy of a code counts); the level narrows after `levels` is listed and the totals are recounted; teachers order by forms, MCQs pending, lower-case name.
// Months default to last month and this month (UTC), at most 12 months.

internal static class PendingReport
{
    internal sealed record Loaded(int Gender, string From, string To, IReadOnlyList<string> Levels, IReadOnlyList<PendingRules.PendingTeacher> Teachers);

    public static async Task<(Loaded? Report, IResult? Refusal)> OpenAsync(HttpContext context, ClassesContext db, Permissions permissions, Caller caller, DateOnly today, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return (null, refusal);
        }

        var from = ReportMonths.Param(context, "from") ?? Month(new DateOnly(today.Year, today.Month, 1).AddMonths(-1));
        var to = ReportMonths.Param(context, "to") ?? Month(today);
        var invalid = ReportMonths.Check(from, to, limitToTwelve: true);
        if (invalid is not null)
        {
            return (null, Problem.Detail(StatusCodes.Status422UnprocessableEntity, invalid));
        }

        var ids = await ReportScope.KeepAssignedAsync(await scope!.ClassIdsAsync(db, 0, ct), permissions, caller, ct);
        var classes = await ReportClasses.ForIdsAsync(db, ids, ct);
        var summary = await SummaryRows.ForMonthsAsync(db, ids, from, to, today, ct);
        var notFilled = summary.ToDictionary(r => r.Id, r => r.Expected - r.Submitted);
        var mcqs = (await McqAdherence.FiguresAsync(db, ids, ct)).ToDictionary(r => r.ClassId, r => new PendingRules.Mcq(r.Expected, r.Conducted, r.Pending));

        var teachers = PendingRules.Group(classes, notFilled, mcqs);
        var levels = teachers.SelectMany(t => t.Classes).Select(c => c.Level).Distinct().ToList();
        var level = ReportScope.LevelOf(context);
        return (new Loaded(scope.Gender, from, to, levels, level.Length == 0 ? teachers : PendingRules.InLevel(teachers, level)), null);
    }

    private static string Month(DateOnly day) => day.ToString("MM-yyyy", CultureInfo.InvariantCulture);
}
