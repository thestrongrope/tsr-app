using System.Text.Json.Nodes;

namespace Tsr.Db.Tests;

internal static partial class AccessGoldenScenarios
{
    private const int Super = GoldenSeed.Super;
    private const int Gents = GoldenSeed.GentsAdmin;
    private const int Plain = GoldenSeed.Plain;
    private const int Subject = GoldenSeed.Subject;

    // GET /admin/permissions/members and /{token}: the searches, and members with an empty name (the 0 of Cast.Text), a non-ASCII name, no row and a junk token.
    private static async Task AdminPermReadsAsync(GoldenScenario run)
    {
        foreach (var query in new[] { "q=Gold", "q=900008", "q=Zo%C3%AB", "q=%25", "q=a", "q=", "q%5B%5D=xx", "q=Gold&q=Plain", string.Empty })
        {
            await run.SendAsync(Super, Get, "/admin/permissions/members" + (query.Length == 0 ? string.Empty : "?" + query));
        }

        foreach (var token in new[] { "900005", "900007", "900008", "900001", "99999999", "abc" })
        {
            await run.SendAsync(Super, Get, "/admin/permissions/members/" + token);
        }
    }

    private static async Task AdminPermReadsRefusedAsync(GoldenScenario run)
    {
        foreach (int? caller in new int?[] { null, Plain, Gents, GoldenSeed.LadiesAdmin })
        {
            await run.SendAsync(caller, Get, "/admin/permissions/members?q=Gold");
            await run.SendAsync(caller, Get, "/admin/permissions/members/900005");
        }
    }

    // POST /admin/permissions/members/{token}/grants: every refusal, in the order the route checks them, with nothing granted.
    private static async Task AdminPermGrantRefusalsAsync(GoldenScenario run)
    {
        var grants = $"/admin/permissions/members/{Subject}/grants";
        await run.SendAsync(null, Post, grants, """{"permission": "donors:read:all", "reason": "Needs the list"}""");
        await run.SendAsync(Plain, Post, grants, """{"permission": "donors:read:all", "reason": "Needs the list"}""");
        await run.SendAsync(Gents, Post, grants, """{"permission": "donors:read:all", "reason": "Needs the list"}""");
        await run.SendAsync(Super, Post, grants, "not json");
        await run.SendAsync(Super, Post, grants, """{"reason": "Needs the list"}""");
        await run.SendAsync(Super, Post, grants, """{"permission": 5, "reason": "Needs the list"}""");
        await run.SendAsync(Super, Post, grants, """{"permission": "donors:read:all"}""");
        await run.SendAsync(Super, Post, grants, """{"permission": "donors:read:all", "reason": 5}""");
        await run.SendAsync(Super, Post, grants, """{"permission": "donors:read:all", "reason": "   "}""");
        await run.SendAsync(Super, Post, grants, $$"""{"permission": "donors:read:all", "reason": "{{new string('x', 301)}}"}""");
        await run.SendAsync(Super, Post, "/admin/permissions/members/99999999/grants", """{"permission": "donors:read:all", "reason": "Needs the list"}""");
        await run.SendAsync(Super, Post, $"/admin/permissions/members/{Super}/grants", """{"permission": "donors:read:all", "reason": "Self"}""");
        foreach (var permission in new[] { "permissions:manage:all", "class-access:manage:all", "members:enrol-by-token:all", "donors:read:gender", "nothing:here:all", "content:read:all" })
        {
            await run.SendAsync(Super, Post, grants, $$"""{"permission": "{{permission}}", "reason": "Needs the list"}""");
        }

        await run.AppendRowsAsync("the refused grants");
    }

    // A grant to a member with an empty name, a non-ASCII name and a plain one, a second grant that is held (409), and every revoke answer.
    private static async Task AdminPermGrantRevokeAsync(GoldenScenario run)
    {
        var first = await run.SendAsync(Super, Post, $"/admin/permissions/members/{Subject}/grants", """{"permission": "donors:read:all", "reason": "  Needs the list  "}""");
        await run.SendAsync(Super, Post, $"/admin/permissions/members/{Subject}/grants", """{"permission": "Donors:Read:All", "reason": "Again"}""");
        await run.SendAsync(Super, Post, $"/admin/permissions/members/{Subject}/grants", """{"permission": "donors:read:all", "reason": "Held"}""");
        await run.SendAsync(Super, Post, $"/admin/permissions/members/{GoldenSeed.EmptyName}/grants", """{"permission": "feedback:review:all", "reason": "Empty name"}""");
        await run.SendAsync(Super, Post, $"/admin/permissions/members/{GoldenSeed.OddName}/grants", """{"permission": "content:read:all", "reason": "Odd +\" < name"}""");
        await run.SendAsync(Super, Post, $"/admin/permissions/members/{GoldenSeed.OddName}/grants", """{"permission": "audit-log:read:all", "reason": "Second"}""");
        await run.SendAsync(Super, Get, $"/admin/permissions/members/{GoldenSeed.OddName}");
        await run.SendAsync(Subject, Get, "/me/permissions");
        var id = first.Json!["granted"]![0]!["id"]!.GetValue<int>();
        var revoke = $"/admin/permissions/grants/{id}/revoke";
        await run.SendAsync(null, Post, revoke, """{"reason": "Done"}""");
        await run.SendAsync(Plain, Post, revoke, """{"reason": "Done"}""");
        await run.SendAsync(Gents, Post, revoke, """{"reason": "Done"}""");
        await run.SendAsync(Super, Post, revoke, "not json");
        await run.SendAsync(Super, Post, revoke, "{}");
        await run.SendAsync(Super, Post, revoke, """{"reason": "   "}""");
        await run.SendAsync(Super, Post, "/admin/permissions/grants/99999999/revoke", """{"reason": "Done"}""");
        await run.SendAsync(Super, Post, "/admin/permissions/grants/abc/revoke", """{"reason": "Done"}""");
        await run.SendAsync(Super, Post, revoke, """{"reason": "  Done  "}""");
        await run.SendAsync(Super, Post, revoke, """{"reason": "Done again"}""");
        await run.SendAsync(Subject, Get, "/me/permissions");
    }

    // The five read routes of class access and the preview, for one operator: searches, views (empty name, non-ASCII name, other gender, no gender, none), options and previews.
    private static async Task ClassAccessReadsAsync(GoldenScenario run, int caller)
    {
        foreach (var query in new[] { "q=Gold", "q=900007", "q=Zo%C3%AB", "q=a", "q%5B%5D=xx", string.Empty })
        {
            await run.SendAsync(caller, Get, "/admin/class-access/members" + (query.Length == 0 ? string.Empty : "?" + query));
        }

        foreach (var token in new[] { "900005", "900007", "900008", "900006", "900011", "900001", "99999999" })
        {
            await run.SendAsync(caller, Get, "/admin/class-access/members/" + token);
        }

        await run.SendAsync(caller, Get, "/admin/class-access/options");
        var previews = new[]
        {
            $$"""{"gender": 1, "conditions": [{{Ville}}]}""",
            """{"gender": 1, "conditions": [{"field": "level", "value": 2}]}""",
            """{"gender": 1, "conditions": [{"field": "tag", "value": "ALPHA"}]}""",
            """{"gender": 1, "conditions": [{"field": "country", "value": "goldland"}]}""",
            $$"""{"gender": 1, "conditions": [{"field": "level", "value": 2}, {{Ville}}, {"field": "tag", "value": "alpha"}, {"field": "level", "value": 3}]}""",
            $$"""{"conditions": [{{Ville}}]}""",
            $$"""{"gender": 2, "conditions": [{{Ville}}]}""",
            """{"gender": 1, "conditions": []}""",
            """{"gender": 1, "conditions": [{"field": "level", "value": 99}]}""",
            """{"gender": 1, "conditions": [{"field": "city", "value": "Nowhere"}]}""",
            """{"gender": 1, "conditions": [{"field": "city", "value": "Goldville", "negate": true}]}""",
            """{"gender": 1, "conditions": [{"field": "colour", "value": "red"}]}""",
            """{"gender": 3, "conditions": [{"field": "level", "value": 2}]}""",
            """{"gender": "1", "conditions": "x"}""",
            "not json",
        };
        foreach (var body in previews)
        {
            await run.SendAsync(caller, Post, "/admin/class-access/preview", body);
        }
    }

    private static async Task ClassAccessReadsRefusedAsync(GoldenScenario run)
    {
        foreach (int? caller in new int?[] { null, Plain, GoldenSeed.LadiesAdmin })
        {
            await run.SendAsync(caller, Get, "/admin/class-access/members?q=Gold");
            await run.SendAsync(caller, Get, "/admin/class-access/members/900005");
            await run.SendAsync(caller, Get, "/admin/class-access/options");
            await run.SendAsync(caller, Post, "/admin/class-access/preview", $$"""{"gender": 1, "conditions": [{{Ville}}]}""");
        }
    }

    // POST /admin/class-access/members/{token}/rules: every refusal that writes nothing.
    private static async Task ClassAccessSaveRefusalsAsync(GoldenScenario run)
    {
        var rules = $"/admin/class-access/members/{Subject}/rules";
        var (version, hash) = await DraftAsync(run, Gents, Subject, 1, Ville);
        await run.SendAsync(null, Post, rules, SaveBody(1, Ville, "Why", version, hash));
        await run.SendAsync(Plain, Post, rules, SaveBody(1, Ville, "Why", version, hash));
        foreach (var body in new[]
        {
            """{"gender": "1", "conditions": "x", "reason": 5, "version": 5, "previewHash": 5}""",
            """{"gender": 1, "conditions": "x", "reason": 5, "version": 5, "previewHash": 5}""",
            $$"""{"gender": 1, "conditions": [{{Ville}}], "reason": 5, "version": 5, "previewHash": 5}""",
            $$"""{"gender": 1, "conditions": [{{Ville}}], "reason": "Why", "version": 5, "previewHash": 5}""",
            $$"""{"gender": 1, "conditions": [{{Ville}}], "reason": "Why", "version": "x"}""",
            $$"""{"gender": 1, "conditions": [{{Ville}}], "reason": "   ", "version": "x", "previewHash": "x"}""",
            $$"""{"gender": 5, "conditions": [{{Ville}}], "reason": "Why", "version": "x", "previewHash": "x"}""",
            """{"gender": 1, "conditions": [], "reason": "Why", "version": "x", "previewHash": "x"}""",
            """{"gender": 1, "conditions": [{"field": "level", "value": 99}], "reason": "Why", "version": "x", "previewHash": "x"}""",
            """{"gender": 1, "conditions": [{"field": "city", "value": "Nowhere"}], "reason": "Why", "version": "x", "previewHash": "x"}""",
        })
        {
            await run.SendAsync(Gents, Post, rules, body);
        }

        await run.SendAsync(Gents, Post, rules, "not json");
        await run.SendAsync(Gents, Post, "/admin/class-access/members/99999999/rules", SaveBody(1, Ville, "Why", version, hash));
        await run.SendAsync(Gents, Post, $"/admin/class-access/members/{Gents}/rules", SaveBody(1, Ville, "Why", version, hash));
        await run.SendAsync(Super, Post, $"/admin/class-access/members/{Super}/rules", SaveBody(1, Ville, "Why", version, hash));
        foreach (var member in new[] { GoldenSeed.LadiesMember, GoldenSeed.NoGender })
        {
            await run.SendAsync(Gents, Post, $"/admin/class-access/members/{member}/rules", SaveBody(1, Ville, "Why", version, hash));
        }

        await run.SendAsync(Gents, Post, rules, SaveBody(2, Ville, "Why", version, hash));
        await run.SendAsync(GoldenSeed.LadiesAdmin, Post, rules, SaveBody(1, Ville, "Why", version, hash));
        await run.SendAsync(Gents, Post, $"/admin/class-access/members/{GoldenSeed.PeerGentsAdmin}/rules", SaveBody(1, Ville, "Why", version, hash));
        await run.SendAsync(Gents, Post, $"/admin/class-access/members/{Super}/rules", SaveBody(1, Ville, "Why", version, hash));
        var (financeVersion, financeHash) = await DraftAsync(run, Super, GoldenSeed.Finance, 1, Ville);
        await run.SendAsync(Super, Post, $"/admin/class-access/members/{GoldenSeed.Finance}/rules", SaveBody(1, Ville, "Why", financeVersion, financeHash));
        await run.SendAsync(Gents, Post, rules, SaveBody(1, Ville, "Why", "0:0000000000000000", hash));
        await run.SendAsync(Gents, Post, rules, SaveBody(1, """{"field": "city", "value": "Goldother"}""", "Why", version, hash));
        var (superVersion, superHash) = await DraftAsync(run, Super, Subject, 2, """{"field": "city", "value": "Goldother"}""");
        await run.SendAsync(Super, Post, rules, SaveBody(2, """{"field": "city", "value": "Goldother"}""", "Why", superVersion, superHash));
        await run.AppendRowsAsync("the refused saves");
    }

    // Save a rule for each kind of member, save the same access again (409), save on a stale version (409), revoke it by another operator (403), by a super admin, again (409), and the revoke refusals.
    private static async Task ClassAccessSaveRevokeAsync(GoldenScenario run)
    {
        var rules = $"/admin/class-access/members/{Subject}/rules";
        var (version, hash) = await DraftAsync(run, Gents, Subject, 1, Ville);
        var saved = await run.SendAsync(Gents, Post, rules, SaveBody(1, Ville, "  Teaches there  ", version, hash));
        var current = AccessGoldenScenarios.StringOf(saved.Json, "version");
        var ruleId = saved.Json!["rules"]![0]!["id"]!.GetValue<int>();
        await run.SendAsync(Gents, Post, rules, SaveBody(1, Ville, "Again", current, hash));
        await run.SendAsync(Gents, Post, rules, SaveBody(1, Ville, "Stale", version, hash));
        var (_, levelHash) = await DraftAsync(run, Gents, Subject, 1, """{"field": "level", "value": 2}""");
        await run.SendAsync(Gents, Post, rules, SaveBody(1, Ville, "Wrong draft", current, levelHash));
        await SaveForAsync(run, GoldenSeed.OddName);
        await SaveForAsync(run, GoldenSeed.EmptyName);
        var revoke = $"/admin/class-access/rules/{ruleId}/revoke";
        await run.SendAsync(null, Post, revoke, RevokeBody("Moved", current));
        await run.SendAsync(Plain, Post, revoke, RevokeBody("Moved", current));
        await run.SendAsync(GoldenSeed.PeerGentsAdmin, Post, revoke, RevokeBody("Moved", current));
        await run.SendAsync(Gents, Post, revoke, "not json");
        await run.SendAsync(Gents, Post, revoke, """{"version": "x"}""");
        await run.SendAsync(Gents, Post, revoke, """{"reason": "Moved"}""");
        await run.SendAsync(Gents, Post, revoke, RevokeBody("   ", current));
        await run.SendAsync(Gents, Post, "/admin/class-access/rules/99999999/revoke", RevokeBody("Moved", current));
        await run.SendAsync(Gents, Post, revoke, RevokeBody("Moved", "0:0000000000000000"));
        await run.SendAsync(Super, Post, revoke, RevokeBody("  Moved  ", current));
        await run.SendAsync(Super, Post, revoke, RevokeBody("Moved again", current));
        await run.SendAsync(Gents, Get, $"/admin/class-access/members/{Subject}");
    }

    private static async Task SaveForAsync(GoldenScenario run, int member)
    {
        var (version, hash) = await DraftAsync(run, Gents, member, 1, Ville);
        await run.SendAsync(Gents, Post, $"/admin/class-access/members/{member}/rules", SaveBody(1, Ville, "Rule for " + member, version, hash));
    }

    private static async Task<(string Version, string Hash)> DraftAsync(GoldenScenario run, int caller, int member, int gender, string condition)
    {
        var view = await run.SendAsync(caller, Get, $"/admin/class-access/members/{member}");
        var preview = await run.SendAsync(caller, Post, "/admin/class-access/preview", $$"""{"gender": {{gender}}, "conditions": [{{condition}}]}""");
        return (AccessGoldenScenarios.StringOf(view.Json, "version"), AccessGoldenScenarios.StringOf(preview.Json, "previewHash"));
    }

    private static string SaveBody(int gender, string condition, string reason, string version, string hash) =>
        $$"""{"gender": {{gender}}, "conditions": [{{condition}}], "reason": "{{reason}}", "version": "{{version}}", "previewHash": "{{hash}}"}""";

    private static string RevokeBody(string reason, string version) => $$"""{"reason": "{{reason}}", "version": "{{version}}"}""";
}
