using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using NUnit.Framework;
using Tsr.Classes.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api;
using Tsr.Notifications.Api;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// Issue 98: a published command runs on the caller's transaction. A caller still on Entity Framework hands its open transaction over through
/// <see cref="EfTransaction"/>; these cases pin what that bridge refuses and what a joined transaction does once its owner has finished.
/// </summary>
public sealed class PublishedCommandsTests
{
    private Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public async Task StartAsync()
    {
        await TestDatabase.ExecuteAsync(
            """
            create table if not exists public.scratch_98 (id int primary key, note text);
            grant select, insert, update, delete on public.scratch_98 to tsr_app;
            """);
        factory = TestApi.Create();
    }

    [OneTimeTearDown]
    public void Stop() => factory.Dispose();

    [SetUp]
    public Task ResetScratchAsync() => TestDatabase.ExecuteAsync("truncate public.scratch_98");

    private static Task<long> ScratchCountAsync() => TestDatabase.ScalarAsync<long>("select count(*) from public.scratch_98", TestDatabase.OwnerConnection);

    private static Task<int> InsertAsync(DbTx tx, int id) =>
        tx.ExecuteAsync($"insert into public.scratch_98 (id, note) values ({id}, {"stale"})", CancellationToken.None);

    // TC-CMD-R5-01
    [Test]
    public async Task The_bridge_refuses_a_context_with_no_transaction()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<PlatformContext>();

        Assert.That(context.Database.CurrentTransaction, Is.Null);
        Assert.Throws<InvalidOperationException>(() => EfTransaction.Join(context));
        Assert.That(await ScratchCountAsync(), Is.EqualTo(0));
    }

    // TC-CMD-R5-02: how the owner ends the transaction.
    public enum Ending
    {
        Commit,
        Rollback,
        Dispose,
    }

    private static async Task EndAsync(IDbContextTransaction transaction, Ending ending)
    {
        switch (ending)
        {
            case Ending.Commit:
                await transaction.CommitAsync();
                break;
            case Ending.Rollback:
                await transaction.RollbackAsync();
                break;
            default:
                await transaction.DisposeAsync();
                break;
        }
    }

    [Test]
    public async Task A_joined_DbTx_kept_after_its_owner_ends_writes_nothing([Values] Ending ending)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<PlatformContext>();
        var first = await context.Database.BeginTransactionAsync();
        var stale = EfTransaction.Join(context);
        await EndAsync(first, ending);

        await Assert.ThrowsAsync<InvalidOperationException>(() => InsertAsync(stale, 1), "no new transaction");
        Assert.That(await ScratchCountAsync(), Is.EqualTo(0));

        await using var second = await context.Database.BeginTransactionAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => InsertAsync(stale, 2), "after the same context began a new transaction");
        await second.CommitAsync();

        Assert.That(await ScratchCountAsync(), Is.EqualTo(0), "the new transaction holds no row from the stale DbTx");
    }

    // CMD-R9: the payload column is citext, so the text is stored exactly as given (a jsonb cast would reorder keys, add spaces and decode escapes).
    [Test]
    public async Task A_queued_payload_is_stored_byte_for_byte()
    {
        const string payload = "{\"zeta\":\"\\u00e9 \u00e9\",\"alpha\":[1,2],\"mid\":{\"b\":null,\"a\":\"x\"}}";
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<PlatformContext>();
        await using var transaction = await context.Database.BeginTransactionAsync();
        var tx = EfTransaction.Join(context);

        await PlatformCommands.QueueMessagesAsync(tx, "push", ["r98-bytes"], payload, "k98-bytes", null, CancellationToken.None);
        var stored = await tx.ListAsync($"select payload::text as p from platform.outbound_messages where recipient = 'r98-bytes'", r => r.Text("p"), CancellationToken.None);

        Assert.That(stored, Is.EqualTo(new[] { payload }));
        await transaction.RollbackAsync();
    }

    // CMD-R11: the bridge succeeds. The other tests here check refusals.
    [Test]
    public async Task A_write_through_the_bridge_lands_when_Entity_Framework_commits_and_is_gone_when_it_rolls_back()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<PlatformContext>();

        await using (var rolledBack = await context.Database.BeginTransactionAsync())
        {
            await InsertAsync(EfTransaction.Join(context), 1);
            await rolledBack.RollbackAsync();
        }

        Assert.That(await ScratchCountAsync(), Is.EqualTo(0), "after the rollback");

        await using (var committed = await context.Database.BeginTransactionAsync())
        {
            await InsertAsync(EfTransaction.Join(context), 2);
            Assert.That(await ScratchCountAsync(), Is.EqualTo(0), "not visible to others before the commit");
            await committed.CommitAsync();
        }

        Assert.That(await ScratchCountAsync(), Is.EqualTo(1), "after the commit");
    }

    [Test]
    public async Task A_joined_DbTx_made_after_an_Entity_Framework_savepoint_is_accepted_and_rolls_back_to_it()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<PlatformContext>();
        await using var transaction = await context.Database.BeginTransactionAsync();
        await InsertAsync(EfTransaction.Join(context), 1);

        await transaction.CreateSavepointAsync("sp98");
        var later = EfTransaction.Join(context);
        await InsertAsync(later, 2);
        Assert.That(
            await later.ScalarAsync<long>($"select count(*) from public.scratch_98", CancellationToken.None),
            Is.EqualTo(2),
            "the write after the savepoint was accepted");
        await transaction.RollbackToSavepointAsync("sp98");

        Assert.That(
            await EfTransaction.Join(context).ScalarAsync<long>($"select count(*) from public.scratch_98", CancellationToken.None),
            Is.EqualTo(1),
            "only the earlier write stays");
        await transaction.CommitAsync();
        Assert.That(await ScratchCountAsync(), Is.EqualTo(1));
    }

    // TC-CMD-R3-04: platform's in-transaction commands leave nothing behind when the caller rolls back.
    [Test]
    public async Task A_rollback_removes_the_writes_of_platforms_commands()
    {
        const int token = 984301;
        var userId = await TestDatabase.ScalarAsync<int>(
            $"insert into identity.users (token, email, firebase_uid) values ({token}, 'm{token}@example.invalid', 'uid-{token}') returning id",
            TestDatabase.OwnerConnection);
        await TestDatabase.ExecuteAsync(
            $"""
            insert into platform.feedback (user_id, client_id, message) values ({userId}, 'c-{token}', 'feedback of {token}');
            insert into platform.outbound_messages (channel, recipient, payload, dedupe_key) values ('push', 'r98-old', '[]', 'k98-old');
            """);
        try
        {
            await using var scope = factory.Services.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<PlatformContext>();
            await using (var transaction = await context.Database.BeginTransactionAsync())
            {
                var tx = EfTransaction.Join(context);
                var queued = await PlatformCommands.QueueMessagesAsync(tx, "push", ["r98-new"], """{"title":"t"}""", "k98-new", null, CancellationToken.None);
                await PlatformCommands.RedactRecipientsAsync(tx, ["r98-old"], CancellationToken.None);
                await PlatformCommands.EraseFeedbackAsync(tx, userId, CancellationToken.None);
                Assert.That(queued, Is.EqualTo(1));
                Assert.That(
                    await tx.ScalarAsync<long>($"select count(*) from platform.outbound_messages where dedupe_key = 'k98-old' and recipient = '[deleted]'", CancellationToken.None),
                    Is.EqualTo(1),
                    "the commands wrote inside the transaction");
                await transaction.RollbackAsync();
            }

            Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from platform.outbound_messages where recipient = 'r98-new'", TestDatabase.OwnerConnection), Is.Zero, "the queued row");
            Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from platform.outbound_messages where recipient = 'r98-old'", TestDatabase.OwnerConnection), Is.EqualTo(1), "the redaction");
            Assert.That(await TestDatabase.ScalarAsync<long>($"select count(*) from platform.feedback where user_id = {userId}", TestDatabase.OwnerConnection), Is.EqualTo(1), "the feedback deletion");
        }
        finally
        {
            await TestDatabase.ExecuteAsync($"delete from platform.outbound_messages where dedupe_key like 'k98-%'; delete from platform.feedback where user_id = {userId}; delete from identity.users where id = {userId}");
        }
    }

    // TC-CMD-R3-03: notifications' announce command leaves nothing behind when the caller rolls back.
    [Test]
    public async Task A_rollback_removes_the_notification_the_inbox_rows_and_the_queued_push_of_an_announcement()
    {
        const int token = 984302;
        await TestDatabase.ExecuteAsync(
            $"""
            insert into identity.users (token, email, firebase_uid) values ({token}, 'm{token}@example.invalid', 'uid-{token}');
            insert into notifications.user_devices (token, device_id) values ({token}, 'dev-98-3');
            """);
        try
        {
            await using var scope = factory.Services.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<NotificationsContext>();
            await using (var transaction = await context.Database.BeginTransactionAsync())
            {
                var tx = EfTransaction.Join(context);
                var announcement = new Announcement("R98 title", "R98 body", "/r98", "r98_type", "k98-announce", [token]);
                var result = await NotificationsCommands.AnnounceCountedAsync(tx, announcement, CancellationToken.None);
                Assert.That(result, Is.EqualTo(new AnnounceResult(1, 1)));
                Assert.That(
                    await tx.ScalarAsync<long>($"select count(*) from notifications.user_notifications where user_token = {token}", CancellationToken.None),
                    Is.EqualTo(1),
                    "the command wrote inside the transaction");
                await transaction.RollbackAsync();
            }

            Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from notifications.notifications where title = 'R98 title'", TestDatabase.OwnerConnection), Is.Zero, "the notification");
            Assert.That(await TestDatabase.ScalarAsync<long>($"select count(*) from notifications.user_notifications where user_token = {token}", TestDatabase.OwnerConnection), Is.Zero, "the inbox row");
            Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from platform.outbound_messages where dedupe_key like 'k98-announce:%'", TestDatabase.OwnerConnection), Is.Zero, "the queued push");
        }
        finally
        {
            await TestDatabase.ExecuteAsync(
                $"""
                delete from notifications.user_notifications where user_token = {token};
                delete from notifications.notifications where title = 'R98 title';
                delete from platform.outbound_messages where dedupe_key like 'k98-announce:%';
                delete from notifications.user_devices where token = {token};
                delete from identity.users where token = {token};
                """);
        }
    }

    // A synthetic member above every real token, so the token CreateMemberAsync allocates (the highest + 1) is 900000 or more.
    private const int Anchor = 984310;

    private static Task CreateAnchorAsync() =>
        TestDatabase.ExecuteAsync($"insert into identity.users (token, email, firebase_uid) values ({Anchor}, 'm{Anchor}@example.invalid', 'uid-{Anchor}')");

    private static Task DeleteMembersAsync() =>
        TestDatabase.ExecuteAsync(
            $"""
            delete from platform.outbox where event_type in ('identity.member_created', 'identity.member_email_changed') and (payload->>'token')::int >= {Anchor};
            delete from identity.users where token >= {Anchor};
            """);

    // TC-CMD-R3-01: identity's commands leave nothing behind when the caller rolls back.
    [Test]
    public async Task A_rollback_removes_the_member_the_new_email_and_both_events_of_identitys_commands()
    {
        await CreateAnchorAsync();
        try
        {
            await using var scope = factory.Services.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<ClassesContext>();
            int token;
            await using (var transaction = await context.Database.BeginTransactionAsync())
            {
                var tx = EfTransaction.Join(context);
                token = await IdentityCommands.CreateMemberAsync(tx, TimeProvider.System, CancellationToken.None);
                Assert.That(await IdentityCommands.ChangeEmailAsync(tx, token, $"new{token}@example.invalid", TimeProvider.System, CancellationToken.None), Is.True);
                Assert.That(
                    await tx.ScalarAsync<long>($"select count(*) from identity.users where email = {"new" + token + "@example.invalid"}", CancellationToken.None),
                    Is.EqualTo(1),
                    "the commands wrote inside the transaction");
                await transaction.RollbackAsync();
            }

            Assert.That(await TestDatabase.ScalarAsync<long>($"select count(*) from identity.users where token = {token}", TestDatabase.OwnerConnection), Is.Zero, "the user and its new email");
            Assert.That(
                await TestDatabase.ScalarAsync<long>(
                    $"select count(*) from platform.outbox where event_type in ('identity.member_created', 'identity.member_email_changed') and (payload->>'token')::int = {token}",
                    TestDatabase.OwnerConnection),
                Is.Zero,
                "both events");
        }
        finally
        {
            await DeleteMembersAsync();
        }
    }

    // CMD-R2 and R9: a commit keeps both events, and each stored payload is what the reflection serializer's bytes became in the jsonb column.
    [Test]
    public async Task A_commit_keeps_identitys_events_with_the_payload_the_old_code_stored()
    {
        await CreateAnchorAsync();
        try
        {
            await using var scope = factory.Services.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<ClassesContext>();
            int token;
            await using (var transaction = await context.Database.BeginTransactionAsync())
            {
                var tx = EfTransaction.Join(context);
                token = await IdentityCommands.CreateMemberAsync(tx, TimeProvider.System, CancellationToken.None);
                await IdentityCommands.ChangeEmailAsync(tx, token, $"new{token}@example.invalid", TimeProvider.System, CancellationToken.None);
                await transaction.CommitAsync();
            }

            // The old code wrote JsonSerializer.Serialize(new Record(token), new JsonSerializerOptions(JsonSerializerDefaults.Web)) through the same jsonb insert.
            var oldBytes = System.Text.Json.JsonSerializer.Serialize(new OldTokenPayload(token), OldOptions);
            var oldStored = await TestDatabase.ScalarAsync<string>($"select '{oldBytes}'::jsonb::text", TestDatabase.OwnerConnection);
            Assert.That(oldStored, Is.EqualTo($"{{\"token\": {token}}}"), "the old form, as jsonb stores it");
            foreach (var type in new[] { "identity.member_created", "identity.member_email_changed" })
            {
                Assert.That(
                    await TestDatabase.ScalarAsync<string>($"select payload::text from platform.outbox where event_type = '{type}' and (payload->>'token')::int = {token}", TestDatabase.OwnerConnection),
                    Is.EqualTo(oldStored),
                    type);
            }

            Assert.That(await TestDatabase.ScalarAsync<string>($"select email::text from identity.users where token = {token}", TestDatabase.OwnerConnection), Is.EqualTo($"new{token}@example.invalid"));
        }
        finally
        {
            await DeleteMembersAsync();
        }
    }

    private static readonly System.Text.Json.JsonSerializerOptions OldOptions = new(System.Text.Json.JsonSerializerDefaults.Web);

    private sealed record OldTokenPayload(int Token);

    private sealed record OldContactPayload(int Token, bool NameChanged);

    private static Task DeleteMembershipRowsAsync() =>
        TestDatabase.ExecuteAsync(
            $"""
            delete from platform.outbox where event_type in ('membership.member_created', 'membership.member_contact_changed') and (payload->>'token')::int >= {Anchor};
            delete from membership.class_registrations where token >= {Anchor};
            delete from membership.member_profiles where user_id in (select id from identity.users where token >= {Anchor});
            """);

    // TC-CMD-R3-02: membership's commands leave nothing behind when the caller rolls back.
    [Test]
    public async Task A_rollback_removes_the_profile_the_new_name_the_request_and_both_events_of_membership_commands()
    {
        await CreateAnchorAsync();
        try
        {
            await using var scope = factory.Services.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<ClassesContext>();
            int token;
            await using (var transaction = await context.Database.BeginTransactionAsync())
            {
                var tx = EfTransaction.Join(context);
                token = await IdentityCommands.CreateMemberAsync(tx, TimeProvider.System, CancellationToken.None);
                await MembershipCommands.CreateProfileAsync(tx, token, "R98 Member", "1", "0300", TimeProvider.System, CancellationToken.None);
                await MembershipCommands.ChangeContactAsync(tx, token, "R98 Renamed", "0311", TimeProvider.System, CancellationToken.None);
                await MembershipCommands.RecordAcceptedRegistrationAsync(tx, token, 98001, CancellationToken.None);
                Assert.That(
                    await tx.ScalarAsync<long>($"select count(*) from membership.member_profiles where name = 'R98 Renamed' and mobile = '0311'", CancellationToken.None),
                    Is.EqualTo(1),
                    "the commands wrote inside the transaction");
                await transaction.RollbackAsync();
            }

            Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from membership.member_profiles where name like 'R98 %'", TestDatabase.OwnerConnection), Is.Zero, "the profile and its new name");
            Assert.That(await TestDatabase.ScalarAsync<long>($"select count(*) from membership.class_registrations where token = {token}", TestDatabase.OwnerConnection), Is.Zero, "the request");
            Assert.That(
                await TestDatabase.ScalarAsync<long>(
                    $"select count(*) from platform.outbox where event_type in ('membership.member_created', 'membership.member_contact_changed') and (payload->>'token')::int = {token}",
                    TestDatabase.OwnerConnection),
                Is.Zero,
                "both events");
        }
        finally
        {
            await DeleteMembershipRowsAsync();
            await DeleteMembersAsync();
        }
    }

    // CMD-R2 and R9: a commit keeps the rows and the events, each stored payload is what the old code's bytes became in the jsonb column.
    [Test]
    public async Task A_commit_keeps_membership_rows_and_events_with_the_payload_the_old_code_stored()
    {
        await CreateAnchorAsync();
        try
        {
            await using var scope = factory.Services.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<ClassesContext>();
            int token;
            await using (var transaction = await context.Database.BeginTransactionAsync())
            {
                var tx = EfTransaction.Join(context);
                token = await IdentityCommands.CreateMemberAsync(tx, TimeProvider.System, CancellationToken.None);
                await MembershipCommands.CreateProfileAsync(tx, token, "R98 Member", "1", "0300", TimeProvider.System, CancellationToken.None);
                await MembershipCommands.ChangeContactAsync(tx, token, "R98 Renamed é", "0311", TimeProvider.System, CancellationToken.None);
                await MembershipCommands.ChangeContactAsync(tx, token, null, "0322", TimeProvider.System, CancellationToken.None);
                await MembershipCommands.RecordAcceptedRegistrationAsync(tx, token, 98001, CancellationToken.None);
                await MembershipCommands.RecordAcceptedRegistrationAsync(tx, token, 98002, CancellationToken.None);
                await transaction.CommitAsync();
            }

            var profile = await TestDatabase.RowAsync($"select name::text as name, mobile::text as mobile from membership.member_profiles where user_id in (select id from identity.users where token = {token})");
            Assert.That(profile, Is.EqualTo(new Dictionary<string, string?> { ["name"] = "R98 Renamed é", ["mobile"] = "0322" }), "a null name leaves the name, the mobile is overwritten");
            Assert.That(
                await TestDatabase.RowAsync($"select for_classid::text as c, status::text as s from membership.class_registrations where token = {token}"),
                Is.EqualTo(new Dictionary<string, string?> { ["c"] = "98001", ["s"] = "Accepted" }),
                "a member with a request is left alone");

            var created = await OldStoredAsync(new OldTokenPayload(token));
            var renamed = await OldStoredAsync(new OldContactPayload(token, true));
            var kept = await OldStoredAsync(new OldContactPayload(token, false));
            Assert.Multiple(async () =>
            {
                Assert.That(await EventPayloadAsync("membership.member_created", token, null), Is.EqualTo(created));
                Assert.That(await EventPayloadAsync("membership.member_contact_changed", token, true), Is.EqualTo(renamed));
                Assert.That(await EventPayloadAsync("membership.member_contact_changed", token, false), Is.EqualTo(kept));
            });
        }
        finally
        {
            await DeleteMembershipRowsAsync();
            await DeleteMembersAsync();
        }
    }

    private static async Task<string> OldStoredAsync<T>(T payload)
    {
        var oldBytes = System.Text.Json.JsonSerializer.Serialize(payload, OldOptions);
        return await TestDatabase.ScalarAsync<string>($"select '{oldBytes}'::jsonb::text", TestDatabase.OwnerConnection);
    }

    private static Task<string> EventPayloadAsync(string type, int token, bool? nameChanged)
    {
        var filter = nameChanged is null ? string.Empty : $" and payload->>'nameChanged' = '{(nameChanged.Value ? "true" : "false")}'";
        return TestDatabase.ScalarAsync<string>($"select payload::text from platform.outbox where event_type = '{type}' and (payload->>'token')::int = {token}{filter}", TestDatabase.OwnerConnection);
    }

    // TC-CMD-R5-03: a command on a committed owned transaction writes nothing.
    [Test]
    public async Task A_command_on_a_committed_transaction_writes_nothing()
    {
        const int token = 984320;
        var source = factory.Services.GetRequiredService<NpgsqlDataSource>();
        await using var tx = await source.BeginAsync(CancellationToken.None);
        await tx.CommitAsync(CancellationToken.None);

        await Assert.ThrowsAsync<InvalidOperationException>(() => MembershipCommands.RecordAcceptedRegistrationAsync(tx, token, 98001, CancellationToken.None));

        Assert.That(await TestDatabase.ScalarAsync<long>($"select count(*) from membership.class_registrations where token = {token}", TestDatabase.OwnerConnection), Is.Zero);
    }

    private sealed record FourDomainRows(long Users, long Profiles, long Requests, long Notifications, long Inbox, long Queued, long Events);

    // One command of each owning domain on the caller's transaction: identity (create), membership (profile, request), notifications (announce to a device), platform (a direct queue and the announce's own).
    private static async Task<int> RunFourDomainCommandsAsync(DbTx tx)
    {
        var token = await IdentityCommands.CreateMemberAsync(tx, TimeProvider.System, CancellationToken.None);
        await MembershipCommands.CreateProfileAsync(tx, token, "R98 Member", "1", "0300", TimeProvider.System, CancellationToken.None);
        await MembershipCommands.RecordAcceptedRegistrationAsync(tx, token, 98001, CancellationToken.None);
        await tx.ExecuteAsync($"insert into notifications.user_devices (token, device_id) values ({token}, {"dev-98-" + token})", CancellationToken.None);
        var announcement = new Announcement("R98 title", "R98 body", "/r98", "r98_type", "k98-four", [token]);
        Assert.That(await NotificationsCommands.AnnounceCountedAsync(tx, announcement, CancellationToken.None), Is.EqualTo(new AnnounceResult(1, 1)));
        Assert.That(await PlatformCommands.QueueMessagesAsync(tx, "push", ["r98-direct"], """{"title":"t"}""", "k98-direct", null, CancellationToken.None), Is.EqualTo(1));
        return token;
    }

    // Read on a fresh connection each time, so only committed rows count.
    private static async Task<FourDomainRows> FourDomainRowsAsync(int token) =>
        new(
            await TestDatabase.ScalarAsync<long>($"select count(*) from identity.users where token = {token}", TestDatabase.OwnerConnection),
            await TestDatabase.ScalarAsync<long>($"select count(*) from membership.member_profiles where name = 'R98 Member'", TestDatabase.OwnerConnection),
            await TestDatabase.ScalarAsync<long>($"select count(*) from membership.class_registrations where token = {token}", TestDatabase.OwnerConnection),
            await TestDatabase.ScalarAsync<long>("select count(*) from notifications.notifications where title = 'R98 title'", TestDatabase.OwnerConnection),
            await TestDatabase.ScalarAsync<long>($"select count(*) from notifications.user_notifications where user_token = {token}", TestDatabase.OwnerConnection),
            await TestDatabase.ScalarAsync<long>("select count(*) from platform.outbound_messages where dedupe_key like 'k98-%'", TestDatabase.OwnerConnection),
            await TestDatabase.ScalarAsync<long>(
                $"select count(*) from platform.outbox where event_type in ('identity.member_created', 'membership.member_created') and (payload->>'token')::int = {token}",
                TestDatabase.OwnerConnection));

    private static Task DeleteFourDomainRowsAsync() =>
        TestDatabase.ExecuteAsync(
            $"""
            delete from notifications.user_notifications where user_token >= {Anchor};
            delete from notifications.notifications where title = 'R98 title';
            delete from notifications.user_devices where token >= {Anchor};
            delete from platform.outbound_messages where dedupe_key like 'k98-%';
            """);

    // TC-CMD-R1-01: the converted-caller path. The caller holds its own DbTx and has no Entity Framework at all.
    [Test]
    public async Task An_owned_DbTx_commits_commands_of_four_domains_together()
    {
        await CreateAnchorAsync();
        try
        {
            var source = factory.Services.GetRequiredService<NpgsqlDataSource>();
            int token;
            await using (var tx = await source.BeginAsync(CancellationToken.None))
            {
                token = await RunFourDomainCommandsAsync(tx);
                Assert.That(await FourDomainRowsAsync(token), Is.EqualTo(new FourDomainRows(0, 0, 0, 0, 0, 0, 0)), "nothing is visible to others before the commit");
                await tx.CommitAsync(CancellationToken.None);
            }

            Assert.That(await FourDomainRowsAsync(token), Is.EqualTo(new FourDomainRows(1, 1, 1, 1, 1, 2, 2)));
        }
        finally
        {
            await DeleteFourDomainRowsAsync();
            await DeleteMembershipRowsAsync();
            await DeleteMembersAsync();
        }
    }

    // TC-CMD-R3-05: the same commands, the owned transaction disposed with no commit.
    [Test]
    public async Task An_owned_DbTx_disposed_without_a_commit_keeps_none_of_the_four_domains_writes()
    {
        await CreateAnchorAsync();
        try
        {
            var source = factory.Services.GetRequiredService<NpgsqlDataSource>();
            int token;
            await using (var tx = await source.BeginAsync(CancellationToken.None))
            {
                token = await RunFourDomainCommandsAsync(tx);
                Assert.That(
                    await tx.ScalarAsync<long>($"select count(*) from platform.outbox where (payload->>'token')::int = {token}", CancellationToken.None),
                    Is.EqualTo(2),
                    "the commands wrote inside the transaction");
            }

            Assert.That(await FourDomainRowsAsync(token), Is.EqualTo(new FourDomainRows(0, 0, 0, 0, 0, 0, 0)));
        }
        finally
        {
            await DeleteFourDomainRowsAsync();
            await DeleteMembershipRowsAsync();
            await DeleteMembersAsync();
        }
    }

    private static readonly string SlowTriggerSql =
        $"""
        create or replace function public.slow_users_98() returns trigger language plpgsql as $$ begin perform pg_sleep(2); return new; end $$;
        create trigger slow_users_98 before insert on identity.users for each row when (new.token > {Anchor}) execute function public.slow_users_98();
        """;

    private static async Task CleanUpCancelledAsync()
    {
        await TestDatabase.ExecuteAsync("drop trigger if exists slow_users_98 on identity.users; drop function if exists public.slow_users_98()");
        await TestDatabase.ExecuteAsync("delete from platform.outbound_messages where dedupe_key like 'k98-%'");
        await DeleteMembersAsync();
    }

    // Starts the command, waits until the database is inside the held insert (the trigger's pg_sleep), and only then cancels.
    // So the cancel always lands in a running statement, whatever the speed of the machine. Returns what the caller sees.
    private static async Task<Exception> CancelWhileTheInsertRunsAsync(Func<CancellationToken, Task> command)
    {
        using var cancelling = new CancellationTokenSource();
        var running = command(cancelling.Token);
        var deadline = DateTime.UtcNow.AddSeconds(10);
        while (!running.IsCompleted)
        {
            var sleeping = await TestDatabase.ScalarAsync<long>(
                "select count(*) from pg_stat_activity where wait_event = 'PgSleep' and query like 'insert into identity.users%'",
                TestDatabase.OwnerConnection);
            if (sleeping > 0)
            {
                break;
            }

            Assert.That(DateTime.UtcNow, Is.LessThan(deadline), "the held insert never started");
            await Task.Delay(20);
        }

        Assert.That(running.IsCompleted, Is.False, "the command finished before the cancel, so nothing was held");
        cancelling.Cancel();
        return await Assert.CatchAsync(() => running.WaitAsync(TimeSpan.FromSeconds(10)));
    }

    // A cancelled RUNNING statement: Npgsql throws OperationCanceledException whose inner exception is the database's own 57014 (query cancelled).
    private static void AssertCancelledInsideTheStatement(Exception thrown)
    {
        Assert.That(thrown, Is.InstanceOf<OperationCanceledException>());
        Assert.That(thrown.InnerException, Is.InstanceOf<PostgresException>(), "the database's own cancellation, not a token seen before the statement");
        Assert.That(((PostgresException)thrown.InnerException!).SqlState, Is.EqualTo(PostgresErrorCodes.QueryCanceled));
    }

    private static async Task AssertNoWritesOfTheCancelledCommandAsync()
    {
        Assert.That(await TestDatabase.ScalarAsync<long>("select count(*) from platform.outbound_messages where dedupe_key like 'k98-cancel:%'", TestDatabase.OwnerConnection), Is.Zero, "the write before the cancelled command");
        Assert.That(await TestDatabase.ScalarAsync<long>($"select count(*) from identity.users where token > {Anchor}", TestDatabase.OwnerConnection), Is.Zero, "the user");
        Assert.That(
            await TestDatabase.ScalarAsync<long>("select count(*) from platform.outbox where event_type = 'identity.member_created' and (payload->>'token')::int > " + Anchor, TestDatabase.OwnerConnection),
            Is.Zero,
            "the event");
    }

    // TC-CMD-R6-01 on an owned DbTx: the cancel is sent once the database is inside CreateMemberAsync's insert, held 2 s by a trigger.
    // The command has four statements (lock, read, insert, event); the cancel lands in the third.
    [Test]
    public async Task A_cancelled_command_keeps_none_of_its_writes()
    {
        await CreateAnchorAsync();
        await TestDatabase.ExecuteAsync(SlowTriggerSql);
        try
        {
            var source = factory.Services.GetRequiredService<NpgsqlDataSource>();
            var tx = await source.BeginAsync(CancellationToken.None);
            try
            {
                await PlatformCommands.QueueMessagesAsync(tx, "push", ["r98-cancel"], """{"title":"t"}""", "k98-cancel", null, CancellationToken.None);

                var thrown = await CancelWhileTheInsertRunsAsync(ct => IdentityCommands.CreateMemberAsync(tx, TimeProvider.System, ct));

                AssertCancelledInsideTheStatement(thrown);
            }
            finally
            {
                await tx.DisposeAsync().AsTask().WaitAsync(TimeSpan.FromSeconds(10));
            }

            await AssertNoWritesOfTheCancelledCommandAsync();
            await using var after = await source.BeginAsync(CancellationToken.None);
            Assert.That(await after.ScalarAsync<int>($"select 1", CancellationToken.None), Is.EqualTo(1), "the pool serves a new transaction");
        }
        finally
        {
            await CleanUpCancelledAsync();
        }
    }

    // TC-CMD-R6-01 on the bridge path every production caller uses: the command joins the context's transaction, the cancel lands inside it,
    // the caller rolls back its Entity Framework transaction, and the context can begin another. The plan names CreateMemberAsync (four
    // statements, the third held by the trigger), the same command as the test above.
    [Test]
    public async Task A_cancelled_command_on_a_joined_Entity_Framework_transaction_keeps_none_of_its_writes_after_the_caller_rolls_back()
    {
        await CreateAnchorAsync();
        await TestDatabase.ExecuteAsync(SlowTriggerSql);
        try
        {
            await using var scope = factory.Services.CreateAsyncScope();
            var context = scope.ServiceProvider.GetRequiredService<ClassesContext>();
            await using (var transaction = await context.Database.BeginTransactionAsync())
            {
                var tx = EfTransaction.Join(context);
                await PlatformCommands.QueueMessagesAsync(tx, "push", ["r98-cancel"], """{"title":"t"}""", "k98-cancel", null, CancellationToken.None);

                var thrown = await CancelWhileTheInsertRunsAsync(ct => IdentityCommands.CreateMemberAsync(tx, TimeProvider.System, ct));

                AssertCancelledInsideTheStatement(thrown);
                await transaction.RollbackAsync().WaitAsync(TimeSpan.FromSeconds(10));
            }

            await AssertNoWritesOfTheCancelledCommandAsync();
            await using var next = await context.Database.BeginTransactionAsync();
            Assert.That(
                await EfTransaction.Join(context).ScalarAsync<int>($"select 1", CancellationToken.None),
                Is.EqualTo(1),
                "the context begins a new transaction and runs a statement on it");
            await next.RollbackAsync();
        }
        finally
        {
            await CleanUpCancelledAsync();
        }
    }
}
