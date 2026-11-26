using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.GuideUpdate;

// Slice: PUT /guides/{level_id} {guide} -> replace the English guide of a level; answers {guide}. Permission guides:manage. Contract: spec/api.yaml.
// PHP: routes/guides.php route_guide_save (guides.php:56), GuidesModel::update. Order: guides:manage (403), the level has a guide page (2 to 5, else 404 "Level not found"), body (422), guide is a non-blank
// string (422 "guide must be the guide text"), at most 65535 bytes (422 "guide is too long to save"). One upsert on (level, language 1) that sets only the text, as PHP.
// Deviation: a NUL byte in the guide is a 422 (PostgreSQL text cannot hold it; PHP stores it). Event: classes.guide_saved (outbox). PHP also touches the search index; the event covers it.

internal static class GuideUpdateSlice
{
    private const int MaxBytes = 65535;

    internal sealed record GuideSaved(int LevelId, int LanguageId, int ChangedBy);

    public static IEndpointRouteBuilder MapGuideUpdate(this IEndpointRouteBuilder routes)
    {
        routes.MapPut("/guides/{level_id}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string level_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "guides:manage", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var levelId = (int)Math.Clamp(ClassGuards.IdOf(level_id), int.MinValue, int.MaxValue);
        if (GuideSlugs.ForLevel(levelId) is null)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "Level not found");
        }

        var (body, refusal) = await RequestBodies.ReadAsync(context.Request, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var raw = body!.Get("guide");
        if (raw.ValueKind != JsonValueKind.String || PhpText.Trim(raw.GetString()!).Length == 0)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "guide must be the guide text");
        }

        var guide = raw.GetString()!;
        if (Encoding.UTF8.GetByteCount(guide) > MaxBytes)
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "guide is too long to save");
        }

        if (guide.Contains('\0'))
        {
            return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "guide must not contain a NUL byte");
        }

        await using var tx = await source.BeginAsync(ct);
        await tx.ExecuteAsync(
            $"""
            insert into classes.guides (level_id, language_id, guide) values ({levelId}, 1, {guide})
            on conflict (level_id, language_id) do update set guide = excluded.guide
            """,
            ct);
        await Outbox.WriteAsync(tx, "classes.guide_saved", new GuideSaved(levelId, 1, caller.Token), ClassesJson.Default.GuideSaved, clock, ct);
        await tx.CommitAsync(ct);
        return Results.Json(new Dictionary<string, object?> { ["guide"] = guide }, ClassesJson.Answers.Answer);
    }
}
