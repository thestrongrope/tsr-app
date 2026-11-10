using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Membership.Api;

namespace Tsr.Db.Tests;

/// <summary>membership's public read interface (member names by user id) and the default of its classes port.</summary>
public sealed class MembershipInterfacesTests
{
    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public void StartApi() => factory = TestApi.Create();

    [OneTimeTearDown]
    public void StopApi() => factory.Dispose();

    [SetUp]
    public Task SeedAsync() => TestDatabase.ExecuteAsync(
        """
        truncate membership.member_profiles;
        insert into membership.member_profiles (user_id, name) values (1, 'Synthetic One'), (2, ''), (3, null), (5, 'Synthetic Five');
        """);

    [Test]
    public async Task Names_come_back_by_user_id_and_members_without_a_name_are_left_out()
    {
        var names = await WithScopeAsync(s => s.GetRequiredService<MemberNames>().ByUserIdsAsync([1, 2, 3, 4, 5], CancellationToken.None));

        Assert.That(names, Is.EqualTo(new Dictionary<int, string> { [1] = "Synthetic One", [5] = "Synthetic Five" }));
    }

    [Test]
    public async Task No_ids_gives_an_empty_result()
    {
        var names = await WithScopeAsync(s => s.GetRequiredService<MemberNames>().ByUserIdsAsync([], CancellationToken.None));

        Assert.That(names, Is.Empty);
    }

    [Test]
    public async Task A_batch_over_the_limit_throws_instead_of_truncating()
    {
        var ids = Enumerable.Range(1, MemberNames.MaxBatch + 1).ToList();

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() => WithScopeAsync(s => s.GetRequiredService<MemberNames>().ByUserIdsAsync(ids, CancellationToken.None)));
    }

    [Test]
    public async Task Until_classes_exists_nobody_is_enrolled()
    {
        var enrolled = await WithScopeAsync(s => s.GetRequiredService<IClassEnrolments>().IsEnrolledAsync(900001, CancellationToken.None));

        Assert.That(enrolled, Is.False);
    }

    private async Task<T> WithScopeAsync<T>(Func<IServiceProvider, Task<T>> action)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        return await action(scope.ServiceProvider);
    }
}
