using System.Globalization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Access.Api;
using Tsr.Membership.Api.Domain;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Features.AdminDonorsDownload;

// Slice: GET /admin/donors/download?format=xlsx|pdf -> the donors list as a file: Name, Email, Mobile, City, State, Country, Zip. Contract: spec/api.yaml.
// PHP: routes/donors.php route_admin_donors_download. Order as PHP: format (422, before the sign-in), sign-in, donors:read (403), then the SAME rows as GET /admin/donors (domain/DonorList.cs: every member in an active class, no reach limit: flagged in the
// membership notes), and 404 "There are no donors to download" when there are none (a file only when there is something to send). Title "Donors", heading "TSR Members (Donors), <today>", file "TSR_Donors_Export_<YYYYMMDD_HHMMSS>.<format>" (UTC, as PHP's
// server). The file carries email and mobile of every donor: that is PHP's reach, copied exactly. Writes nothing.

internal static class AdminDonorsDownloadSlice
{
    private static readonly string[] Headers = ["Name", "Email", "Mobile", "City", "State", "Country", "Zip"];

    public static IEndpointRouteBuilder MapAdminDonorsDownload(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/donors/download", HandleAsync).RequireMember(createsMember: true, precheck: ReportExport.FormatRefusal);
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

        if (!await permissions.CanAsync(caller, "donors:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var donors = await DonorList.LoadAsync(source, ct);
        if (donors.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status404NotFound, "There are no donors to download");
        }

        IReadOnlyList<IReadOnlyList<object?>> rows = [.. donors.Select(d => (IReadOnlyList<object?>)[d.Name, d.Email, d.Mobile, d.City, d.State, d.Country, d.Zip])];
        var now = clock.GetUtcNow().UtcDateTime;
        var heading = "TSR Members (Donors), " + now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        return await export.DownloadAsync(format, "Donors", [new ReportSection(heading, Headers, rows)], "TSR_Donors_Export_" + now.ToString("yyyyMMdd_HHmmss", CultureInfo.InvariantCulture), ct);
    }
}
