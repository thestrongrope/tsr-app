using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using NUnit.Framework;
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
}
