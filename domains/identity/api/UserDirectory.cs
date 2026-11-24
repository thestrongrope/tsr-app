using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>One member's identity facts: the user id, the token and the email. The email is null for a deleted account.</summary>
public sealed record UserRef(int Id, int Token, string? Email);

/// <summary>
/// The module's public read interface: who a user id or a token is, without reading identity's table. A token is
/// not unique (PHP's <c>users.token</c> is a plain key, and every guest has 0), so a token lookup returns every match
/// and the caller decides what a shared token means (the guardian code refuses one).
/// </summary>
public sealed class UserDirectory
{
    /// <summary>The most ids one call accepts. A bigger batch is a bug in the caller and throws.</summary>
    public const int MaxBatch = 500;

    /// <summary>The most users one token lookup returns (token 0 matches every guest).</summary>
    public const int MaxMatches = 50;

    /// <summary>The most users a batch of tokens returns (a bound on the answer; token 0 should not be asked for).</summary>
    public const int MaxTokenMatches = 2000;

    private readonly NpgsqlDataSource _source;

    internal UserDirectory(NpgsqlDataSource source) => _source = source;

    /// <summary>Every user holding <paramref name="token"/>, oldest first, at most <see cref="MaxMatches"/>.</summary>
    public async Task<IReadOnlyList<UserRef>> ByTokenAsync(int token, CancellationToken ct) =>
        await _source.ListAsync(
            $"select u.id as \"Id\", u.token as \"Token\", u.email as \"Email\" from identity.users u where u.token = {token} order by u.id limit {MaxMatches}",
            Read,
            ct);

    /// <summary>Every user holding any of these tokens, in id order (a shared token returns each holder). At most <see cref="MaxBatch"/> tokens.</summary>
    public async Task<IReadOnlyList<UserRef>> ByTokensAsync(IReadOnlyCollection<int> tokens, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(tokens);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(tokens.Count, MaxBatch);
        if (tokens.Count == 0)
        {
            return [];
        }

        var wanted = tokens.Distinct().ToArray();
        return await _source.ListAsync(
            $"select u.id as \"Id\", u.token as \"Token\", u.email as \"Email\" from identity.users u where u.token = any({wanted}) order by u.id limit {MaxTokenMatches}",
            Read,
            ct);
    }

    /// <summary>The users with these ids (an id that does not exist is left out), in id order. At most <see cref="MaxBatch"/> ids.</summary>
    public async Task<IReadOnlyList<UserRef>> ByIdsAsync(IReadOnlyCollection<int> ids, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(ids);
        ArgumentOutOfRangeException.ThrowIfGreaterThan(ids.Count, MaxBatch);
        if (ids.Count == 0)
        {
            return [];
        }

        var wanted = ids.Distinct().ToArray();
        return await _source.ListAsync(
            $"select u.id as \"Id\", u.token as \"Token\", u.email as \"Email\" from identity.users u where u.id = any({wanted}) order by u.id",
            Read,
            ct);
    }

    private static UserRef Read(DbRow row) => new(row.Int("Id"), row.Int("Token"), row.TextOrNull("Email"));
}
