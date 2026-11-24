using System.Text.Json.Nodes;

namespace Tsr.Db.Tests;

/// <summary>
/// The scenarios behind identity's golden files (issue 102): each is a fixed list of requests on its own copy of the seeded database. <see cref="Routes"/> are the answers of the
/// nine routes and their refusals (TC-IDN-R1-01), <see cref="Writes"/> the writes with every row and event after each (TC-IDN-R6-01), <see cref="SignInOutcomes"/> what the sign-in
/// judges (TC-IDN-R2-01) and <see cref="SignInWrites"/> what it stores (TC-IDN-R3-01). The headers of a request are not in a transcript, so the label of each request says what was sent.
/// </summary>
internal static class IdentityGoldenScenarios
{
    private const string FeedbackBody = """{"clientId":"c-1","text":"salaam"}""";
    private const string Raise = "/admin/deletion-requests";
    private const string Mine = "/me/deletion-request";

    private static readonly HttpMethod Get = HttpMethod.Get;
    private static readonly HttpMethod Post = HttpMethod.Post;
    private static readonly HttpMethod Delete = HttpMethod.Delete;

    public static IReadOnlyDictionary<string, Func<IdentityRun, Task>> Routes { get; } = new Dictionary<string, Func<IdentityRun, Task>>
    {
        ["me-get"] = MeGetAsync,
        ["me-create-refused"] = MeCreateRefusedAsync,
        ["me-cancel-refused"] = MeCancelRefusedAsync,
        ["debug-token"] = DebugTokenAsync,
        ["admin-list"] = AdminListAsync,
        ["admin-raise-refused"] = AdminRaiseRefusedAsync,
        ["admin-hold-refused"] = AdminHoldRefusedAsync,
        ["admin-confirm-refused"] = AdminConfirmRefusedAsync,
        ["admin-complete-refused"] = AdminCompleteRefusedAsync,
    };

    public static IReadOnlyDictionary<string, Func<IdentityRun, Task>> Writes { get; } = new Dictionary<string, Func<IdentityRun, Task>>
    {
        ["write-create-cancel"] = CreateAndCancelAsync,
        ["write-raise"] = RaiseAsync,
        ["write-hold"] = HoldAsync,
        ["write-confirm"] = ConfirmAsync,
        ["write-complete-target"] = CompleteTargetAsync,
        ["write-complete-pair"] = CompletePairAsync,
        ["write-complete-no-token"] = CompleteNoTokenAsync,
    };

    public static IReadOnlyDictionary<string, Func<IdentityRun, Task>> SignInOutcomes { get; } = new Dictionary<string, Func<IdentityRun, Task>>
    {
        ["signin-refused"] = SignInRefusedAsync,
        ["signin-unverified"] = SignInUnverifiedAsync,
        ["signin-guest"] = SignInGuestAsync,
        ["signin-live-deletion"] = SignInLiveDeletionAsync,
        ["signin-recently-deleted"] = SignInRecentlyDeletedAsync,
    };

    public static IReadOnlyDictionary<string, Func<IdentityRun, Task>> SignInWrites { get; } = new Dictionary<string, Func<IdentityRun, Task>>
    {
        ["signin-first"] = SignInFirstAsync,
        ["signin-claim"] = SignInClaimAsync,
        ["signin-tracking"] = SignInTrackingAsync,
    };

    /// <summary>The headers of one verified sign-in: the uid, the address, whether the address is verified, and any name, picture and tracking values.</summary>
    internal static List<KeyValuePair<string, string>> Headers(string uid, string email, bool verified = true, string? name = null, string? picture = null, params (string Name, string Value)[] more)
    {
        var headers = TestApi.SignedInAs(uid, email, verified).ToList();
        if (name is not null)
        {
            headers.Add(new(TestApi.Name, name));
        }

        if (picture is not null)
        {
            headers.Add(new(TestApi.Picture, picture));
        }

        headers.AddRange(more.Select(m => new KeyValuePair<string, string>(m.Name, m.Value)));
        return headers;
    }

    internal static string Body(string field, string? value) => new JsonObject { [field] = value }.ToJsonString();

    private static string Url(int id, string action) => $"{Raise}/{id}/{action}";

    // ---- the routes ----

    private static async Task MeGetAsync(IdentityRun run)
    {
        foreach (var token in new[] { IdentitySeed.Plain, IdentitySeed.Unconfirmed, IdentitySeed.Held, IdentitySeed.CancelledMember, IdentitySeed.Finished, IdentitySeed.Admin })
        {
            await run.AsAsync(token, Get, Mine);
        }

        await run.SendAsync("guest", Headers("uid-guest", IdentitySeed.GuestAddress), Get, Mine);
        await run.AsNobodyAsync(Get, Mine);
    }

    private static async Task MeCreateRefusedAsync(IdentityRun run)
    {
        var who = IdentitySeed.Plain;
        await run.AsAsync(who, Post, Mine, "nope");
        await run.AsAsync(IdentitySeed.Unconfirmed, Post, Mine, "[1]");
        await run.AsAsync(who, Post, Mine, """{"reason": 5}""");
        await run.AsAsync(who, Post, Mine, Body("reason", new string('x', 501)));
        await run.AsAsync(who, Post, Mine, Body("reason", "a\0b"));
        await run.AsAsync(IdentitySeed.Unconfirmed, Post, Mine, "{}");
        await run.SendAsync("guest", Headers("uid-guest", IdentitySeed.GuestAddress), Post, Mine, "{}");
        await run.AsNobodyAsync(Post, Mine, "{}");
    }

    private static async Task MeCancelRefusedAsync(IdentityRun run)
    {
        await run.AsAsync(IdentitySeed.Plain, Delete, Mine);
        await run.AsAsync(IdentitySeed.Finished, Delete, Mine);
        await run.AsAsync(IdentitySeed.CancelledMember, Delete, Mine);
        await run.SendAsync("guest", Headers("uid-guest", IdentitySeed.GuestAddress), Delete, Mine);
        await run.AsNobodyAsync(Delete, Mine);
    }

    // The success body is pinned by TestDebugTokenTests; here the three answers that need no signing key.
    private static async Task DebugTokenAsync(IdentityRun run)
    {
        await run.SendAsync("no header", [], Post, "/auth/debug-token");
        await run.SendAsync("a Basic header", [new("Authorization", "Basic abc")], Post, "/auth/debug-token");
        await run.SendAsync("a Bearer that is no token", [new("Authorization", "Bearer garbage")], Post, "/auth/debug-token");
    }

    private static async Task AdminListAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        await run.AsAsync(admin, Get, Raise);
        foreach (var status in new[] { "pending", "awaiting_prize_delivery", "completed", "cancelled", "bogus" })
        {
            await run.AsAsync(admin, Get, Raise + "?status=" + status);
        }

        await run.AsAsync(IdentitySeed.Plain, Get, Raise);
        await run.SendAsync("guest", Headers("uid-guest", IdentitySeed.GuestAddress), Get, Raise);
        await run.AsNobodyAsync(Get, Raise);
    }

    private static async Task AdminRaiseRefusedAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        await run.AsAsync(admin, Post, Raise, "nope");
        await run.AsAsync(admin, Post, Raise, "[1]");
        await run.AsAsync(admin, Post, Raise, "{}");
        await run.AsAsync(admin, Post, Raise, """{"email": 5}""");
        await run.AsAsync(admin, Post, Raise, Body("email", "   "));
        await run.AsAsync(admin, Post, Raise, Body("email", "a\0b@example.invalid"));
        await run.AsAsync(admin, Post, Raise, Body("email", "nobody.here@example.invalid"));
        await run.AsAsync(admin, Post, Raise, Body("email", IdentitySeed.GuestAddress));
        await run.AsAsync(IdentitySeed.Plain, Post, Raise, Body("email", IdentitySeed.ClaimAddress));
        await run.AsNobodyAsync(Post, Raise, Body("email", IdentitySeed.ClaimAddress));
    }

    private static async Task AdminHoldRefusedAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        foreach (var id in new[] { "abc", "0", "9899999" })
        {
            await run.AsAsync(admin, Post, $"{Raise}/{id}/hold", "{}");
        }

        await run.AsAsync(admin, Post, Url(IdentitySeed.HeldRequest, "hold"), "nope");
        await run.AsAsync(admin, Post, Url(IdentitySeed.HeldRequest, "hold"), """{"note": 5}""");
        await run.AsAsync(admin, Post, Url(IdentitySeed.HeldRequest, "hold"), Body("note", new string('n', 501)));
        await run.AsAsync(admin, Post, Url(IdentitySeed.HeldRequest, "hold"), Body("note", "a\0b"));
        await run.AsAsync(admin, Post, Url(IdentitySeed.CompletedRecent, "hold"), "{}");
        await run.AsAsync(IdentitySeed.Plain, Post, Url(IdentitySeed.HeldRequest, "hold"), "{}");
        await run.AsNobodyAsync(Post, Url(IdentitySeed.HeldRequest, "hold"), "{}");
    }

    private static async Task AdminConfirmRefusedAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        foreach (var id in new[] { "abc", "0", "9899999" })
        {
            await run.AsAsync(admin, Post, $"{Raise}/{id}/confirmation-sent");
        }

        await run.AsAsync(admin, Post, Url(IdentitySeed.CompletedRecent, "confirmation-sent"));
        await run.AsAsync(admin, Post, Url(IdentitySeed.CancelledRequest, "confirmation-sent"));
        await run.AsAsync(admin, Post, Url(IdentitySeed.HeldRequest, "confirmation-sent"));
        await run.AsAsync(IdentitySeed.Plain, Post, Url(IdentitySeed.HeldRequest, "confirmation-sent"));
        await run.AsNobodyAsync(Post, Url(IdentitySeed.HeldRequest, "confirmation-sent"));
    }

    // Each refusal of a completion; none writes. A completion the rate limit stopped is asked twice: the limit is the first answer of the second.
    private static async Task AdminCompleteRefusedAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        foreach (var id in new[] { "abc", "0", "9899999" })
        {
            await run.AsAsync(admin, Post, $"{Raise}/{id}/complete");
        }

        foreach (var id in new[]
        {
            IdentitySeed.GuestRequest, IdentitySeed.PendingUnconfirmed, IdentitySeed.CompletedRecent, IdentitySeed.CancelledRequest, IdentitySeed.DemoRequest,
            IdentitySeed.SharedRequest, IdentitySeed.NoRowsRequest, IdentitySeed.CrowdedRequest, IdentitySeed.PendingUnconfirmed,
        })
        {
            await run.AsAsync(admin, Post, Url(id, "complete"));
        }

        await run.AsAsync(IdentitySeed.Plain, Post, Url(IdentitySeed.PendingConfirmedTarget, "complete"));
        await run.AsNobodyAsync(Post, Url(IdentitySeed.PendingConfirmedTarget, "complete"));
        await run.RowsAsync("the refused completions");
    }

    // ---- the writes, each followed by every row and event ----

    private static async Task CreateAndCancelAsync(IdentityRun run)
    {
        await Step(run, "a new request", () => run.AsAsync(IdentitySeed.Plain, Post, Mine, Body("reason", IdentitySeed.Odd)));
        await Step(run, "the same again", () => run.AsAsync(IdentitySeed.Plain, Post, Mine, "{}"));
        await Step(run, "cancelled", () => run.AsAsync(IdentitySeed.Plain, Delete, Mine));
        await Step(run, "cancelled again", () => run.AsAsync(IdentitySeed.Plain, Delete, Mine));
        await Step(run, "a member with no profile", () => run.SendAsync("uid-900113 (no profile)", Headers("uid-" + IdentitySeed.DupHolder, "DUP.Shared@Example.invalid"), Post, Mine, "{}"));
        await Step(run, "a seeded request cancelled", () => run.AsAsync(IdentitySeed.Unconfirmed, Delete, Mine));
        await Step(run, "a request after completion", () => run.AsAsync(IdentitySeed.Finished, Delete, Mine));
    }

    private static async Task RaiseAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        await Step(run, "raised by address in other case", () => run.AsAsync(admin, Post, Raise, Body("email", "M900102@EXAMPLE.INVALID")));
        await Step(run, "raised again", () => run.AsAsync(admin, Post, Raise, Body("email", "M900102@EXAMPLE.INVALID")));
        await Step(run, "a member with a live request", () => run.AsAsync(admin, Post, Raise, Body("email", MembershipTestKit.EmailOf(IdentitySeed.Target))));
        await Step(run, "an address held by two rows", () => run.AsAsync(admin, Post, Raise, Body("email", "  dup.shared@example.invalid  ")));
        await Step(run, "a trimmed address", () => run.AsAsync(admin, Post, Raise, Body("email", "  " + IdentitySeed.ClaimAddress + "  ")));
    }

    private static async Task HoldAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        await Step(run, "a pending request held", () => run.AsAsync(admin, Post, Url(IdentitySeed.PendingUnconfirmed, "hold"), Body("note", IdentitySeed.Odd)));
        await Step(run, "held again with no note", () => run.AsAsync(admin, Post, Url(IdentitySeed.PendingUnconfirmed, "hold"), """{"note": null}"""));
        await Step(run, "a held request, a blank note", () => run.AsAsync(admin, Post, Url(IdentitySeed.HeldRequest, "hold"), Body("note", "  ")));
        await Step(run, "a request with no member", () => run.AsAsync(admin, Post, Url(IdentitySeed.NoTokenRequest, "hold"), "{}"));
        await Step(run, "a settled request", () => run.AsAsync(admin, Post, Url(IdentitySeed.CompletedRecent, "hold"), "{}"));
    }

    private static async Task ConfirmAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        await Step(run, "a first confirmation", () => run.AsAsync(admin, Post, Url(IdentitySeed.PendingUnconfirmed, "confirmation-sent")));
        await Step(run, "a second confirmation", () => run.AsAsync(admin, Post, Url(IdentitySeed.PendingUnconfirmed, "confirmation-sent")));
        await Step(run, "a settled request", () => run.AsAsync(admin, Post, Url(IdentitySeed.CompletedRecent, "confirmation-sent")));
    }

    private static async Task CompleteTargetAsync(IdentityRun run)
    {
        var admin = IdentitySeed.Admin;
        await run.RowsAsync("before");
        await Step(run, "the target completed", () => run.AsAsync(admin, Post, Url(IdentitySeed.PendingConfirmedTarget, "complete")));
        await Step(run, "completed again", () => run.AsAsync(admin, Post, Url(IdentitySeed.PendingConfirmedTarget, "complete")));
        await Step(run, "the list after", () => run.AsAsync(admin, Get, Raise));
    }

    private static async Task CompletePairAsync(IdentityRun run)
    {
        await Step(run, "a token held by two rows", () => run.AsAsync(IdentitySeed.Admin, Post, Url(IdentitySeed.PairRequest, "complete")));
    }

    private static async Task CompleteNoTokenAsync(IdentityRun run)
    {
        await Step(run, "a request with no member", () => run.AsAsync(IdentitySeed.Admin, Post, Url(IdentitySeed.NoTokenRequest, "complete")));
    }

    // ---- the sign-in ----

    private static async Task BothRoutesAsync(IdentityRun run, string who, List<KeyValuePair<string, string>> headers)
    {
        await run.SendAsync(who + ", create route", headers, Post, "/auth/link");
        await run.SendAsync(who + ", lookup route", headers, Post, "/feedback", FeedbackBody);
    }

    private static async Task SignInRefusedAsync(IdentityRun run)
    {
        foreach (var outcome in new[] { "missing", "invalid", "noemail" })
        {
            await BothRoutesAsync(run, outcome, [new(TestApi.Outcome, outcome)]);
        }
    }

    private static async Task SignInUnverifiedAsync(IdentityRun run)
    {
        await BothRoutesAsync(run, "an unverified address of a member with no uid", Headers("uid-new", IdentitySeed.ClaimAddress, verified: false));
        await BothRoutesAsync(run, "an unverified address of a member with a uid", Headers("uid-new", MembershipTestKit.EmailOf(IdentitySeed.Plain), verified: false));
        await run.SendAsync("an unknown address, lookup route", Headers("uid-nobody", "nobody.here@example.invalid"), Post, "/feedback", FeedbackBody);
        await run.RowsAsync("the refused sign-ins");
    }

    private static async Task SignInGuestAsync(IdentityRun run)
    {
        await BothRoutesAsync(run, "the guest row", Headers("uid-guest", IdentitySeed.GuestAddress));
        await BothRoutesAsync(run, "the guest row by address", Headers("uid-other", IdentitySeed.GuestAddress));
        await run.RowsAsync("the guest sign-ins");
    }

    private static async Task SignInLiveDeletionAsync(IdentityRun run)
    {
        await BothRoutesAsync(run, "a pending deletion", Headers("uid-" + IdentitySeed.Unconfirmed, MembershipTestKit.EmailOf(IdentitySeed.Unconfirmed)));
        await BothRoutesAsync(run, "a deletion held for a prize", Headers("uid-" + IdentitySeed.Held, MembershipTestKit.EmailOf(IdentitySeed.Held)));
        await BothRoutesAsync(run, "a cancelled deletion", Headers("uid-" + IdentitySeed.CancelledMember, MembershipTestKit.EmailOf(IdentitySeed.CancelledMember)));
        // On the allow list (/me, the three deletion routes, DELETE /devices) and off it (/me/permissions, POST /devices); the cancel is last, it ends the live request.
        foreach (var (method, path) in new[] { (Get, "/me"), (Get, "/me/permissions"), (Post, "/devices"), (Delete, "/devices"), (Get, Mine), (Delete, Mine) })
        {
            await run.AsAsync(IdentitySeed.Unconfirmed, method, path, method == Post ? "{}" : null);
        }

        await run.RowsAsync("the refused sign-ins");
    }

    private static async Task SignInRecentlyDeletedAsync(IdentityRun run)
    {
        await BothRoutesAsync(run, "an address deleted an hour ago, in other case", Headers("uid-new", "REVIVED.one@example.invalid"));
        await run.RowsAsync("the refused sign-ins");
    }

    private static async Task SignInFirstAsync(IdentityRun run)
    {
        var first = Headers("uid-first", "first.one@example.invalid", true, IdentitySeed.Odd, "https://img.invalid/p?a=1&b=2+3", ("User-Agent", "FirstUA/1.0"));
        await Step(run, "a first sign-in with name and picture", () => run.SendAsync("uid-first, name and picture", first, Post, "/auth/link"));
        await Step(run, "the same again", () => run.SendAsync("uid-first, name and picture", first, Post, "/auth/link"));
        await Step(run, "a first sign-in with no name", () => run.SendAsync("uid-second, no name", Headers("uid-second", "second.one@example.invalid"), Post, "/auth/link"));
        await Step(run, "an address deleted three hours ago", () => run.SendAsync("uid-again, address of an old deletion", Headers("uid-again", "Old.One@Example.invalid"), Post, "/auth/link"));
    }

    private static async Task SignInClaimAsync(IdentityRun run)
    {
        await Step(run, "a claim on a lookup route", () => run.SendAsync("uid-claim-a, verified", Headers("uid-claim-a", IdentitySeed.ClaimAddress, name: "Ignored Name"), Post, "/feedback", FeedbackBody));
        await Step(run, "the same uid again", () => run.SendAsync("uid-claim-a, verified", Headers("uid-claim-a", IdentitySeed.ClaimAddress), Post, "/feedback", FeedbackBody));
        await Step(run, "a claim on a create route", () => run.SendAsync(
            "uid-dup-new, verified, name and picture", Headers("uid-dup-new", IdentitySeed.DupAddress, name: IdentitySeed.Odd, picture: "https://img.invalid/dup"), Post, "/auth/link"));
        await Step(run, "a create route overwrites another uid", () => run.SendAsync(
            "uid-plain-new, verified, name", Headers("uid-plain-new", MembershipTestKit.EmailOf(IdentitySeed.Plain), name: "Plain New"), Post, "/auth/link"));
        await Step(run, "a lookup route keeps another uid", () => run.SendAsync(
            "uid-admin-new, verified", Headers("uid-admin-new", MembershipTestKit.EmailOf(IdentitySeed.Admin)), Post, "/feedback", FeedbackBody));
    }

    private static async Task SignInTrackingAsync(IdentityRun run)
    {
        var all = Headers(
            "uid-" + IdentitySeed.Plain, MembershipTestKit.EmailOf(IdentitySeed.Plain), true, null, null,
            ("X-Forwarded-For", "203.0.113.9"), ("User-Agent", "AllUA/2.0 + <x>"), ("X-Device-Info", "Pixel \"9\""), ("X-Platform-Info", "Android 15"), ("X-App-Version", "1.0.2+10"));
        await Step(run, "every tracking header", () => run.SendAsync("plain, every tracking header", all, Post, "/feedback", FeedbackBody));
        await Step(run, "one tracking header", () => run.SendAsync(
            "admin, X-Device-Info only", Headers("uid-" + IdentitySeed.Admin, MembershipTestKit.EmailOf(IdentitySeed.Admin), true, null, null, ("X-Device-Info", "Tablet")), Post, "/feedback", FeedbackBody));
        await Step(run, "no tracking header", () => run.SendAsync(
            "cancelled member, no tracking header", Headers("uid-" + IdentitySeed.CancelledMember, MembershipTestKit.EmailOf(IdentitySeed.CancelledMember)), Post, "/feedback", FeedbackBody));
        await Step(run, "two rows whose addresses differ only in case", () => run.SendAsync(
            "uid-900113, user agent", Headers("uid-" + IdentitySeed.DupHolder, "dup.shared@example.invalid", true, null, null, ("User-Agent", "TwinUA/3.0")), Post, "/feedback", FeedbackBody));
        await Step(run, "values longer than their columns", () => run.SendAsync(
            "finished member, device of 201 characters", Headers("uid-" + IdentitySeed.Finished, MembershipTestKit.EmailOf(IdentitySeed.Finished), true, null, null, ("X-Device-Info", new string('d', 201))), Post, "/feedback", FeedbackBody));
    }

    // One request, then every row and event as they are after it.
    private static async Task Step(IdentityRun run, string label, Func<Task<GoldenReply>> send)
    {
        await send();
        await run.RowsAsync(label);
    }
}
