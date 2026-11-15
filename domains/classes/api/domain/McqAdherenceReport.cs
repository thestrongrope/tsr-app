using System.Globalization;
using Microsoft.AspNetCore.Http;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

// The MCQ adherence report as data, for the list (GET /reports/mcq-adherence?gender), one class (/{class_id}), the CSV of every class (/download-all?classIds) and the class's file (/{class_id}/download).
// PHP: routes/reports.php api_require_mcq_adherence_report (:1415), mis.php mcqAdherenceReport (:1567) and mcqAdherenceCsv (:658), classes.php getClassMcqAdherence (:1395, once per class in PHP).
// Queries: the class ids of the scope, the classes, the figures of every class (McqAdherence.FiguresAsync, the pending report's query) = 3; the list of MCQs (McqAdherence.ItemsAsync, one query for all classes) only for the class routes and the CSV = 4.
// Copied: the classes are those of PHP getAll narrowed to the reports:read reach (a class must have a level; the teacher's name may be missing); a class with no standard MCQ is left out; worst adherence first, ties in class order (gender, level order, id);
// {class_id} is cast as PHP's (int): 0 or a word means NO narrowing, so the class routes answer with the first class of the whole report (the worst one); a class out of reach or with no MCQs answers as a class with none.

internal static class McqAdherenceReport
{
    internal sealed record Line(int ClassId, string Class, string Level, string? Teacher, string Location, int Expected, int Conducted, int Pending, int Skipped, PhpFloat AdherencePercent);

    internal sealed record Loaded(int Gender, IReadOnlyList<Line> Lines);

    /// <summary>One class's figures and every standard MCQ of it (all zero and none for a class the caller does not reach or one with no standard MCQ).</summary>
    internal sealed record ClassView(int Expected, int Conducted, int Pending, int Skipped, PhpFloat AdherencePercent, IReadOnlyList<McqAdherence.Item> Items);

    public static async Task<(Loaded? Report, IResult? Refusal)> OpenAsync(HttpContext context, ClassesContext db, Permissions permissions, Caller caller, long classId, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        var (scope, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return (null, refusal);
        }

        var ids = await ReportScope.KeepAssignedAsync(await scope!.ClassIdsAsync(db, classId, ct), permissions, caller, ct);
        var classes = await ReportClasses.ForIdsAsync(db, ids, ct);
        var figures = (await McqAdherence.FiguresAsync(db, ids, ct)).ToDictionary(f => f.ClassId);
        var lines = classes
            .Where(c => figures.ContainsKey(c.Id))
            .Select(c => ToLine(c, figures[c.Id]))
            .OrderBy(l => l.AdherencePercent.Value)
            .ToList();
        return (new Loaded(scope.Gender, lines), null);
    }

    /// <summary>The first class of the report with its MCQs (PHP <c>$r['report'][0]</c>); the empty class when there is none.</summary>
    public static async Task<ClassView> FirstClassAsync(ClassesContext db, Loaded report, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(report);
        var first = report.Lines.Count == 0 ? null : report.Lines[0];
        if (first is null)
        {
            return new ClassView(0, 0, 0, 0, new PhpFloat(0), []);
        }

        var items = await McqAdherence.ItemsAsync(db, [first.ClassId], ct);
        return new ClassView(first.Expected, first.Conducted, first.Pending, first.Skipped, first.AdherencePercent, items);
    }

    /// <summary>PHP <c>mcqAdherenceCsv</c>: a row per standard MCQ of every class (or only those of <paramref name="asked"/> when it is not empty), or null when there is none.</summary>
    public static async Task<string?> CsvAsync(ClassesContext db, Loaded report, IReadOnlyCollection<long> asked, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(report);
        var lines = report.Lines.Where(l => asked.Count == 0 || asked.Contains(l.ClassId)).ToList();
        if (lines.Count == 0)
        {
            return null;
        }

        var items = (await McqAdherence.ItemsAsync(db, [.. lines.Select(l => l.ClassId)], ct)).ToLookup(i => i.ClassId);
        var rows = lines
            .SelectMany(l => items[l.ClassId].Select(i => (IReadOnlyList<string?>)
            [
                l.Class, l.Level, l.Teacher ?? string.Empty, l.Location, Text(l.Expected), Text(l.Conducted), Text(l.Pending), Text(l.Skipped), Text(l.AdherencePercent),
                i.Code, i.Topic, i.Subject, i.Lesson, i.Name, i.Status, i.PublishedAt?.UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture),
            ]))
            .ToList();
        return ReportCsv.Build(CsvHeaders, rows);
    }

    /// <summary>PHP's float to text: 50.0 is "50", 33.3 is "33.3".</summary>
    public static string Text(PhpFloat value) => value.Value.ToString(CultureInfo.InvariantCulture);

    private static readonly string[] CsvHeaders =
    [
        "Class Code", "Level", "Teacher", "Location", "Expected", "Conducted", "Pending", "Skipped", "Adherence %", "MCQ Code", "Topic", "Subject", "Lesson", "MCQ Name", "Status", "Published At",
    ];

    private static string Text(int value) => value.ToString(CultureInfo.InvariantCulture);

    private static Line ToLine(PendingRules.ClassRow c, McqAdherence.Figures f) =>
        new(c.Id, c.Code, c.Level, c.TeacherName.Length == 0 ? null : c.TeacherName, c.Location, f.Expected, f.Conducted, f.Pending, f.Expected - f.Conducted - f.Pending, McqAdherence.Percent(f.Conducted, f.Expected));
}
