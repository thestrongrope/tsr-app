using System.Globalization;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Tsr.Identity.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The golden set-up of identity's characterisation tests (issue 102, plan "Golden files"): the template <c>identity_golden_template</c>, migrated as production and seeded with
/// <see cref="IdentitySeed"/>, and <see cref="IdentityRun"/>, a <see cref="GoldenScenario"/> that also records every call the account-service port received. Every row query
/// reads a table a route or a sign-in writes, ordered by its key, so a golden file is the same on every run.
/// </summary>
internal static class IdentityGolden
{
    public static GoldenSet Set { get; } = new(
        "identity",
        "identity_golden_template",
        IdentitySeed.RunAsync,
        [
            "identity.users|select row_to_json(t)::text from identity.users t order by t.id",
            "identity.account_deletion_requests|select row_to_json(t)::text from identity.account_deletion_requests t order by t.id",
            "membership.member_profiles|select row_to_json(t)::text from membership.member_profiles t order by t.user_id",
            "notifications.user_devices|select row_to_json(t)::text from notifications.user_devices t order by t.id",
            "notifications.member_event_settings|select row_to_json(t)::text from notifications.member_event_settings t order by t.user_id, t.class_id, t.event_key",
            // The feedback route a lookup-route sign-in reaches stamps created_at from the database's own clock, which a golden file cannot hold.
            "platform.feedback (without created_at)|select (to_jsonb(t) - 'created_at')::text from platform.feedback t order by t.id",
            "platform.outbound_messages|select row_to_json(t)::text from platform.outbound_messages t order by t.id",
            "platform.outbox (created_at, event_type, payload)|select to_json(t.created_at)::text || ' | ' || t.event_type || ' | ' || t.payload::text from platform.outbox t order by t.created_at, t.event_type, t.payload::text",
        ],
        null);
}

/// <summary>A scenario on the identity template, with the recording account service in place of the real one.</summary>
internal sealed class IdentityRun : IAsyncDisposable
{
    private readonly RecordingFirebase firebase;

    private IdentityRun(GoldenScenario run, RecordingFirebase firebase)
    {
        Run = run;
        this.firebase = firebase;
    }

    public GoldenScenario Run { get; }

    public string Transcript => Run.Transcript;

    /// <summary>A fresh copy of the identity template; <paramref name="configure"/> replaces more services of the API.</summary>
    public static async Task<IdentityRun> StartAsync(string name, Action<IServiceCollection>? configure = null)
    {
        var firebase = new RecordingFirebase();
        var run = await GoldenScenario.StartAsync(
            name,
            services =>
            {
                services.AddSingleton<IFirebaseAccounts>(firebase);
                configure?.Invoke(services);
            },
            IdentityGolden.Set);
        return new IdentityRun(run, firebase);
    }

    /// <summary>Sends one request signed in as one seeded member (uid and address as the seed gives them), then writes the account-service calls it made.</summary>
    public Task<GoldenReply> AsAsync(int token, HttpMethod method, string path, string? json = null) =>
        SendAsync(token.ToString(CultureInfo.InvariantCulture), [.. TestApi.SignedInAs("uid-" + token, MembershipTestKit.EmailOf(token))], method, path, json);

    /// <summary>Sends one request with these headers, then writes the account-service calls it made, in order, after the answer.</summary>
    public async Task<GoldenReply> SendAsync(string who, IReadOnlyList<KeyValuePair<string, string>> headers, HttpMethod method, string path, string? json = null, bool recordBody = true)
    {
        var reply = await Run.SendAsync(who, headers, method, path, json, recordBody);
        foreach (var call in firebase.Drain())
        {
            Run.Note(call);
        }

        return reply;
    }

    /// <summary>A request with nobody signed in.</summary>
    public Task<GoldenReply> AsNobodyAsync(HttpMethod method, string path, string? json = null) =>
        SendAsync("nobody", [new(TestApi.Outcome, "missing")], method, path, json);

    public Task RowsAsync(string label) => Run.AppendRowsAsync(label);

    public ValueTask DisposeAsync() => Run.DisposeAsync();
}

/// <summary>The account service as a recording fake: what it was asked, in order, as transcript lines. A seeded address with no stored uid answers <c>fb-&lt;local part&gt;</c>; any other has no account.</summary>
internal sealed class RecordingFirebase : IFirebaseAccounts
{
    private readonly List<string> calls = [];

    public Task<string?> FindUidByEmailAsync(string email, CancellationToken ct)
    {
        var known = IdentitySeed.NoUidAddresses.Contains(email, StringComparer.OrdinalIgnoreCase);
        var uid = known ? "fb-" + email[..email.IndexOf('@', StringComparison.Ordinal)] : null;
        Add("firebase: lookup " + email + " -> " + (uid ?? "(none)"));
        return Task.FromResult(uid);
    }

    public Task DeleteAsync(string? uid, string? email, CancellationToken ct)
    {
        Add("firebase: delete " + uid);
        return Task.CompletedTask;
    }

    public List<string> Drain()
    {
        lock (calls)
        {
            var taken = calls.ToList();
            calls.Clear();
            return taken;
        }
    }

    private void Add(string line)
    {
        lock (calls)
        {
            calls.Add(line);
        }
    }
}

/// <summary>
/// The synthetic members and requests of the identity goldens: tokens 900101 to 900199, addresses on .invalid (one on @demo.invalid, the reviewer cohort), request ids 9800001 and up.
/// Every timestamp is a literal relative to the scenarios' fixed instant (2026-01-01T00:00:00Z); nothing reads the database's clock. Every free text holds a plus, quotes, angle brackets,
/// an ampersand, an HTML entity and non-ASCII text, so an encoder slip or a lost entity decode shows in a golden file.
/// </summary>
internal static class IdentitySeed
{
    public const int Admin = 900101;
    public const int Plain = 900102;
    public const int Target = 900110;
    public const int Pair = 900111;
    public const int DupNoUid = 900112;
    public const int DupHolder = 900113;
    public const int Demo = 900114;
    public const int Claimable = 900115;
    public const int Unconfirmed = 900116;
    public const int Held = 900117;
    public const int CancelledMember = 900118;
    public const int Revived = 900119;
    public const int Purgeable = 900120;
    public const int Finished = 900121;
    public const int NoRows = 900191;
    public const int Crowded = 900192;

    public const int PendingUnconfirmed = 9800001;
    public const int PendingConfirmedTarget = 9800002;
    public const int HeldRequest = 9800003;
    public const int CancelledRequest = 9800004;
    public const int CompletedRecent = 9800005;
    public const int CompletedOld = 9800006;
    public const int DemoRequest = 9800007;
    public const int SharedRequest = 9800008;
    public const int PairRequest = 9800009;
    public const int NoTokenRequest = 9800010;
    public const int GuestRequest = 9800011;
    public const int NoRowsRequest = 9800012;
    public const int CrowdedRequest = 9800013;
    public const int FinishedRequest = 9800014;

    /// <summary>The address of the Pair member's second row, and of the shared-address row: rows with no stored uid, which the account service finds an account for.</summary>
    public static readonly string[] NoUidAddresses = ["nouid.900111@example.invalid", "dup.shared@example.invalid", "claim.me@example.invalid"];

    public const string GuestAddress = "guest@example.invalid";
    public const string ClaimAddress = "claim.me@example.invalid";
    public const string DupAddress = "dup.shared@example.invalid";

    /// <summary>A text with a plus, quotes, angle brackets, an ampersand, an HTML entity and Arabic and accented letters.</summary>
    public const string Odd = "Zoë \"Q\" <b> + & &amp; أحمد Ünï";

    public static async Task RunAsync(string ownerConnection)
    {
        var sql = new StringBuilder();
        User(sql, Admin, MembershipTestKit.EmailOf(Admin), "uid-" + Admin);
        User(sql, Plain, MembershipTestKit.EmailOf(Plain), "uid-" + Plain);
        User(sql, Target, MembershipTestKit.EmailOf(Target), "uid-" + Target);
        User(sql, Pair, MembershipTestKit.EmailOf(Pair), "uid-" + Pair);
        User(sql, Pair, "nouid.900111@example.invalid", null);
        User(sql, DupNoUid, DupAddress, null);
        User(sql, DupHolder, "DUP.Shared@Example.invalid", "uid-" + DupHolder);
        User(sql, Demo, "m900114@demo.invalid", "uid-" + Demo);
        User(sql, Claimable, ClaimAddress, null);
        User(sql, Unconfirmed, MembershipTestKit.EmailOf(Unconfirmed), "uid-" + Unconfirmed);
        User(sql, Held, MembershipTestKit.EmailOf(Held), "uid-" + Held);
        User(sql, CancelledMember, MembershipTestKit.EmailOf(CancelledMember), "uid-" + CancelledMember);
        User(sql, Finished, MembershipTestKit.EmailOf(Finished), "uid-" + Finished);
        User(sql, 0, GuestAddress, "uid-guest");
        for (var i = 1; i <= 21; i++)
        {
            User(sql, Crowded, $"crowd-{i}@example.invalid", null);
        }

        sql.Append(CultureInfo.InvariantCulture, $"insert into access.user_roles (user_id, roleid) select id, 1 from identity.users where token = {Admin}; ");
        Profile(sql, MembershipTestKit.EmailOf(Admin), "Gold Admin", null, null, null);
        Profile(sql, MembershipTestKit.EmailOf(Plain), Odd, "https://img.invalid/p?a=1&b=2+3", null, null);
        Profile(sql, MembershipTestKit.EmailOf(Target), Odd + " Target", "https://img.invalid/900110", "+15550900110", "90011");
        Profile(sql, MembershipTestKit.EmailOf(Pair), "Pair One", null, "+15550900111", null);
        Profile(sql, "m900114@demo.invalid", "Demo Reviewer", null, null, null);
        Profile(sql, ClaimAddress, "Claim Old", "https://img.invalid/old", null, null);
        Profile(sql, MembershipTestKit.EmailOf(Unconfirmed), "Unconfirmed Member", null, null, null);
        Profile(sql, MembershipTestKit.EmailOf(Held), "Held Member + <i>", null, "+15550900117", "90017");
        Profile(sql, MembershipTestKit.EmailOf(CancelledMember), "Cancelled Member", null, null, null);
        Profile(sql, MembershipTestKit.EmailOf(Finished), "Finished Member", null, null, null);

        Requests(sql);
        Erasable(sql);

        await using var connection = new NpgsqlConnection(ownerConnection);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(sql.ToString(), connection);
        await command.ExecuteNonQueryAsync();
    }

    // A member with stored tracking values when it has a uid, so a sign-in that sends none (or some) has something to keep and a careless write has something to wipe.
    private static void User(StringBuilder sql, int token, string email, string? uid)
    {
        var tracking = uid is null
            ? "null, null, null, null, null, null"
            : "timestamptz '2025-12-01 08:00:00+00', '198.51.100.7', 'Old UA', 'Old phone', 'Old OS', '0.9'";
        sql.Append(CultureInfo.InvariantCulture,
            $"insert into identity.users (token, email, firebase_uid, provider, createdon, lastlogin, lastloginip, lastdevice, device, platform, version) values ({token}, {MembershipTestKit.Quote(email)}, {MembershipTestKit.Quote(uid)}, {(uid is null ? "null" : "'firebase'")}, timestamptz '2025-06-01 00:00:00+00', {tracking}); ");
    }

    private static void Profile(StringBuilder sql, string email, string name, string? picture, string? mobile, string? zip) =>
        sql.Append(CultureInfo.InvariantCulture,
            $"insert into membership.member_profiles (user_id, name, picture, mobile, zip) select id, {MembershipTestKit.Quote(name)}, {MembershipTestKit.Quote(picture)}, {MembershipTestKit.Quote(mobile ?? string.Empty)}, {MembershipTestKit.Quote(zip)} from identity.users where email = {MembershipTestKit.Quote(email)} and token <> 0 order by id limit 1; ");

    private static void Requests(StringBuilder sql)
    {
        const string cols = "id, token, status, source, reason, contact_name, contact_email, requested_at, operator_note, confirmation_sent_at, completed_at, cancelled_at, handled_by";
        var odd = MembershipTestKit.Quote(Odd);
        sql.Append(CultureInfo.InvariantCulture, $"insert into identity.account_deletion_requests ({cols}) values ");
        sql.Append(CultureInfo.InvariantCulture, $"({PendingUnconfirmed}, {Unconfirmed}, 'pending', 'app', {odd}, 'Unconfirmed Contact', '{MembershipTestKit.EmailOf(Unconfirmed)}', timestamptz '2025-12-30 10:00:00+00', null, null, null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({PendingConfirmedTarget}, {Target}, 'pending', 'app', 'Please delete + \"all\" of it', {odd}, '{MembershipTestKit.EmailOf(Target)}', timestamptz '2025-12-30 11:00:00+00', null, timestamptz '2025-12-31 11:00:00+00', null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({HeldRequest}, {Held}, 'awaiting_prize_delivery', 'web', 'Prize <soon>', 'Held Contact', '{MembershipTestKit.EmailOf(Held)}', timestamptz '2025-12-30 12:00:00+00', {odd}, timestamptz '2025-12-31 12:00:00+00', null, null, {Admin}), ");
        sql.Append(CultureInfo.InvariantCulture, $"({CancelledRequest}, {CancelledMember}, 'cancelled', 'app', 'changed my mind', 'Cancelled Contact', '{MembershipTestKit.EmailOf(CancelledMember)}', timestamptz '2025-12-30 13:00:00+00', null, null, null, timestamptz '2025-12-31 13:00:00+00', null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({CompletedRecent}, {Revived}, 'completed', 'app', 'gone', 'Revived Contact', 'Revived.One@Example.invalid', timestamptz '2025-12-31 20:00:00+00', null, timestamptz '2025-12-31 21:00:00+00', timestamptz '2025-12-31 23:00:00+00', null, {Admin}), ");
        sql.Append(CultureInfo.InvariantCulture, $"({CompletedOld}, {Purgeable}, 'completed', 'app', 'gone long ago', 'Old Contact', 'old.one@example.invalid', timestamptz '2025-12-31 18:00:00+00', null, timestamptz '2025-12-31 19:00:00+00', timestamptz '2025-12-31 21:00:00+00', null, {Admin}), ");
        sql.Append(CultureInfo.InvariantCulture, $"({DemoRequest}, {Demo}, 'pending', 'app', 'demo', 'Demo Contact', 'm900114@demo.invalid', timestamptz '2025-12-30 14:00:00+00', null, timestamptz '2025-12-31 14:00:00+00', null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({SharedRequest}, {DupNoUid}, 'pending', 'web', 'shared', 'Shared Contact', '{DupAddress}', timestamptz '2025-12-30 15:00:00+00', null, timestamptz '2025-12-31 15:00:00+00', null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({PairRequest}, {Pair}, 'pending', 'app', 'pair', 'Pair Contact', '{MembershipTestKit.EmailOf(Pair)}', timestamptz '2025-12-30 16:00:00+00', null, timestamptz '2025-12-31 16:00:00+00', null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({NoTokenRequest}, null, 'pending', 'web', 'no member', 'Nobody Contact', 'nobody@example.invalid', timestamptz '2025-12-30 17:00:00+00', null, timestamptz '2025-12-31 17:00:00+00', null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({GuestRequest}, 0, 'pending', 'web', 'guest', 'Guest Contact', '{GuestAddress}', timestamptz '2025-12-30 18:00:00+00', null, timestamptz '2025-12-31 18:00:00+00', null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({NoRowsRequest}, {NoRows}, 'pending', 'web', 'no rows', 'Rowless Contact', 'rowless@example.invalid', timestamptz '2025-12-30 19:00:00+00', null, timestamptz '2025-12-31 19:00:00+00', null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({CrowdedRequest}, {Crowded}, 'pending', 'web', 'crowded', 'Crowded Contact', 'crowd@example.invalid', timestamptz '2025-12-30 20:00:00+00', null, timestamptz '2025-12-31 20:00:00+00', null, null, null), ");
        sql.Append(CultureInfo.InvariantCulture, $"({FinishedRequest}, {Finished}, 'completed', 'app', 'done', 'Finished Contact', '{MembershipTestKit.EmailOf(Finished)}', timestamptz '2025-12-31 12:00:00+00', null, timestamptz '2025-12-31 13:00:00+00', timestamptz '2025-12-31 15:00:00+00', null, {Admin}); ");
    }

    // The rows a completion erases (the target's devices, calendar settings, feedback and queued messages) and a bystander's, which it must leave.
    private static void Erasable(StringBuilder sql)
    {
        const string stamp = "timestamptz '2025-12-15 09:00:00+00'";
        foreach (var device in new[] { "dev-900110-a", "dev-900110-b" })
        {
            sql.Append(CultureInfo.InvariantCulture, $"insert into notifications.user_devices (token, device_id, last_accessed_at, registered_at) values ({Target}, '{device}', {stamp}, {stamp}); ");
            sql.Append(CultureInfo.InvariantCulture, $"insert into platform.outbound_messages (channel, recipient, payload, dedupe_key, created_at) values ('push', '{device}', '[]', 'k-{device}', {stamp}); ");
        }

        sql.Append(CultureInfo.InvariantCulture, $"insert into notifications.user_devices (token, device_id, last_accessed_at, registered_at) values ({Plain}, 'dev-900102-a', {stamp}, {stamp}); ");
        sql.Append(CultureInfo.InvariantCulture, $"insert into platform.outbound_messages (channel, recipient, payload, dedupe_key, created_at) values ('push', 'dev-900102-a', '[]', 'k-dev-900102-a', {stamp}), ('whatsapp', '+15550900110', '[]', 'k-mobile-900110', {stamp}); ");
        sql.Append(CultureInfo.InvariantCulture, $"insert into platform.feedback (user_id, client_id, message, created_at) select id, 'c-' || token, {MembershipTestKit.Quote("feedback " + Odd)}, {stamp} from identity.users where token in ({Target}, {Plain}) order by id; ");
        sql.Append(CultureInfo.InvariantCulture, $"insert into notifications.member_event_settings (user_id, class_id, event_key, client_updated_at, server_updated_at, device_key) select id, 98400, 'event:1', {stamp}, {stamp}, 'aaaaaaaaaaaaaaaa' from identity.users where token in ({Target}, {Plain}); ");
    }
}
