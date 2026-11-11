using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.SubscriberCard;

// Slice: GET /subscribers/{token} -> {token, name, gender, registeredOn, requestedClass}: a registered person who is in no class. Permission classes:read (403); then ONLY a caller whose
// classes:read reaches every class (Reach.All) gets a card: anyone else, a token of 0 or less, an unknown member or a member with a live enrolment in an active class is 404 "Person
// not found" (one answer for all, so it never says which). Carries no contact details. Contract: spec/api.yaml.
// PHP: routes/entity_cards.php route_subscribers_card, EntityAccessModel::subscriberCardFor. gender is genderOf (1 or Male, 2 or Female, else null). registeredOn is the day of the member's
// LATEST registration (highest id), requestedClass that registration's class code when the class still exists; both null without one. The student card (GET /students/{token}) is not
// built: it needs the class level name, which no published view carries.

internal static class SubscriberCardSlice
{
    private sealed record MemberRow(string? Name, string? Gender);

    private sealed record RegistrationRow(string? RegisteredOn, string? Code);

    public static IEndpointRouteBuilder MapSubscriberCard(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/subscribers/{token}", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    /// <summary>PHP EntityAccessModel::genderOf: "1" or "Male" is 1, "2" or "Female" is 2, anything else is not recorded.</summary>
    internal static int? GenderOf(string? stored) =>
        stored switch
        {
            "1" or "Male" => 1,
            "2" or "Female" => 2,
            _ => null,
        };

    private static async Task<IResult> HandleAsync(string token, HttpContext context, MembershipContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        if (!await permissions.CanAsync(caller, "classes:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var value = PhpValue.IntOfText(token);
        var reach = await permissions.ReachAsync(caller, "classes:read", ct);
        if (value is <= 0 or > int.MaxValue || !reach.All)
        {
            return NotFound();
        }

        var member = await FindMemberAsync(db, (int)value, ct);
        if (member is null || await InClassAsync(db, (int)value, ct))
        {
            return NotFound();
        }

        var registration = await LatestRegistrationAsync(db, (int)value, ct);
        return Results.Json(new Dictionary<string, object?>
        {
            ["token"] = value,
            ["name"] = member.Name ?? string.Empty,
            ["gender"] = GenderOf(member.Gender),
            ["registeredOn"] = registration?.RegisteredOn,
            ["requestedClass"] = string.IsNullOrEmpty(registration?.Code) ? null : registration.Code,
        });
    }

    private static async Task<MemberRow?> FindMemberAsync(MembershipContext db, int token, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<MemberRow>($"""
                select p.name as "Name", p.gender as "Gender" from identity.v_users u
                left join membership.member_profiles p on p.user_id = u.id
                where u.token = {token} order by u.id limit 1
                """)
            .ToListAsync(ct)).FirstOrDefault();

    private static async Task<bool> InClassAsync(MembershipContext db, int token, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<int>($"""
                select 1 as "Value" from classes.v_enrolments cs
                join classes.v_classes c on c.id = cs.class_id and c.status = 'A'
                where cs.token_no = {token} and cs.removed_at is null limit 1
                """)
            .ToListAsync(ct)).Count > 0;

    private static async Task<RegistrationRow?> LatestRegistrationAsync(MembershipContext db, int token, CancellationToken ct) =>
        (await db.Database
            .SqlQuery<RegistrationRow>($"""
                select to_char(cr.created_at at time zone 'UTC', 'YYYY-MM-DD') as "RegisteredOn", c.code as "Code"
                from membership.class_registrations cr
                left join classes.v_classes c on c.id = cr.for_classid
                where cr.token = {token} order by cr.id desc limit 1
                """)
            .ToListAsync(ct)).FirstOrDefault();

    private static IResult NotFound() => Problem.Detail(StatusCodes.Status404NotFound, "Person not found");
}
