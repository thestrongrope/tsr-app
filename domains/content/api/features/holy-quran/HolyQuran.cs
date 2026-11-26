using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
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

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, CancellationToken ct)
    {
        if (context.GetCaller() is null)
        {
            return Problem.Unauthenticated();
        }

        var surahs = await source.ListAsync(
            $"""
                select id as "Id", surah as "Surah", coalesce(arabic, '') as "Arabic", verses as "Verses"
                from content.holy_quran
                order by id
                limit {MaxRows}
                """,
            row => new SurahItem(row.Int("Id"), row.Text("Surah"), row.Text("Arabic"), row.Int("Verses")),
            ct);
        return Results.Json(surahs, ContentJson.Answers.SurahList);
    }
}
