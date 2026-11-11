using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

namespace Tsr.Shared.Api;

/// <summary>
/// Marks an endpoint as one only a signed-in member may call. identity's middleware reads it: it
/// verifies the sign-in and refuses the request with PHP's status and detail before the handler runs.
/// <c>CreatesMember</c> is PHP's <c>api_authenticate(true)</c>: a first sign-in creates the member's row.
/// <c>Precheck</c> is a check PHP makes BEFORE it authenticates (the report downloads refuse a bad <c>?format=</c> first): an answer here is sent and the sign-in never runs.
/// Endpoints without it (health, public reads) are never authenticated.
/// </summary>
public sealed record MemberRoute(bool CreatesMember, Func<HttpContext, IResult?>? Precheck = null);

public static class MemberRouteExtensions
{
    public static TBuilder RequireMember<TBuilder>(this TBuilder builder, bool createsMember = false, Func<HttpContext, IResult?>? precheck = null)
        where TBuilder : IEndpointConventionBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);
        builder.Add(endpoint => endpoint.Metadata.Add(new MemberRoute(createsMember, precheck)));
        return builder;
    }
}
