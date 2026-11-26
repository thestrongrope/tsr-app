using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>The selects of guardian links and the reader of one row. Each query runs on a data source or on a <see cref="DbTx"/>.</summary>
internal static class GuardianRows
{
    /// <summary>The length of an invite code (PHP: <c>bin2hex(random_bytes(16))</c>, the column is 32 characters). A longer code cannot match a row.</summary>
    public const int CodeLength = 32;

    /// <summary>The link whose invite code is <paramref name="code"/> (a citext comparison).</summary>
    public static Sql ByCode(string code) =>
        $"""
        select id, parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at
        from membership.user_guardians where code = {code}::citext
        """;

    /// <summary>Every link of a parent, newest first.</summary>
    public static Sql OfParent(int parentToken, int limit) =>
        $"""
        select id, parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at
        from membership.user_guardians where parent_token = {parentToken}
        order by created_at desc, id limit {limit}
        """;

    /// <summary>The active links of a child, newest first.</summary>
    public static Sql ActiveOfChild(int childToken, int limit) =>
        $"""
        select id, parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at
        from membership.user_guardians where child_token = {childToken} and status = 'active'
        order by created_at desc, id limit {limit}
        """;

    /// <summary>The unused, unexpired invites a user made for a child, newest id first.</summary>
    public static Sql OpenInvites(int childToken, int createdBy, DateTimeOffset now, int limit) =>
        $"""
        select id, parent_token, child_token, relationship, status, source, code, expires_at, created_by, created_at, activated_at, revoked_by, revoked_at
        from membership.user_guardians
        where child_token = {childToken} and created_by = {createdBy} and status = 'invited' and (expires_at is null or expires_at > {now})
        order by id desc limit {limit}
        """;

    public static UserGuardian Read(DbRow row) => new()
    {
        Id = row.Int("id"),
        ParentToken = row.IntOrNull("parent_token"),
        ChildToken = row.Int("child_token"),
        Relationship = row.TextOrNull("relationship"),
        Status = row.Text("status"),
        Source = row.Text("source"),
        Code = row.TextOrNull("code"),
        ExpiresAt = row.InstantOrNull("expires_at"),
        CreatedBy = row.Int("created_by"),
        CreatedAt = row.Instant("created_at"),
        ActivatedAt = row.InstantOrNull("activated_at"),
        RevokedBy = row.IntOrNull("revoked_by"),
        RevokedAt = row.InstantOrNull("revoked_at"),
    };
}
