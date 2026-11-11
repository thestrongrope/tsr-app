using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ReportRegistrationsDownload;

// Slice: GET /reports/registrations/download?format=xlsx|pdf&gender -> the people waiting to be placed in a class, newest first, numbered, with the web download's columns (email, mobile and address included, as the screen's details panel shows them). Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_registrations_download (:1710). Order as PHP: format (422, before the sign-in), sign-in, registrations:read for the gender (403), then the SAME people as the screen (domain/WaitingRegistrations.cs: no row scope beyond the gender).
// The cells are PHP's raw model values (the full creation time "YYYY-MM-DD HH:MM:SS", free texts not entity-decoded, years as numbers), unlike the screen's cast values. No 404: nobody waiting is a file with headers only.
// Title "Registrations: Gents|Ladies", heading "Waiting to be placed, <today>", file "Registrations-Gents|Ladies-<YYYYMMDD>.<format>" (UTC day, as PHP's server). Writes nothing.

internal static class ReportRegistrationsDownloadSlice
{
    private static readonly string[] Headers =
    [
        "Sr. No.", "Token", "Name", "Created On", "For Class", "Email", "Mobile", "Location", "Birth Year / Age", "Profession", "Islamic Study", "City", "Country", "Pincode",
    ];

    public static IEndpointRouteBuilder MapReportRegistrationsDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/registrations/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, MembershipContext db, Permissions permissions, ReportExport export, TimeProvider clock, CancellationToken ct)
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

        var (gender, refusal) = await WaitingRegistrations.GuardAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var people = await WaitingRegistrations.LoadAsync(db, gender, ct);
        IReadOnlyList<IReadOnlyList<object?>> rows = [.. people.Select((p, i) => Row(i + 1, p))];
        var day = clock.GetUtcNow().UtcDateTime;
        var name = gender == 2 ? "Ladies" : "Gents";
        var heading = "Waiting to be placed, " + day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        return await export.DownloadAsync(format, "Registrations: " + name, [new ReportSection(heading, Headers, rows)], "Registrations-" + name + "-" + day.ToString("yyyyMMdd", CultureInfo.InvariantCulture), ct);
    }

    private static IReadOnlyList<object?> Row(int number, WaitingRegistrations.Row p) =>
        [number, p.Token, p.Name, p.CreatedAt, p.ForClass, p.Email, p.Mobile, p.Preferred, p.BirthYear, p.Profession, p.IslamicYears, p.City, p.Country, p.Zip];
}
