using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// Sign-in hands the token's name and picture to membership in the same request, as PHP's getOrCreateFromFirebase writes them
/// into <c>users</c>: a new member gets both (absent ones as empty text); a verified email that claims an existing member
/// overwrites only what the token carries; a lookup route (no create) writes nothing. Through the API, as the limited role.
/// </summary>
public sealed class ProfileSinkTests
{
    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public void StartApi() => factory = TestApi.Create();

    [OneTimeTearDown]
    public void StopApi() => factory.Dispose();

    [SetUp]
    public Task CleanAsync() => TestDatabase.ExecuteAsync(
        "truncate identity.users, identity.account_deletion_requests, membership.member_profiles restart identity cascade");

    [Test]
    public async Task A_new_member_gets_the_tokens_name_and_picture_in_their_profile()
    {
        var status = await LinkAsync("uid-new", "new@example.invalid", name: "Synthetic Person", picture: "https://example.invalid/p.png");

        Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
        var row = await ProfileOfAsync("new@example.invalid");
        Assert.That(row["name"], Is.EqualTo("Synthetic Person"));
        Assert.That(row["picture"], Is.EqualTo("https://example.invalid/p.png"));
    }

    [Test]
    public async Task A_new_member_whose_token_has_no_name_gets_empty_text_as_in_PHP()
    {
        await LinkAsync("uid-new", "new@example.invalid");

        var row = await ProfileOfAsync("new@example.invalid");
        Assert.That(row["name"], Is.EqualTo(string.Empty));
        Assert.That(row["picture"], Is.EqualTo(string.Empty));
    }

    [Test]
    public async Task A_verified_email_claiming_a_member_overwrites_only_what_the_token_carries()
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email) values (900001, 'old@example.invalid')");
        await TestDatabase.ExecuteAsync(
            "insert into membership.member_profiles (user_id, name, picture, mobile, city) "
            + "select id, 'Old Name', 'https://example.invalid/old.png', '+911234567890', 'Pune' from identity.users where token = 900001");

        await LinkAsync("uid-claim", "old@example.invalid", name: "New Name");

        var row = await ProfileOfAsync("old@example.invalid");
        Assert.That(row["name"], Is.EqualTo("New Name"));
        Assert.That(row["picture"], Is.EqualTo("https://example.invalid/old.png"));
        Assert.That(row["mobile"], Is.EqualTo("+911234567890"));
        Assert.That(row["city"], Is.EqualTo("Pune"));
    }

    [Test]
    public async Task A_claim_by_a_member_with_no_profile_row_creates_one_from_the_token()
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email) values (900001, 'old@example.invalid')");

        await LinkAsync("uid-claim", "old@example.invalid", name: "New Name", picture: "https://example.invalid/n.png");

        var row = await ProfileOfAsync("old@example.invalid");
        Assert.That(row["name"], Is.EqualTo("New Name"));
        Assert.That(row["picture"], Is.EqualTo("https://example.invalid/n.png"));
    }

    [Test]
    public async Task A_claim_whose_token_carries_neither_writes_no_profile_row()
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email) values (900001, 'old@example.invalid')");

        await LinkAsync("uid-claim", "old@example.invalid");

        Assert.That(await CountProfilesAsync(), Is.EqualTo(0));
    }

    [Test]
    public async Task A_sign_in_that_finds_the_member_by_uid_writes_nothing()
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email, firebase_uid) values (900001, 'old@example.invalid', 'uid-1')");

        await LinkAsync("uid-1", "old@example.invalid", name: "Ignored");

        Assert.That(await CountProfilesAsync(), Is.EqualTo(0));
    }

    [Test]
    public async Task A_lookup_route_never_writes_the_name()
    {
        await TestDatabase.ExecuteAsync("insert into identity.users (token, email) values (900001, 'old@example.invalid')");
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Post, "/feedback") { Content = new StringContent("""{"clientId":"c-1","text":"salaam"}""", System.Text.Encoding.UTF8, "application/json") };
        foreach (var (key, value) in TestApi.SignedInAs("uid-claim", "old@example.invalid"))
        {
            request.Headers.Add(key, value);
        }

        request.Headers.Add(TestApi.Name, "Ignored");
        using var response = await client.SendAsync(request);

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.Created));
        Assert.That(await CountProfilesAsync(), Is.EqualTo(0));
    }

    [Test]
    public async Task A_name_or_picture_longer_than_its_column_is_cut_to_fit_rather_than_failing_the_sign_in()
    {
        var status = await LinkAsync("uid-new", "new@example.invalid", name: new string('n', 250), picture: "https://example.invalid/" + new string('p', 2100));

        Assert.That(status, Is.EqualTo(HttpStatusCode.OK));
        var row = await ProfileOfAsync("new@example.invalid");
        Assert.That(row["name"], Has.Length.EqualTo(200));
        Assert.That(row["picture"], Has.Length.EqualTo(2000));
    }

    private async Task<HttpStatusCode> LinkAsync(string uid, string email, string? name = null, string? picture = null)
    {
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Post, "/auth/link") { Content = new ByteArrayContent([]) };
        foreach (var (key, value) in TestApi.SignedInAs(uid, email))
        {
            request.Headers.Add(key, value);
        }

        if (name is not null)
        {
            request.Headers.Add(TestApi.Name, name);
        }

        if (picture is not null)
        {
            request.Headers.Add(TestApi.Picture, picture);
        }

        using var response = await client.SendAsync(request);
        return response.StatusCode;
    }

    private static async Task<Dictionary<string, string?>> ProfileOfAsync(string email) =>
        await TestDatabase.RowAsync(
            "select p.* from membership.member_profiles p join identity.users u on u.id = p.user_id where u.email = '" + email + "'")
        ?? throw new AssertionException("No profile for " + email);

    private static Task<long> CountProfilesAsync() =>
        TestDatabase.ScalarAsync<long>("select count(*) from membership.member_profiles", TestDatabase.OwnerConnection);
}
