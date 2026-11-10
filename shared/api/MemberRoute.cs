using Microsoft.AspNetCore.Builder;

namespace Tsr.Shared.Api;

/// <summary>
/// Marks an endpoint as one only a signed-in member may call. identity's middleware reads it: it
/// verifies the sign-in and refuses the request with PHP's status and detail before the handler runs.
/// <c>CreatesMember</c> is PHP's <c>api_authenticate(true)</c>: a first sign-in creates the member's row.
/// Endpoints without it (health, public reads) are never authenticated.
/// </summary>
public sealed record MemberRoute(bool CreatesMember);

public static class MemberRouteExtensions
{
    public static TBuilder RequireMember<TBuilder>(this TBuilder builder, bool createsMember = false)
        where TBuilder : IEndpointConventionBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);
        builder.Add(endpoint => endpoint.Metadata.Add(new MemberRoute(createsMember)));
        return builder;
    }
}
