namespace Tsr.Db.Tests;

internal static partial class AccessGoldenScenarios
{
    internal const string MixedConditions =
        """{"field": "level", "value": 3}, {"field": "city", "value": "goldville"}, {"field": "tag", "value": "ALPHA"}, {"field": "level", "value": 2}""";

    /// <summary>The conditions a rule sent as <see cref="MixedConditions"/> stores, in the order of their ids: today's code puts them in key order (field, then value), not in the order sent.</summary>
    internal static readonly string[] StoredConditionOrder = ["city=Goldville", "level=2", "level=3", "tag=alpha"];

    private static async Task GrantAndRevokeAsync(GoldenScenario run)
    {
        await run.SendAsync(Super, Post, $"/admin/permissions/members/{Subject}/grants", """{"permission": "donors:read:all", "reason": "  Needs the list  "}""");
        await run.AppendRowsAsync("grant 1");
        await run.SendAsync(Super, Post, $"/admin/permissions/members/{GoldenSeed.OddName}/grants", """{"permission": "audit-log:read:all", "reason": "Odd +\" < name"}""");
        await run.AppendRowsAsync("grant 2");
        await run.SendAsync(Super, Post, "/admin/permissions/grants/1/revoke", """{"reason": "  Done  "}""");
        await run.AppendRowsAsync("revoke 1");
        await run.SendAsync(Super, Post, "/admin/permissions/grants/2/revoke", """{"reason": "Done too"}""");
        await run.AppendRowsAsync("revoke 2");
    }

    private static async Task RuleSaveAndRevokeAsync(GoldenScenario run)
    {
        var rules = $"/admin/class-access/members/{Subject}/rules";
        var (version, hash) = await DraftAsync(run, Gents, Subject, 1, Ville);
        var saved = await run.SendAsync(Gents, Post, rules, SaveBody(1, Ville, "  Teaches there  ", version, hash));
        await run.AppendRowsAsync("save 1 (member of role 0 becomes role 5)");
        var (_, secondHash) = await DraftAsync(run, Super, Subject, 1, MixedConditions);
        await run.SendAsync(Super, Post, rules, SaveBody(1, MixedConditions, "Second rule", AccessGoldenScenarios.StringOf(saved.Json, "version"), secondHash));
        await run.AppendRowsAsync("save 2");
        await run.SendAsync(Super, Post, "/admin/class-access/rules/1/revoke", RevokeBody("  Moved  ", await VersionOfAsync(run, Subject)));
        await run.AppendRowsAsync("revoke 1 (a live rule is left: role stays 5)");
        await run.SendAsync(Super, Post, "/admin/class-access/rules/2/revoke", RevokeBody("Moved too", await VersionOfAsync(run, Subject)));
        await run.AppendRowsAsync("revoke 2 (the last rule: role back to 0)");
    }

    // One rule sent with conditions level 3, city, tag, level 2: the stored order of its conditions (TC-ACC-R2-02), through the golden file and in the member view.
    private static async Task ConditionOrderAsync(GoldenScenario run)
    {
        var (version, hash) = await DraftAsync(run, Gents, Subject, 1, MixedConditions);
        await run.SendAsync(Gents, Post, $"/admin/class-access/members/{Subject}/rules", SaveBody(1, MixedConditions, "Order", version, hash));
        await run.SendAsync(Gents, Get, $"/admin/class-access/members/{Subject}");
        await run.AppendRowsAsync("save");
    }

    private static async Task<string> VersionOfAsync(GoldenScenario run, int member) =>
        AccessGoldenScenarios.StringOf((await run.SendAsync(Super, Get, $"/admin/class-access/members/{member}")).Json, "version");
}
