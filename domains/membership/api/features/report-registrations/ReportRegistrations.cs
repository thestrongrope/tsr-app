using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ReportRegistrations;

// Slice: GET /reports/registrations?gender -> {gender, registrants[{id, token, name, status, registeredOn, requestedClass, email, mobile, residenceLocation, preferredLocation, workLocation, birthYear, classLevel,
// classNumber, profession, islamicStudyYears, interests, city, country, zip}]}: the people waiting to be placed in a class, newest first. Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_registrations (:1678, api_require_registrations_report :1696). The guard (registrations:read for the gender; NO row scope beyond the gender) and the query with every rule it copies are
// domain/WaitingRegistrations.cs (shared with the download).

internal static class ReportRegistrationsSlice
{
    internal sealed record Answer(int Gender, IReadOnlyList<WaitingRegistrations.Item> Registrants);

    public static IEndpointRouteBuilder MapReportRegistrations(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/registrations", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, MembershipContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var (gender, _, refusal) = await WaitingRegistrations.GuardAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var rows = await WaitingRegistrations.LoadAsync(db, gender, ct);
        return Results.Json(new Answer(gender, [.. rows.Select(WaitingRegistrations.ToItem)]));
    }
}
