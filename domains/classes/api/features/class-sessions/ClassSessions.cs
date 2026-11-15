using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ClassSessions;

// Slice: GET /classes/{class_id}/sessions?page&pageSize -> the class's sessions, newest day first, as a bare array. Contract: spec/api.yaml.
// PHP: routes/classes.php route_class_sessions (classes.php:337). Guards: gender set (400), class active (404), classes:read on the class (403).
// A subject flag is true for '1' or 'Y' (PHP's API writes 0/1, the web form Y/N; the column is citext, so 'y' too). Copied quirks: no deleted_at filter and not-conducted sessions are included; page = max(1, (int)), pageSize = min(100, max(1, (int))) default 20.

internal static class ClassSessionsSlice
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 100;
    private const long MaxPage = 1_000_000_000;

    internal sealed record Session(
        int Id,
        DateOnly ConductedOn,
        bool Conducted,
        int? Duration,
        int? Attendance,
        bool ArabicConducted,
        bool AqaedConducted,
        bool AhkamConducted,
        bool AkhlaqConducted,
        bool OtherConducted,
        string? ArabicTopic,
        string? AqaedTopic,
        string? AhkamTopic,
        string? AkhlaqTopic,
        string? OtherTopic,
        string? NonConductionReason);

    // The wire form: a date is Y-m-d and an empty text is null (PHP api_cast).
    internal sealed record Item(
        int Id,
        string ConductedOn,
        bool Conducted,
        int? Duration,
        int? Attendance,
        bool ArabicConducted,
        bool AqaedConducted,
        bool AhkamConducted,
        bool AkhlaqConducted,
        bool OtherConducted,
        string? ArabicTopic,
        string? AqaedTopic,
        string? AhkamTopic,
        string? AkhlaqTopic,
        string? OtherTopic,
        string? NonConductionReason);

    public static IEndpointRouteBuilder MapClassSessions(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/sessions", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await ClassGuards.HasNumericGenderAsync(db, caller, ct))
        {
            return Refusals.GenderNotSet();
        }

        var head = await ClassGuards.FindActiveClassAsync(db, ClassGuards.IdOf(class_id), ct);
        if (head is null)
        {
            return Refusals.ClassNotFound();
        }

        if (!await permissions.CanAsync(caller, "classes:read", AccessTarget.ForClass(head.Id), ct))
        {
            return Refusals.NotPermitted();
        }

        var page = Math.Min(MaxPage, Math.Max(1, ClassGuards.QueryInt(context, "page", 1)));
        var pageSize = Math.Min(MaxPageSize, Math.Max(1, ClassGuards.QueryInt(context, "pageSize", DefaultPageSize)));
        var offset = (page - 1) * pageSize;
        var rows = await db.Database
            .SqlQuery<Session>($"""
                select id as "Id", conducted_on as "ConductedOn", conducted = 1 as "Conducted", duration as "Duration", attendance as "Attendance",
                       arabic_conducted in ('1', 'Y') as "ArabicConducted", aqaed_conducted in ('1', 'Y') as "AqaedConducted", ahkam_conducted in ('1', 'Y') as "AhkamConducted",
                       akhlaq_conducted in ('1', 'Y') as "AkhlaqConducted", other_conducted in ('1', 'Y') as "OtherConducted",
                       arabic_topic as "ArabicTopic", aqaed_topic as "AqaedTopic", ahkam_topic as "AhkamTopic", akhlaq_topic as "AkhlaqTopic",
                       other_topic as "OtherTopic", non_conduction_reason as "NonConductionReason"
                from classes.class_sessions
                where class_id = {head.Id}
                order by conducted_on desc, id
                limit {pageSize} offset {offset}
                """)
            .ToListAsync(ct);
        return Results.Json(rows.Select(ToItem).ToList());
    }

    private static Item ToItem(Session s) => new(
        s.Id,
        s.ConductedOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
        s.Conducted,
        s.Duration,
        s.Attendance,
        s.ArabicConducted,
        s.AqaedConducted,
        s.AhkamConducted,
        s.AkhlaqConducted,
        s.OtherConducted,
        Text(s.ArabicTopic),
        Text(s.AqaedTopic),
        Text(s.AhkamTopic),
        Text(s.AkhlaqTopic),
        Text(s.OtherTopic),
        Text(s.NonConductionReason));

    private static string? Text(string? value) => string.IsNullOrEmpty(value) ? null : value;
}
