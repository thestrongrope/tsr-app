using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.RegistrationGet;

// Slice: GET /registration -> the member's saved class request, the interest list, their choices and languages.
// Signed in, no permission (PHP checks none). Contract: spec/api.yaml. PHP: routes/registration.php route_registration_get.

internal static class RegistrationGetEndpoint
{
    public static IEndpointRouteBuilder MapRegistrationGet(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/registration",
            (HttpContext context, RegistrationGetHandler handler) => handler.HandleAsync(context.GetCaller(), context.RequestAborted))
            .RequireMember(createsMember: true);
        return routes;
    }
}

internal sealed class RegistrationGetHandler(MembershipContext db)
{
    /// <summary>A safety bound on each list; the form has 19 options and a member has a handful of choices and skills.</summary>
    private const int MaxRows = 500;

    public async Task<IResult> HandleAsync(Caller? caller, CancellationToken ct)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var token = caller.Token;

        // PHP's fetch() takes the table's first row for the token (no ORDER BY; the table holds duplicates): the lowest id.
        var registration = await db.ClassRegistrations.AsNoTracking()
            .Where(r => r.Token == token)
            .OrderBy(r => r.Id)
            .FirstOrDefaultAsync(ct);

        var options = await db.InterestOptions.AsNoTracking()
            .Where(o => o.IsActive)
            .OrderBy(o => o.SortOrder).ThenBy(o => o.Name)
            .Select(o => new { o.Id, o.Name })
            .Take(MaxRows)
            .ToListAsync(ct);

        var selected = await db.StudentInterests.AsNoTracking()
            .Where(s => s.Token == token)
            .Join(db.InterestOptions, s => s.InterestId, o => o.Id, (s, _) => s.InterestId)
            .OrderBy(id => id)
            .Take(MaxRows)
            .ToListAsync(ct);

        var languages = await db.RegistrationLanguages.AsNoTracking()
            .Where(l => l.Token == token)
            .OrderBy(l => l.Id)
            .Select(l => new LanguageEntry(l.Language ?? string.Empty, l.Skill ?? string.Empty, l.Proficiency ?? string.Empty))
            .Take(MaxRows)
            .ToListAsync(ct);

        return Results.Json(new JsonObject
        {
            ["registration"] = registration is null ? null : RegistrationView.Payload(registration),
            ["interestOptions"] = new JsonArray(options.Select(o => (JsonNode)new JsonObject { ["id"] = o.Id, ["name"] = o.Name }).ToArray()),
            ["selectedInterestIds"] = new JsonArray(selected.Select(id => (JsonNode)id).ToArray()),
            ["languages"] = RegistrationView.Languages(languages),
        });
    }
}
