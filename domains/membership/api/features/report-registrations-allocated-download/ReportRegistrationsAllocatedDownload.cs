using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.ReportRegistrationsAllocatedDownload;

// Slice: GET /reports/registrations/allocated/download?format=xlsx|pdf&gender -> everyone who registered and is placed in an active class, 25 columns (contact details, address, registration answers, the class, level and teacher placed with). Contract: spec/api.yaml.
// PHP: routes/reports.php route_reports_registrations_allocated_download (:1745), subscribers.php getAllocatedRegistrations (:495). Order as PHP: format (422, before the sign-in), sign-in, registrations:read for the gender (403, the gender locked as for the waiting list), then the rows.
// REACH, copied exactly: a super administrator or a gender administrator (reach all or by gender) gets every placed person of the gender, including open registrations (for no particular class); anyone else holding registrations:read (a coordinator) gets only
// "class registrations" (those naming a class) of people placed in THEIR assigned classes; with no assigned class, nobody. The rules, columns and quirks of the query are domain/AllocatedRegistrations.cs. The cells are PHP's raw model values (times as "YYYY-MM-DD HH:MM:SS",
// free texts not entity-decoded). No 404: nobody is a file with headers only. Title "Registrations placed in a class: Gents|Ladies", heading "Placed in a class, <today>", file "Registrations-placed-Gents|Ladies-<YYYYMMDD>.<format>" (UTC day). Writes nothing.

internal static class ReportRegistrationsAllocatedDownloadSlice
{
    private static readonly string[] Headers =
    [
        "Sr. No.", "Token", "Name", "Created On", "Gender", "Mobile", "Email", "Age Range", "City", "State", "Country", "Zip Code", "Registered On", "Last Modified On", "Residence Location",
        "Work Location", "Class Level", "Class Number", "Professional Expertise", "Interests", "Allocated Class", "Allocated Level", "Allocated Teacher Code", "Allocated Teacher", "Extra Students",
    ];

    public static IEndpointRouteBuilder MapReportRegistrationsAllocatedDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/reports/registrations/allocated/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, NpgsqlDataSource source, Permissions permissions, ReportExport export, TimeProvider clock, CancellationToken ct)
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

        var (gender, classIds, refusal) = await WaitingRegistrations.GuardAsync(context, permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var people = await AllocatedRegistrations.LoadAsync(source, gender, classOnly: classIds is not null, classIds, ct);

        IReadOnlyList<IReadOnlyList<object?>> rows = [.. people.Select((p, i) => Row(i + 1, p))];
        var day = clock.GetUtcNow().UtcDateTime;
        var name = gender == 2 ? "Ladies" : "Gents";
        var heading = "Placed in a class, " + day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        return await export.DownloadAsync(
            format, "Registrations placed in a class: " + name, [new ReportSection(heading, Headers, rows)], "Registrations-placed-" + name + "-" + day.ToString("yyyyMMdd", CultureInfo.InvariantCulture), ct);
    }

    private static IReadOnlyList<object?> Row(int number, AllocatedRegistrations.Row p) =>
    [
        number, p.Token, p.Name, p.UserCreated, AllocatedRegistrations.GenderLabel(p.Gender), p.Mobile, p.Email, AllocatedRegistrations.AgeRangeLabel(p.AgeRange), p.City, p.State, p.Country, p.Zip,
        p.CreatedAt, p.ModifiedAt, p.Residence, p.Work, p.ClassLevel, p.ClassNumber, p.Profession, AllocatedRegistrations.Interests(p.Interests, p.OtherInterests),
        p.ClassCode, p.AllocatedLevel, p.Teacher, p.TeacherName, AllocatedRegistrations.ExtraStudents(p.ExtraStudents),
    ];
}
