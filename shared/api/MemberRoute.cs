using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

namespace Tsr.Shared.Api;

/// <summary>
/// Marks an endpoint as one only a signed-in member may call. identity's middleware reads it: it
/// verifies the sign-in and refuses the request with PHP's status and detail before the handler runs.
/// <c>CreatesMember</c> is PHP's <c>api_authenticate(true)</c>: a first sign-in creates the member's row.
/// <c>Precheck</c> is a check PHP makes BEFORE it authenticates (the report downloads refuse a bad <c>?format=</c> first): an answer here is sent and the sign-in never runs.
/// <c>Optional</c> makes the sign-in optional: no credentials is a signed-out call (no caller is set); credentials that fail, or that name no member, are 401 "Authentication failed"; the call never creates a member,
/// is never refused for a pending account deletion and is not recorded as a sign-in. For a public route that answers more to a member (GET /quiz/info).
/// Endpoints without it (health, public reads) are never authenticated.
/// </summary>
public sealed record MemberRoute(bool CreatesMember, Func<HttpContext, IResult?>? Precheck = null, bool Optional = false);

public static class MemberRouteExtensions
{
    public static TBuilder RequireMember<TBuilder>(this TBuilder builder, bool createsMember = false, Func<HttpContext, IResult?>? precheck = null, bool optional = false)
        where TBuilder : IEndpointConventionBuilder
    {
        ArgumentNullException.ThrowIfNull(builder);
        builder.Add(endpoint => endpoint.Metadata.Add(new MemberRoute(createsMember, precheck, optional)));
        return builder;
    }
}
