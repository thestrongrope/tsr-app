using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportQuranLeaderboard;

// Slice: GET /reports/quran-leaderboard?gender&from&to&level&minimum -> {gender, from, to, levels[], total, students[{rank, name, token, class, recitation}]}: the top 100 rows of the recitation ranking (days YYYY-MM-DD, default the last year;
// at most five years; level by name; minimum recitations, whole number from 0, else 1). Permission quran-leaderboard:read for the gender (its own gender lock, not reports:read). Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_quran_leaderboard (:1629, api_require_quran_leaderboard :1588), QuranRecitationModel::getLeaderboardData. The guard, the parameters and the ranking query (global ranks, a member in two classes twice, no demo-class exclusion)
// are domain/QuranLeaderboard.cs (shared with the download and the students report). total counts every ranked row, not only the top 100.

internal static class ReportQuranLeaderboardSlice
{
    internal sealed record Student(long Rank, string Name, long Token, string Class, long Recitation);

    internal sealed record Answer(int Gender, string From, string To, IReadOnlyList<string> Levels, long Total, IReadOnlyList<Student> Students);

    public static IEndpointRouteBuilder MapReportQuranLeaderboard(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/quran-leaderboard", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource db, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var (report, refusal) = await QuranLeaderboard.OpenAsync(context, db, permissions, caller, today, QuranLeaderboard.TopRows, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var students = report!.Rows.Select(r => new Student(r.Rank, r.Name ?? string.Empty, r.Token, r.Class, r.Total)).ToList();
        return Results.Json(new Answer(report.Gender, report.From, report.To, report.Levels, report.Total, students), ClassesJson.Answers.ReportQuranLeaderboard);
    }
}
