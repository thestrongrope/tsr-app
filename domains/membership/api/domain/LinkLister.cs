using System.Text.Json.Nodes;
using Npgsql;
using Tsr.Identity.Api;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>
/// Builds the rows of GET /me/children/links and GET /me/parents the way PHP's two LEFT JOINs do: every member holding the other
/// side's token gives a row (a shared token doubles it, none gives a null name), the creator is joined by user id. Names come
/// straight from the profile, so an empty name stays empty (MemberNames leaves those out). Reads other domains through
/// identity's <see cref="UserDirectory"/> only.
/// </summary>
internal sealed class LinkLister(NpgsqlDataSource source, UserDirectory users)
{
    /// <summary>A bound on one list; a member has a handful of links.</summary>
    public const int MaxRows = 200;

    public async Task<JsonArray> ShowAsync(IReadOnlyList<UserGuardian> rows, string nameKey, Func<UserGuardian, int?> otherToken, CancellationToken ct)
    {
        var tokens = rows.Select(otherToken).OfType<int>().Distinct().ToList();
        var holders = (await users.ByTokensAsync(tokens, ct)).ToLookup(u => u.Token, u => u.Id);
        var creators = (await users.ByIdsAsync(rows.Select(r => r.CreatedBy).Distinct().ToList(), ct)).Select(u => u.Id);
        var userIds = holders.SelectMany(h => h).Concat(creators).Distinct().ToArray();
        var named = await source.ListAsync(
            $"select user_id, name from membership.member_profiles where user_id = any({userIds})",
            row => (UserId: row.Int("user_id"), Name: row.TextOrNull("name")),
            ct);
        var names = named.ToDictionary(p => p.UserId, p => p.Name);

        var list = new JsonArray();
        foreach (var row in rows)
        {
            var creator = names.GetValueOrDefault(row.CreatedBy);
            var token = otherToken(row);
            var members = token is int t ? holders[t].ToList() : [];
            var memberNames = members.Count == 0 ? [null] : members.Select(id => names.GetValueOrDefault(id)).ToList();
            foreach (var memberName in memberNames)
            {
                list.Add((JsonNode)LinkRowView.Build(ToRow(row), nameKey, memberName, creator));
            }
        }

        return list;
    }

    private static LinkRow ToRow(UserGuardian g) =>
        new(g.Id, g.ParentToken, g.ChildToken, g.Relationship, g.Status, g.Source, g.CreatedAt, g.ActivatedAt, g.RevokedAt);
}
