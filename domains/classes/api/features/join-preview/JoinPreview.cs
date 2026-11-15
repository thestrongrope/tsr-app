using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.JoinPreview;

// Slice: GET /join/{code} (PUBLIC, no sign-in: the app shows it before sign-in; only what the web join page shows, never the teacher, counts or ids) -> the class a join link names. Contract: spec/api.yaml.
// PHP: routes/classes.php route_join_preview (:101), ClassesModel::getForJoinPage. Order: 30 calls a minute per client address (429 "Too many requests; try again later"; in memory here, PHP's file counter; a
// SHA-256 of the address folded to the limiter's integer key), the code is 1 to 32 letters or digits (else a bare 404 "Not Found"), the class with that link (case-insensitive) that is not deactivated (else 404).
// Answer {name, level, language (English, Urdu, Gujarati by language_id, else ""), gender (platform's genders name), open (status A)}. A deactivated class has deleted_at, so it is a 404, never "closed".

internal static partial class JoinPreviewSlice
{
    private static readonly string[] Languages = ["", "English", "Urdu", "Gujarati"];

    private sealed record Row(string? Name, string? Status, int? LanguageId, string? Level, string? GenderName);

    [GeneratedRegex("^[A-Za-z0-9]{1,32}$", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking)]
    private static partial Regex CodeShape();

    public static IEndpointRouteBuilder MapJoinPreview(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/join/{code}", HandleAsync);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string code, HttpContext context, ClassesContext db, MemberRateLimit limit, CancellationToken ct)
    {
        var address = ClientAddress.Of(context);
        if (!limit.Allow("join_preview", KeyOf(address), 30, 60))
        {
            return Problem.Detail(StatusCodes.Status429TooManyRequests, "Too many requests; try again later");
        }

        if (!CodeShape().IsMatch(code))
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Not Found");
        }

        var rows = await db.Database
            .SqlQuery<Row>($"""
                select c.name as "Name", c.status as "Status", c.language_id as "LanguageId", cl.name as "Level", g.name as "GenderName"
                from classes.classes c
                left join classes.class_levels cl on cl.id = c.class_level_id
                left join platform.v_genders g on g.id = c.gender
                where c.link = {code}::citext and c.deleted_at is null
                limit 1
                """)
            .ToListAsync(ct);
        if (rows.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Not Found");
        }

        var row = rows[0];
        var language = row.LanguageId is >= 1 and <= 3 ? Languages[row.LanguageId.Value] : string.Empty;
        return Results.Json(new Dictionary<string, object?>
        {
            ["name"] = PhpText.HtmlDecode(row.Name ?? string.Empty),
            ["level"] = row.Level ?? string.Empty,
            ["language"] = language,
            ["gender"] = row.GenderName ?? string.Empty,
            ["open"] = row.Status == "A",
        });
    }

    private static int KeyOf(string address) => BitConverter.ToInt32(SHA256.HashData(Encoding.UTF8.GetBytes(address)), 0);
}
