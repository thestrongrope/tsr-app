using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Content.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Content.Api.Features.HolyQuran;

// Slice: GET /holy-quran -> the surahs in order. Any signed-in member (no permission, as PHP); a first sign-in creates the member's row.
// PHP: routes/conduction.php route_holy_quran (:227), HolyQuranModel::getAll. Contract: spec/api.yaml.

internal static class HolyQuranSlice
{
    /// <summary>Bound on one response (MUST 2); the table holds 114 rows.</summary>
    private const int MaxRows = 200;

    internal sealed record SurahItem(int Id, string Surah, string Arabic, int Verses);

    public static IEndpointRouteBuilder MapHolyQuran(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/holy-quran", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ContentContext db, CancellationToken ct)
    {
        if (context.GetCaller() is null)
        {
            return Problem.Unauthenticated();
        }

        var surahs = await db.HolyQuran.AsNoTracking()
            .OrderBy(s => s.Id)
            .Take(MaxRows)
            .Select(s => new SurahItem(s.Id, s.Surah, s.Arabic ?? string.Empty, s.Verses))
            .ToListAsync(ct);
        return Results.Json(surahs, ContentJson.Answers.SurahList);
    }
}
