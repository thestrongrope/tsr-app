using System.Text.Json.Nodes;

namespace Tsr.Db.Tests;

/// <summary>
/// The scenarios behind the golden files: each is a fixed list of requests on its own copy of the seeded database. A request that needs a value an earlier
/// answer gave (a version, a preview hash, a grant id) reads it from that answer, so nothing is typed in that a different run could change.
/// </summary>
internal static partial class AccessGoldenScenarios
{
    private const string Ville = """{"field": "city", "value": "Goldville"}""";

    private static readonly HttpMethod Get = HttpMethod.Get;
    private static readonly HttpMethod Post = HttpMethod.Post;

    /// <summary>TC-ACC-R1-01: the three read routes (task 1) and the ten admin routes with their refusals (task 2).</summary>
    public static IReadOnlyDictionary<string, Func<GoldenScenario, Task>> Routes { get; } = new Dictionary<string, Func<GoldenScenario, Task>>
    {
        ["read-super"] = run => ReadRoutesAsync(run, GoldenSeed.Super),
        ["read-gents-admin"] = run => ReadRoutesAsync(run, GoldenSeed.GentsAdmin),
        ["read-plain-enrolled"] = run => ReadRoutesAsync(run, GoldenSeed.Plain),
        ["read-teacher"] = run => ReadRoutesAsync(run, GoldenSeed.Teacher),
        ["read-unsigned"] = run => ReadRoutesAsync(run, null),
        ["read-etag"] = ReadEtagAsync,
        ["admin-perm-reads-super"] = AdminPermReadsAsync,
        ["admin-perm-reads-refused"] = AdminPermReadsRefusedAsync,
        ["admin-perm-grant-refusals"] = AdminPermGrantRefusalsAsync,
        ["admin-perm-grant-revoke"] = AdminPermGrantRevokeAsync,
        ["class-access-reads-gents"] = run => ClassAccessReadsAsync(run, GoldenSeed.GentsAdmin),
        ["class-access-reads-super"] = run => ClassAccessReadsAsync(run, GoldenSeed.Super),
        ["class-access-reads-refused"] = ClassAccessReadsRefusedAsync,
        ["class-access-save-refusals"] = ClassAccessSaveRefusalsAsync,
        ["class-access-save-revoke"] = ClassAccessSaveRevokeAsync,
    };

    /// <summary>TC-ACC-R2-01 and R2-02: the writes, with the stored rows and event payloads after each (task 3).</summary>
    public static IReadOnlyDictionary<string, Func<GoldenScenario, Task>> Writes { get; } = new Dictionary<string, Func<GoldenScenario, Task>>
    {
        ["write-permission-grant-revoke"] = GrantAndRevokeAsync,
        ["write-rule-save-revoke"] = RuleSaveAndRevokeAsync,
        ["write-rule-condition-order"] = ConditionOrderAsync,
    };

    // GET /me/permissions, one action the caller holds in some scope, one it may not hold, one the catalog lacks, and the legacy list.
    private static async Task ReadRoutesAsync(GoldenScenario run, int? caller)
    {
        await run.SendAsync(caller, Get, "/me/permissions");
        await run.SendAsync(caller, Get, "/me/permissions/donors:read");
        await run.SendAsync(caller, Get, "/me/permissions/permissions:manage");
        await run.SendAsync(caller, Get, "/me/permissions/classes:read");
        await run.SendAsync(caller, Get, "/me/permissions/nothing:here");
        await run.SendAsync(caller, Get, "/user/permissions");
    }

    // 304 on a matching tag (exact, weak, in a list, star) and 200 on a tag that does not match.
    private static async Task ReadEtagAsync(GoldenScenario run)
    {
        var first = await run.SendAsync(GoldenSeed.Super, Get, "/me/permissions");
        var tag = "\"" + first.Json!["revision"]!.GetValue<string>() + "\"";
        await run.SendAsync(GoldenSeed.Super, Get, "/me/permissions", ifNoneMatch: tag);
        await run.SendAsync(GoldenSeed.Super, Get, "/me/permissions", ifNoneMatch: "W/" + tag);
        await run.SendAsync(GoldenSeed.Super, Get, "/me/permissions", ifNoneMatch: "\"other\", " + tag);
        await run.SendAsync(GoldenSeed.Super, Get, "/me/permissions", ifNoneMatch: "*");
        await run.SendAsync(GoldenSeed.Super, Get, "/me/permissions", ifNoneMatch: "\"other\"");
    }

    internal static string StringOf(JsonNode? node, string key) => node![key]!.GetValue<string>();
}
