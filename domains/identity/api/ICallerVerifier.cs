using Microsoft.AspNetCore.Http;

namespace Tsr.Identity.Api;

/// <summary>
/// Port at an external boundary: turns a request's credentials into a member token, or null.
/// Production verifies a Firebase ID token (docs/dev/identity.md in tsr-account); local
/// development uses <see cref="DevTokenVerifier"/>. This is the only interface in identity,
/// because the identity provider is a third party.
/// </summary>
internal interface ICallerVerifier
{
    Task<int?> VerifyAsync(HttpRequest request, CancellationToken ct);
}
