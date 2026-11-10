using Microsoft.AspNetCore.Http;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// What every geo call passes before its own work: PHP's api_geo_guard(). The caller is signed in (identity's
/// middleware did that, 401 and the rest), then the rate limit counts the call, whether or not it later fails
/// validation. So the order is 401, 429, then body validation (422). 60 geo calls in any 60 seconds per member.
/// </summary>
internal sealed class GeoGate(MemberRateLimit limit)
{
    public const string TooManyLookups = "Too many lookups; try again in a minute";

    public const string Bucket = "geo";

    public const int MaxCalls = 60;

    public const int WindowSeconds = 60;

    /// <summary>The Problem to answer, or null when the call may go on.</summary>
    public IResult? Refuse(Caller? caller)
    {
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        return limit.Allow(Bucket, caller.Token, MaxCalls, WindowSeconds)
            ? null
            : Problem.Detail(StatusCodes.Status429TooManyRequests, TooManyLookups);
    }
}
