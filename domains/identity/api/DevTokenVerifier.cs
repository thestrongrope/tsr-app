using System.Globalization;
using Microsoft.AspNetCore.Http;

namespace Tsr.Identity.Api;

/// <summary>
/// Local development only: trusts an <c>X-Dev-Token</c> header holding a synthetic member's
/// token. IdentityModule registers it only when the host environment is Development, and the
/// host refuses to start anywhere else without a real verifier (fail closed).
/// </summary>
internal sealed class DevTokenVerifier : ICallerVerifier
{
    public const string Header = "X-Dev-Token";

    public Task<int?> VerifyAsync(HttpRequest request, CancellationToken ct)
    {
        var raw = request.Headers[Header].ToString();
        if (!int.TryParse(raw, NumberStyles.None, CultureInfo.InvariantCulture, out var token) || token <= 0)
        {
            return Task.FromResult<int?>(null);
        }

        return Task.FromResult<int?>(token);
    }
}
