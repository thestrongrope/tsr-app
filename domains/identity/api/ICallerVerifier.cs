using Microsoft.AspNetCore.Http;

namespace Tsr.Identity.Api;

/// <summary>How a request's credentials fared. Each refusal maps to one PHP response (CallerMiddleware).</summary>
internal enum VerifyStatus
{
    /// <summary>A valid Firebase token with an email.</summary>
    Verified,

    /// <summary>No Authorization header, or not <c>Bearer &lt;token&gt;</c>.</summary>
    NoCredentials,

    /// <summary>Bad signature, expired, wrong issuer, audience or subject, keys unavailable, emulator refused.</summary>
    InvalidToken,

    /// <summary>A valid token that carries no email.</summary>
    NoEmail,
}

/// <summary>
/// What a verified token says about its holder. <c>EmailVerified</c> is true only for a JSON <c>true</c>. <c>Name</c> and
/// <c>Picture</c> are the token's own claims when they are text, else null (PHP: <c>$claims['name'] ?? null</c>); identity hands them on, it stores neither.
/// </summary>
internal sealed record FirebaseIdentity(string Uid, string Email, bool EmailVerified, string? Name = null, string? Picture = null);

internal sealed record Verification(VerifyStatus Status, FirebaseIdentity? Identity = null);

/// <summary>
/// Port at an external boundary: turns a request's credentials into a verified Firebase identity.
/// <see cref="FirebaseVerifier"/> is the one implementation; the database tests replace it so they
/// need no Firebase. This is the only interface in identity, because the identity provider is a third party.
/// </summary>
internal interface ICallerVerifier
{
    Task<Verification> VerifyAsync(HttpRequest request, CancellationToken ct);
}
