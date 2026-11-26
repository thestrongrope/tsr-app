namespace Tsr.Db.Tests;

/// <summary>
/// Scenarios added after the first review of the set: a member who holds live class access rules, an unprivileged member asking after a member that does not exist,
/// and a ladies admin on the paths that succeed for her.
/// </summary>
internal static partial class AccessGoldenScenarios
{
    private const int LadiesAdmin = GoldenSeed.LadiesAdmin;
    private const int LadiesMember = GoldenSeed.LadiesMember;
    private const string LadiesRule = """{"field": "city", "value": "Goldville"}""";

    /// <summary>
    /// Three rules for <see cref="GoldenSeed.Subject"/> (role 5) against the seeded classes (98501 level 2 Goldville alpha, 98502 level 3 Goldville alpha,
    /// 98503 level 2 Goldother beta, 98504 closed, 98505 ladies Goldville level 2). Rule 1, gents, city Goldville and level 2 and tag alpha: reaches 98501 only.
    /// Rule 2, ladies, no conditions: reaches the one active ladies class, 98505. Rule 3, gents, no conditions, revoked: would reach every gents class if it counted.
    /// </summary>
    internal static async Task SeedAssignedRulesAsync(GoldenScenario run) => await run.ExecuteAsync(
        $"""
        insert into access.user_roles (user_id, roleid) select id, 5 from identity.users where token = {Subject};
        insert into access.class_access_rules (token, gender, note, created_at, granted_by, reason, revoked_at, revoked_by, revoke_reason)
          select {Subject}, 1, 'Gents, level 2, Goldville, alpha', timestamptz '2026-01-01 00:00:00+00', id, 'Seed', null, null, null from identity.users where token = {Super};
        insert into access.class_access_rules (token, gender, note, created_at, granted_by, reason, revoked_at, revoked_by, revoke_reason)
          select {Subject}, 2, 'Ladies', timestamptz '2026-01-01 00:00:00+00', id, 'Seed', null, null, null from identity.users where token = {Super};
        insert into access.class_access_rules (token, gender, note, created_at, granted_by, reason, revoked_at, revoked_by, revoke_reason)
          select {Subject}, 1, 'Gents (revoked)', timestamptz '2026-01-01 00:00:00+00', id, 'Seed', timestamptz '2026-01-01 00:00:00+00', id, 'Seed revoked' from identity.users where token = {Super};
        insert into access.class_access_rule_conditions (rule_id, field, negate, value, level_id) values
          (1, 'city', false, 'Goldville', null), (1, 'level', false, null, 2), (1, 'tag', false, 'alpha', null);
        """);

    // The member who holds the rules asks what she holds, and the admin screens show the rules; a plain member next to her shows nothing leaks across members.
    private static async Task ReadAssignedRulesAsync(GoldenScenario run)
    {
        await SeedAssignedRulesAsync(run);
        await ReadRoutesAsync(run, Subject);
        await run.SendAsync(Subject, Get, "/me/permissions/classes:read");
        await run.SendAsync(Plain, Get, "/me/permissions");
        await run.SendAsync(Gents, Get, $"/admin/class-access/members/{Subject}");
        await run.SendAsync(Super, Get, $"/admin/permissions/members/{Subject}");
    }

    // The permission refusal comes before the existence check: a member without the right is told 403, not 404, for a token that is nobody's.
    private static async Task AdminUnknownTokenUnprivilegedAsync(GoldenScenario run)
    {
        await run.SendAsync(Plain, Get, "/admin/permissions/members/99999999");
        await run.SendAsync(Plain, Post, "/admin/permissions/members/99999999/grants", """{"permission": "donors:read:all", "reason": "Needs the list"}""");
        await run.SendAsync(Plain, Post, "/admin/permissions/grants/99999999/revoke", """{"reason": "Done"}""");
        await run.SendAsync(Plain, Get, "/admin/class-access/members/99999999");
        await run.SendAsync(Plain, Post, "/admin/class-access/members/99999999/rules", SaveBody(1, Ville, "Why", "0:0000000000000000", "x"));
        await run.SendAsync(Plain, Post, "/admin/class-access/rules/99999999/revoke", RevokeBody("Moved", "0:0000000000000000"));
        await run.SendAsync(Plain, Post, "/admin/class-access/preview", $$"""{"gender": 1, "conditions": [{{Ville}}]}""");
    }

    // A ladies admin: the member lists and views she may see, her options and previews, one rule saved for a ladies member and revoked again, and what she is refused.
    private static async Task LadiesAdminSuccessAsync(GoldenScenario run)
    {
        foreach (var query in new[] { "q=Gold", "q=a", "q=900006", string.Empty })
        {
            await run.SendAsync(LadiesAdmin, Get, "/admin/class-access/members" + (query.Length == 0 ? string.Empty : "?" + query));
        }

        await run.SendAsync(LadiesAdmin, Get, $"/admin/class-access/members/{LadiesMember}");
        await run.SendAsync(LadiesAdmin, Get, $"/admin/class-access/members/{LadiesAdmin}");
        await run.SendAsync(LadiesAdmin, Get, "/admin/class-access/options");
        await run.SendAsync(LadiesAdmin, Post, "/admin/class-access/preview", $$"""{"gender": 2, "conditions": [{{LadiesRule}}]}""");
        await run.SendAsync(LadiesAdmin, Post, "/admin/class-access/preview", """{"gender": 2, "conditions": [{"field": "level", "value": 2}]}""");
        var rules = $"/admin/class-access/members/{LadiesMember}/rules";
        var (version, hash) = await DraftAsync(run, LadiesAdmin, LadiesMember, 2, LadiesRule);
        var saved = await run.SendAsync(LadiesAdmin, Post, rules, SaveBody(2, LadiesRule, "Teaches there", version, hash));
        await run.SendAsync(LadiesAdmin, Get, $"/admin/class-access/members/{LadiesMember}");
        await run.SendAsync(LadiesMember, Get, "/me/permissions");
        await run.SendAsync(LadiesAdmin, Post, rules, SaveBody(1, LadiesRule, "Wrong gender", StringOf(saved.Json, "version"), hash));
        await run.SendAsync(LadiesAdmin, Get, "/admin/permissions/members?q=Gold");
        var ruleId = saved.Json!["rules"]![0]!["id"]!.GetValue<int>();
        await run.SendAsync(LadiesAdmin, Post, $"/admin/class-access/rules/{ruleId}/revoke", RevokeBody("Moved", StringOf(saved.Json, "version")));
    }
}
