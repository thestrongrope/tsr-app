using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Identity.Api;

namespace Tsr.Db.Tests;

/// <summary>identity's public read interface: every user of a token (a token is not unique), and a bounded batch by id.</summary>
public sealed class UserDirectoryTests
{
    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public void StartApi() => factory = TestApi.Create();

    [OneTimeTearDown]
    public void StopApi() => factory.Dispose();

    [SetUp]
    public Task SeedAsync() => TestDatabase.ExecuteAsync(
        """
        truncate identity.users, identity.account_deletion_requests restart identity cascade;
        insert into identity.users (token, email) values
          (900207, 'shared.one@example.invalid'), (900207, 'shared.two@example.invalid'),
          (900001, 'member.gents@example.invalid'), (0, 'guest@example.invalid');
        """);

    [Test]
    public async Task A_shared_token_returns_every_user_oldest_first()
    {
        var users = await WithDirectoryAsync(d => d.ByTokenAsync(900207, CancellationToken.None));

        Assert.That(users.Select(u => u.Email), Is.EqualTo(["shared.one@example.invalid", "shared.two@example.invalid"]));
        Assert.That(users.Select(u => u.Token), Is.All.EqualTo(900207));
        Assert.That(users[0].Id, Is.LessThan(users[1].Id));
    }

    [Test]
    public async Task An_unknown_token_returns_nothing()
    {
        Assert.That(await WithDirectoryAsync(d => d.ByTokenAsync(123456, CancellationToken.None)), Is.Empty);
    }

    [Test]
    public async Task Users_are_found_by_id_and_a_missing_id_is_left_out()
    {
        var all = await WithDirectoryAsync(d => d.ByTokenAsync(900001, CancellationToken.None));
        var id = all.Single().Id;

        var users = await WithDirectoryAsync(d => d.ByIdsAsync([id, 999999], CancellationToken.None));

        Assert.That(users, Is.EqualTo([new UserRef(id, 900001, "member.gents@example.invalid")]));
    }

    [Test]
    public async Task No_ids_returns_nothing_without_asking_the_database()
    {
        Assert.That(await WithDirectoryAsync(d => d.ByIdsAsync([], CancellationToken.None)), Is.Empty);
    }

    [Test]
    public async Task A_batch_over_the_limit_throws_instead_of_truncating()
    {
        var ids = Enumerable.Range(1, UserDirectory.MaxBatch + 1).ToList();

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() => WithDirectoryAsync(d => d.ByIdsAsync(ids, CancellationToken.None)));
    }

    [Test]
    public async Task Token_zero_returns_at_most_the_match_limit()
    {
        await TestDatabase.ExecuteAsync(
            "insert into identity.users (token, email) select 0, 'guest' || g || '@example.invalid' from generate_series(1, " + (UserDirectory.MaxMatches + 10) + ") g");

        var users = await WithDirectoryAsync(d => d.ByTokenAsync(0, CancellationToken.None));

        Assert.That(users, Has.Count.EqualTo(UserDirectory.MaxMatches));
    }

    [Test]
    public async Task Several_tokens_return_every_holder_in_id_order_and_an_unknown_token_adds_nothing()
    {
        var users = await WithDirectoryAsync(d => d.ByTokensAsync([900207, 900001, 123456], CancellationToken.None));

        Assert.That(
            users.Select(u => u.Email),
            Is.EqualTo(["shared.one@example.invalid", "shared.two@example.invalid", "member.gents@example.invalid"]));
    }

    [Test]
    public async Task No_tokens_return_nothing()
    {
        Assert.That(await WithDirectoryAsync(d => d.ByTokensAsync([], CancellationToken.None)), Is.Empty);
    }

    [Test]
    public async Task A_token_batch_over_the_limit_throws_instead_of_truncating()
    {
        var tokens = Enumerable.Range(1, UserDirectory.MaxBatch + 1).ToList();

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() => WithDirectoryAsync(d => d.ByTokensAsync(tokens, CancellationToken.None)));
    }

    private async Task<T> WithDirectoryAsync<T>(Func<UserDirectory, Task<T>> action)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        return await action(scope.ServiceProvider.GetRequiredService<UserDirectory>());
    }
}
