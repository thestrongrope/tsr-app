using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using NUnit.Framework;
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
                    await tx.ScalarAsync<long>($"select count(*) from platform.outbound_messages where recipient = '[deleted]'", CancellationToken.None),
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
}
