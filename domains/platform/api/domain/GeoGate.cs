using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// What every geo call passes before its own work: PHP's api_geo_guard(). The caller is signed in (identity's
/// middleware did that, 401 and the rest), then the rate limit counts the call, whether or not it later fails
/// validation. So the order is 401, 429, then body validation (422).
/// </summary>
internal sealed class GeoGate(GeoRateLimit limit)
{
    public const string TooManyLookups = "Too many lookups; try again in a minute";

    /// <summary>The Problem to answer, or null when the call may go on.</summary>
    public IResult? Refuse(Caller? caller)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        return limit.Allow(caller.Token) ? null : Problem.Detail(StatusCodes.Status429TooManyRequests, TooManyLookups);
    }
}
