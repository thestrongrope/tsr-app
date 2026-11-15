using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ConductionNew;

// Slice: GET /classes/{class_id}/conduction/new -> the data of the new-record form: the class and roster, the last and next session days, the latest topics and surah, the surah list. Contract: spec/api.yaml.
// PHP: routes/conduction.php route_conduction_new (:331), SessionsModel getLastSessionDate, getNextSessionDate, getLatestTopicsForClass, getLatestSurahForClass. Guards: active class (404), sessions:create (403).
// Copied quirks: lastSessionDate is the newest session of any kind, else the class's start day, else null (raw, never today); nextSessionDate counts schedule rows of every state and a class with no schedule gets 7 minus the weekday
// (PHP reads an undefined index); futureDate is the next day only when it is after today; the latest topics are the newest non-blank trimmed topic of each subject among HELD sessions (day, then id, descending).

internal static class ConductionNewSlice
{
    private const int MaxSessions = 5000;

    internal sealed record Topics(string? ArabicTopic, string? AqaedTopic, string? AhkamTopic, string? AkhlaqTopic, string? OtherTopic);

    internal sealed record FormData(
        ConductionData.ClassPayload Class,
        string? LastSessionDate,
        string? NextSessionDate,
        string? FutureDate,
        Topics LatestTopics,
        int? LatestSurah,
        IReadOnlyList<ConductionData.Surah> HolyQuran);

    private sealed record TopicRow(string? Arabic, string? Aqaed, string? Ahkam, string? Akhlaq, string? Other);

    public static IEndpointRouteBuilder MapConductionNew(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/conduction/new", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (head, refusal) = await ConductionData.OpenAsync(db, permissions, caller, class_id, "sessions:create", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var classId = head!.Id;
        var today = ConductionData.Today(clock);
        var last = await LastSessionDayAsync(db, classId, ct);
        var days = await db.Database
            .SqlQuery<int>($"""select day::int as "Value" from classes.class_schedules where class_id = {classId} order by day, id limit {MaxSessions}""")
            .ToListAsync(ct);
        var next = ConductionRules.NextSessionDate(last, today, days);
        var latestSurah = await db.Database
            .SqlQuery<int>($"""
                select quran_recitation_surah as "Value" from classes.class_sessions
                where class_id = {classId} and conducted = 1 and quran_recitation_surah > 0
                order by conducted_on desc, id desc
                limit 1
                """)
            .ToListAsync(ct);
        return Results.Json(new FormData(
            await ConductionData.HeaderAsync(db, classId, ct),
            last is null ? null : ConductionData.DayText(last.Value),
            ConductionData.DayText(next),
            next > today ? ConductionData.DayText(next) : null,
            await LatestTopicsAsync(db, classId, ct),
            latestSurah.Count == 0 ? null : latestSurah[0],
            await ConductionData.HolyQuranAsync(db, ct)));
    }

    private static async Task<DateOnly?> LastSessionDayAsync(ClassesContext db, int classId, CancellationToken ct)
    {
        var days = await db.Database
            .SqlQuery<DateOnly>($"""select conducted_on as "Value" from classes.class_sessions where class_id = {classId} order by conducted_on desc limit 1""")
            .ToListAsync(ct);
        if (days.Count > 0)
        {
            return days[0];
        }

        var started = await db.Database
            .SqlQuery<DateOnly?>($"""select started_on as "Value" from classes.classes where id = {classId}""")
            .SingleAsync(ct);
        return started;
    }

    private static async Task<Topics> LatestTopicsAsync(ClassesContext db, int classId, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<TopicRow>($"""
                select arabic_topic as "Arabic", aqaed_topic as "Aqaed", ahkam_topic as "Ahkam", akhlaq_topic as "Akhlaq", other_topic as "Other"
                from classes.class_sessions
                where class_id = {classId} and conducted = 1
                order by conducted_on desc, id desc
                limit {MaxSessions}
                """)
            .ToListAsync(ct);
        return new Topics(
            Newest(rows.Select(r => r.Arabic)),
            Newest(rows.Select(r => r.Aqaed)),
            Newest(rows.Select(r => r.Ahkam)),
            Newest(rows.Select(r => r.Akhlaq)),
            Newest(rows.Select(r => r.Other)));
    }

    private static string? Newest(IEnumerable<string?> topics)
    {
        foreach (var topic in topics)
        {
            var trimmed = topic is null ? string.Empty : PhpText.Trim(topic);
            if (trimmed.Length > 0)
            {
                return trimmed;
            }
        }

        return null;
    }
}
