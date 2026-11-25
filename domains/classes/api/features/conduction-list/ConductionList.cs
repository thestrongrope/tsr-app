using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.ConductionList;

// Slice: GET /classes/{class_id}/conduction?page&pageSize -> the class's conduction records for the teacher's screen, newest day first. Contract: spec/api.yaml.
// PHP: routes/conduction.php route_conduction_list (:235). Guards: active class (404), sessions:create on it (403, "manage this class"); no gender check.
// Copied quirks: no deleted_at filter, not-held sessions included; page = max(1, (int)), pageSize = min(100, max(1, (int))) default 20; totalPages is PHP's ceil() so JSON 3.0; editable is the ten-day window.

internal static class ConductionListSlice
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 100;
    private const long MaxPage = 1_000_000_000;

    internal sealed record Listing(ConductionData.ClassPayload Class, IReadOnlyList<ConductionData.SessionItem> Sessions, long TotalRecords, PhpFloat TotalPages, long Page);

    public static IEndpointRouteBuilder MapConductionList(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/classes/{class_id}/conduction", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(string class_id, HttpContext context, NpgsqlDataSource source, Permissions permissions, TimeProvider clock, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (head, refusal) = await ConductionData.OpenAsync(source, permissions, caller, class_id, "sessions:create", ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var page = Math.Min(MaxPage, Math.Max(1, ClassGuards.QueryInt(context, "page", 1)));
        var pageSize = Math.Min(MaxPageSize, Math.Max(1, ClassGuards.QueryInt(context, "pageSize", DefaultPageSize)));
        var offset = (page - 1) * pageSize;
        var classId = head!.Id;
        var ids = await source.ListAsync(
            $"""select id::bigint as "Value" from classes.class_sessions where class_id = {classId} order by conducted_on desc, id limit {pageSize} offset {offset}""",
            row => row.Long("Value"),
            ct);
        var total = (await source.ListAsync($"""select count(*) as "Value" from classes.class_sessions where class_id = {classId}""", row => row.Long("Value"), ct)).Single();
        var now = clock.GetUtcNow();
        var sessions = (await ConductionData.GetSessionsAsync(source, ids.ToArray(), ct)).Select(row => ConductionData.ToItem(row, now)).ToList();

        var header = await ConductionData.HeaderAsync(source, classId, ct);
        return Results.Json(new Listing(header, sessions, total, new PhpFloat(Math.Ceiling(total / (double)pageSize)), page), ClassesJson.Answers.ConductionListing);
    }
}
