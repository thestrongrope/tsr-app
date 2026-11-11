using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>
/// What the app tells us about itself on every request, recorded on the member's row (PHP's
/// api_update_login_info). An empty value is skipped so a missing header never blanks a stored one.
/// Values are cut to their column's length (PHP's strict database would refuse the whole update instead).
/// </summary>
internal sealed record LoginTracking(string? Ip, string? UserAgent, string? Device, string? Platform, string? Version)
{
    /// <summary>False when every value is empty: PHP then writes nothing at all, not even the last sign-in time.</summary>
    public bool HasValues => Ip is not null || UserAgent is not null || Device is not null || Platform is not null || Version is not null;

    public static LoginTracking From(HttpRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        // Stricter than PHP's getRealIpAddr() (decided 11 Nov 2026), which believes Client-IP and X-Forwarded-For as sent: the peer, or the hop our own proxy added.
        var address = ClientAddress.Of(request.HttpContext);
        var ip = address == ClientAddress.Unknown ? null : address;
        return new LoginTracking(
            Fit(ip, 100),
            Fit(First(request.Headers.UserAgent.ToString()), 2000),
            Fit(First(request.Headers["X-Device-Info"].ToString()), 200),
            Fit(First(request.Headers["X-Platform-Info"].ToString()), 200),
            Fit(First(request.Headers["X-App-Version"].ToString()), 200));
    }

    private static string? First(string value) => string.IsNullOrEmpty(value) ? null : value;

    private static string? Fit(string? value, int length) =>
        value is null || value.Length <= length ? value : value[..length];
}
