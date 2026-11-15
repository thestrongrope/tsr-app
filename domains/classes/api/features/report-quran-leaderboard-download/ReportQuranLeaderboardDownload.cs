using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ReportQuranLeaderboardDownload;

// Slice: GET /reports/quran-leaderboard/download?format=xlsx|pdf&gender&from&to&level&minimum -> every ranked row (not only the top 100) as a file: Rank, Name, Token, Class, Recitation. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_quran_leaderboard_download (:1649). Order as PHP: format (422, before the sign-in), sign-in, quran-leaderboard:read for the gender (403), dates (422), level (422), then the same rows as the screen
// (domain/QuranLeaderboard.cs, no limit; at most 50000). No 404: no row is a file with headers only. Numbers stay numbers. Title "Quran recitation leaderboard: Gents|Ladies, <from> to <to>", file "Quran-leaderboard-Gents|Ladies-<from>-to-<to>.<format>". Writes nothing.

internal static class ReportQuranLeaderboardDownloadSlice
{
    private static readonly string[] Headers = ["Rank", "Name", "Token", "Class", "Recitation"];

    public static IEndpointRouteBuilder MapReportQuranLeaderboardDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/quran-leaderboard/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, ReportExport export, TimeProvider clock, CancellationToken ct)
    {
        if (!ReportExport.TryGetFormat(context, out var format))
        {
            return ReportExport.FormatRefusal(context)!;
        }

        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var today = DateOnly.FromDateTime(clock.GetUtcNow().UtcDateTime);
        var (report, refusal) = await QuranLeaderboard.OpenAsync(context, db, permissions, caller, today, null, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        IReadOnlyList<IReadOnlyList<object?>> rows = [.. report!.Rows.Select(r => (IReadOnlyList<object?>)[r.Rank, r.Name ?? string.Empty, r.Token, r.Class, r.Total])];
        var gender = report.Gender == 2 ? "Ladies" : "Gents";
        var period = report.From + " to " + report.To;
        return await export.DownloadAsync(format, $"Quran recitation leaderboard: {gender}, {period}", [new ReportSection(period, Headers, rows)], $"Quran-leaderboard-{gender}-{report.From}-to-{report.To}", ct);
    }
}
