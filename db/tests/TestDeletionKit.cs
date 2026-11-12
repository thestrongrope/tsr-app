using System.Net;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Identity.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// What the account-deletion tests share (lane "deletion", stack 4: tokens 924000 to 924999, request ids 9740000 and up). The API runs as the limited database role with the
/// Firebase boundary and, when a test needs it, the membership erasure port replaced by a fake. Members are <c>m&lt;token&gt;@example.invalid</c> (see MembershipTestKit).
/// </summary>
internal sealed class TestDeletionKit : IDisposable
{
    public const int Admin = 924001;
    public const int Plain = 924002;
    public const int Target = 924010;
    public const int Bystander = 924020;
    public const string TargetMobile = "+15550924010";
    public const string BystanderMobile = "+15550924020";
    public const string TargetDevice = "device-924010-a";
    public const string TargetDevice2 = "device-924010-b";
    public const string BystanderDevice = "device-924020-a";

    private static int nextRequestId = 9740000;

    private readonly MembershipTestKit kit;

    public TestDeletionKit(IFirebaseAccounts firebase, IMemberErasure? erasure = null) =>
        kit = new MembershipTestKit(services =>
        {
            services.AddSingleton<IFirebaseAccounts>(firebase);
            if (erasure is not null)
            {
                services.AddScoped(_ => erasure);
            }
        });

    public static Task ResetAsync() => TestDatabase.ExecuteAsync(
        """
        truncate identity.users, identity.account_deletion_requests, access.user_roles, membership.member_profiles,
          membership.class_registrations, membership.class_registrations_languages, membership.student_interests,
          membership.user_guardians, notifications.user_devices, notifications.member_event_settings, platform.feedback, platform.outbound_messages, platform.outbox restart identity cascade
        """);

    /// <summary>A request id never used before in this run: the completion rate limit is keyed on it and lives as long as the API does.</summary>
    public static int NewRequestId() => Interlocked.Increment(ref nextRequestId);

    public static async Task<int> AddAdminAsync(int token = Admin)
    {
        var id = await MembershipTestKit.AddMemberAsync(token);
        await TestDatabase.ExecuteAsync($"insert into access.user_roles (user_id, roleid) values ({id}, 1)");
        return id;
    }

    /// <summary>The member whose account is deleted: a profile full of personal data, devices, feedback, queued messages, class requests.</summary>
    public static async Task<int> AddFullMemberAsync(int token, string mobile, string[] devices, string? uid = null)
    {
        var id = await TestDatabase.ScalarAsync<int>(
            $"""
            insert into identity.users (token, email, firebase_uid, provider, createdon, lastlogin, lastloginip, lastdevice, device, platform, version)
            values ({token}, '{MembershipTestKit.EmailOf(token)}', {(uid is null ? "'uid-" + token + "'" : MembershipTestKit.Quote(uid))}, 'firebase', now(), now(), '203.0.113.7', 'UA', 'Pixel', 'Android', '1.0')
            returning id
            """,
            TestDatabase.OwnerConnection);
        await TestDatabase.ExecuteAsync(
            $"""
            insert into membership.member_profiles (user_id, name, first_name, last_name, picture, gender, age_range, mobile, country, state, city, zip, language, sendupdates, unsubscribe)
            values ({id}, 'Real Name {token}', 'Real', 'Name', 'https://img.invalid/{token}', '1', '30-39', '{mobile}', 'Country', 'State', 'City', '12345', 3, 'Y', 'N');
            insert into membership.class_registrations (token, for_classid, residence_location, work_location, preferred_location, birth_year, profession, islamic_study_years, interests,
              other_interests, education, field_of_study, field_of_study_other, professional_courses, professional_courses_other, occupation_type, field_of_work, years_experience, role_level,
              linkedin_url, status, status_reason)
            values ({token}, 98400, 'res', 'work', 'pref', 1990, 'prof', 4, 'teaching,research', 'other', 'edu', '["a"]', 'fos', '["b"]', 'pco', 'occ', 'fow', '5', 'role', 'https://linkedin.invalid/{token}', 'Accepted', 'reason text');
            insert into platform.feedback (user_id, client_id, message) values ({id}, 'c-{token}', 'feedback of {token}');
            insert into platform.outbound_messages (channel, recipient, payload, dedupe_key) values ('whatsapp', '{mobile}', '[]', 'k-{token}-m');
            """);
        foreach (var device in devices)
        {
            await TestDatabase.ExecuteAsync(
                $"""
                insert into notifications.user_devices (token, device_id) values ({token}, '{device}');
                insert into platform.outbound_messages (channel, recipient, payload, dedupe_key) values ('push', '{device}', '[]', 'k-{token}-{device}');
                """);
        }

        return id;
    }

    /// <summary>A request row with an explicit, fresh id.</summary>
    public static async Task<int> AddRequestAsync(int? token, string status = "pending", bool confirmed = true, string? contactEmail = "x@example.invalid", string? completedAt = null)
    {
        var id = NewRequestId();
        await TestDatabase.ExecuteAsync(
            $"""
            insert into identity.account_deletion_requests (id, token, status, source, contact_name, contact_email, reason, requested_at, confirmation_sent_at, completed_at)
            values ({id}, {(token is null ? "null" : $"{token}")}, '{status}', 'app', 'Contact', {MembershipTestKit.Quote(contactEmail)}, 'because', now() - interval '1 day',
                    {(confirmed ? "now() - interval '1 hour'" : "null")}, {completedAt ?? "null"})
            """);
        return id;
    }

    public Task<MembershipTestKit.Reply> AsAsync(int caller, HttpMethod method, string path, string? json = null) => kit.SendAsync(caller, method, path, json);

    public Task<MembershipTestKit.Reply> CompleteAsync(int caller, int requestId) => AsAsync(caller, HttpMethod.Post, $"/admin/deletion-requests/{requestId}/complete");

    public static Task<long> EventsAsync(string type) =>
        MembershipTestKit.CountAsync("platform.outbox", $"event_type = '{type}'");

    public static async Task<JsonNode> EventPayloadAsync(string type) =>
        JsonNode.Parse(await TestDatabase.ScalarAsync<string>($"select payload::text from platform.outbox where event_type = '{type}'", TestDatabase.OwnerConnection))!;

    /// <summary>Every row one member owns, as one JSON text: equal before and after means not one of them was touched.</summary>
    public static Task<string> SnapshotAsync(int token, int userId, params string[] recipients) =>
        TestDatabase.ScalarAsync<string>(
            $"""
            select json_build_object(
              'users', (select coalesce(json_agg(u order by id), '[]') from identity.users u where token = {token}),
              'profile', (select coalesce(json_agg(p order by user_id), '[]') from membership.member_profiles p where user_id = {userId}),
              'regs', (select coalesce(json_agg(r order by id), '[]') from membership.class_registrations r where token = {token}),
              'devices', (select coalesce(json_agg(d order by id), '[]') from notifications.user_devices d where token = {token}),
              'feedback', (select coalesce(json_agg(f order by id), '[]') from platform.feedback f where user_id = {userId}),
              'outbound', (select coalesce(json_agg(o order by id), '[]') from platform.outbound_messages o where recipient = any(array[{string.Join(",", recipients.Select(r => "'" + r + "'"))}]::text[]))
            )::text
            """,
            TestDatabase.OwnerConnection);

    /// <summary>Everything the database holds that a completion could change, for "nothing changed" checks.</summary>
    public static Task<string> WholeDatabaseAsync() =>
        TestDatabase.ScalarAsync<string>(
            """
            select json_build_object(
              'users', (select coalesce(json_agg(u order by id), '[]') from identity.users u),
              'requests', (select coalesce(json_agg(r order by id), '[]') from identity.account_deletion_requests r),
              'profiles', (select coalesce(json_agg(p order by user_id), '[]') from membership.member_profiles p),
              'regs', (select coalesce(json_agg(c order by id), '[]') from membership.class_registrations c),
              'devices', (select coalesce(json_agg(d order by id), '[]') from notifications.user_devices d),
              'feedback', (select coalesce(json_agg(f order by id), '[]') from platform.feedback f),
              'outbound', (select coalesce(json_agg(o order by id), '[]') from platform.outbound_messages o),
              'outbox', (select count(*) from platform.outbox)
            )::text
            """,
            TestDatabase.OwnerConnection);

    public void Dispose() => kit.Dispose();
}

/// <summary>The Firebase boundary as a recording fake: what it was asked to delete, an optional look at the database at that moment, and an optional failure.</summary>
internal sealed class FakeFirebase : IFirebaseAccounts
{
    public List<(string? Uid, string? Email)> Calls { get; } = [];

    public Func<Task>? Inside { get; set; }

    public string? FailWith { get; set; }

    public string? FailOnUid { get; set; }

    public Dictionary<string, string> UidByEmail { get; } = new(StringComparer.OrdinalIgnoreCase);

    public List<string> Lookups { get; } = [];

    public Task<string?> FindUidByEmailAsync(string email, CancellationToken ct)
    {
        Lookups.Add(email);
        return Task.FromResult(UidByEmail.GetValueOrDefault(email));
    }

    public async Task DeleteAsync(string? uid, string? email, CancellationToken ct)
    {
        Calls.Add((uid, email));
        if (Inside is not null)
        {
            await Inside();
        }

        if (FailWith is not null || (FailOnUid is not null && uid == FailOnUid))
        {
            throw new FirebaseAccountException(FailWith ?? "Firebase could not be reached (HttpRequestException).");
        }
    }
}

/// <summary>An erasure port that fails after the earlier steps of a completion ran in the transaction.</summary>
internal sealed class FailingErasure : IMemberErasure
{
    public Task EraseAsync(DbContext db, int token, CancellationToken ct) => throw new InvalidOperationException("injected failure");
}

internal static class ReplyAssert
{
    public static void Expect(MembershipTestKit.Reply reply, HttpStatusCode status, string? detail = null)
    {
        Assert.That(reply.Status, Is.EqualTo(status), reply.Body);
        if (detail is not null)
        {
            Assert.That(reply.Detail, Is.EqualTo(detail));
        }
    }
}
