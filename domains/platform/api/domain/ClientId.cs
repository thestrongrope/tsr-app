using System.Text.RegularExpressions;
using Tsr.Shared.Api;

namespace Tsr.Platform.Api.Domain;

/// <summary>
/// The app's own id for one message (a UUID it generates before sending). A replay with the same
/// id from the same member returns the stored row, so a lost reply never stores a message twice.
/// </summary>
internal sealed partial record ClientId
{
    private ClientId(string value) => Value = value;

    public string Value { get; }

    public static Result<ClientId> Create(string? raw)
    {
        var id = raw?.Trim() ?? string.Empty;
        if (!Shape().IsMatch(id))
        {
            return Result.Fail<ClientId>("clientId is required");
        }

        return Result.Ok<ClientId>(new ClientId(id));
    }

    [GeneratedRegex("^[A-Za-z0-9-]{1,36}$", RegexOptions.CultureInvariant, matchTimeoutMilliseconds: 100)]
    private static partial Regex Shape();
}
