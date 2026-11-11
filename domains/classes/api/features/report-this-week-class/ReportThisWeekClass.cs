using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportThisWeekClass;

// Slice: GET /reports/this-week/class/{class_id} -> {classId, code, level, weeks[{from, to, status, subjects}], chart}: what one class taught in each of the last 8 weeks (newest first) and the Standard Syllabus Chart of its level
// (data/syllabus_topics.json, null for a level without one). Contract: spec/api.yaml.
// PHP: routes/this_week.php route_reports_this_week_class (:47), thisweek.php alignment and buildAlignment (AlignmentRules), mis.php reportableClass and classSessionsInRange. Guards: the gender and reports:read for it (403), then the
// class: active, and in the reportClasses of ITS OWN gender (reach, and the assigned classes for an assigned-only classes:read); anything else is 404 "Class not found". Queries: the class's gender, the scope's ids (that class), the
// class's code and level, its sessions of the 8 weeks (PHP: one per week for the gender's classes).
// Copied: the eight weeks are the Sunday weeks ending with the last completed week; a held session shows the topic written, "Conducted" when it taught the subject with no topic; weeks[].subjects is an object even when empty.

internal static class ReportThisWeekClassSlice
{
    private const int AlignmentWeeks = 8;
    private const int MaxSessions = 2000;
    private static readonly string[] Subjects = ["arabic", "aqaed", "ahkam", "akhlaq", "other"];

    internal sealed record Answer(int ClassId, string Code, string Level, IReadOnlyList<AlignmentRules.WeekItem> Weeks, JsonElement? Chart);

    private sealed record Head(string Code, string Level);

    private sealed record SessionRow(DateOnly ConductedOn, int Conducted, string Arabic, string Aqaed, string Ahkam, string Akhlaq, string Other);

    public static IEndpointRouteBuilder MapReportThisWeekClass(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/this-week/class/{class_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (_, refusal) = await ReportScope.OpenAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var classId = ClassGuards.IdOf(class_id);
        var genders = await db.Database
            .SqlQuery<int>($"""select coalesce(gender, 0) as "Value" from classes.classes where id = {classId} and status = 'A' limit 1""")
            .ToListAsync(ct);
        if (genders.Count == 0)
        {
            return NotFound();
        }

        var reach = await permissions.ReachAsync(caller, "reports:read", ct);
        var reachable = await ReportScope.KeepAssignedAsync(await ReportScope.Of(reach, genders[0]).ClassIdsAsync(db, classId, ct), permissions, caller, ct);
        var head = reachable.Length == 0 ? null : await HeadAsync(db, (int)classId, ct);
        if (head is null)
        {
            return NotFound();
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var (year, number) = ReportCalendar.LastCompleted(today);
        var last = ReportCalendar.Range(year, number);
        var weeks = new List<AlignmentRules.Week>();
        for (var i = AlignmentWeeks - 1; i >= 0 && last is not null; i--)
        {
            var start = last.Value.Min.AddDays(-7 * i);
            weeks.Add(new AlignmentRules.Week(start, start.AddDays(6)));
        }

        var sessions = weeks.Count == 0 ? [] : await SessionsAsync(db, (int)classId, weeks[0].Start, weeks[^1].End, ct);
        return Results.Json(new Answer((int)classId, head.Code, head.Level, AlignmentRules.Build(sessions, weeks), SyllabusCatalogue.For(head.Level)));
    }

    private static async Task<Head?> HeadAsync(ClassesContext db, int classId, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<Head>($"""
                select c.code::text as "Code", cl.name::text as "Level" from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id where c.id = {classId}
                """)
            .ToListAsync(ct)).FirstOrDefault();

    // PHP classSessionsInRange: every session of the weeks, held or not; a subject's topic only where it was taught in a held session.
    private static async Task<List<AlignmentRules.Session>> SessionsAsync(ClassesContext db, int classId, DateOnly from, DateOnly to, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<SessionRow>($"""
                select s.conducted_on as "ConductedOn", s.conducted::int as "Conducted",
                       case when s.conducted = 1 and s.arabic_conducted in ('1', 'Y') then coalesce(nullif(s.arabic_topic, ''), 'Conducted') else '' end as "Arabic",
                       case when s.conducted = 1 and s.aqaed_conducted in ('1', 'Y') then coalesce(nullif(s.aqaed_topic, ''), 'Conducted') else '' end as "Aqaed",
                       case when s.conducted = 1 and s.ahkam_conducted in ('1', 'Y') then coalesce(nullif(s.ahkam_topic, ''), 'Conducted') else '' end as "Ahkam",
                       case when s.conducted = 1 and s.akhlaq_conducted in ('1', 'Y') then coalesce(nullif(s.akhlaq_topic, ''), 'Conducted') else '' end as "Akhlaq",
                       case when s.conducted = 1 and s.other_conducted in ('1', 'Y') then coalesce(nullif(s.other_topic, ''), 'Conducted') else '' end as "Other"
                from classes.class_sessions s
                where s.class_id = {classId} and s.conducted_on >= {from} and s.conducted_on <= {to}
                order by s.conducted_on, s.id
                limit {MaxSessions}
                """)
            .ToListAsync(ct);
        return
        [
            .. rows.Select(r => new AlignmentRules.Session(
                r.ConductedOn,
                r.Conducted == 1,
                Subjects.Zip([r.Arabic, r.Aqaed, r.Ahkam, r.Akhlaq, r.Other]).Where(p => p.Second.Length > 0).ToDictionary(p => p.First, p => p.Second))),
        ];
    }

    private static IResult NotFound() => Problem.Detail(StatusCodes.Status404NotFound, "Class not found");
}
