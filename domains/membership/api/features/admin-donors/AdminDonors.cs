using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.AdminDonors;

// Slice: GET /admin/donors -> {donors: [{name, email, mobile, city, state, country, zip}]}: every member in an active class, ordered by name. Permission donors:read. Contract: spec/api.yaml.
// PHP: routes/donors.php route_admin_donors, SubscribersModel::getDonorList. Quirks copied: one row per (enrolment row, holder of the token): NO distinct, so a member in two classes appears
// twice; no reach limit (PHP applies none: every donors:read holder sees every member's contact details, flagged); every column is api_cast "text?" (entities decoded, empty is null).
// Deviation: at most 50000 rows (PHP returns all). The file download of the same list (xlsx or pdf) waits for the export library (batch B5).

internal static class AdminDonorsSlice
{
    public const int MaxRows = 50_000;

    internal sealed record Donor(string? Name, string? Email, string? Mobile, string? City, string? State, string? Country, string? Zip);

    public static IEndpointRouteBuilder MapAdminDonors(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/donors", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, MembershipContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "donors:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var rows = await db.Database
            .SqlQuery<Donor>($"""
                select m.name as "Name", u.email as "Email", m.mobile as "Mobile", m.city as "City", m.state as "State", m.country as "Country", m.zip as "Zip"
                from membership.v_members m
                join identity.v_users u on u.id = m.user_id
                join classes.v_enrolments cs on cs.token_no = m.token
                join classes.v_classes c on c.id = cs.class_id
                where cs.removed_at is null and c.status = 'A'
                order by m.name
                limit {MaxRows}
                """)
            .ToListAsync(ct);
        var donors = rows.Select(d => new Dictionary<string, object?>
        {
            ["name"] = Text(d.Name),
            ["email"] = Text(d.Email),
            ["mobile"] = Text(d.Mobile),
            ["city"] = Text(d.City),
            ["state"] = Text(d.State),
            ["country"] = Text(d.Country),
            ["zip"] = Text(d.Zip),
        }).ToList();
        return Results.Json(new Dictionary<string, object?> { ["donors"] = donors });
    }

    // api_cast "text?": null or empty is null, else the HTML entities decoded.
    private static string? Text(string? value) => string.IsNullOrEmpty(value) ? null : PhpText.HtmlDecode(value);
}
