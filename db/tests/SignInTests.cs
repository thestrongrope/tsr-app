using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// Sign-in against a real database, through the API as the limited role (the Firebase check is stubbed, see
/// TestApi). Every refusal is the status and body PHP's api_authenticate() gives (phase-2-identity-recon.md, section 3).
/// </summary>
public sealed class SignInTests
{
    private const string Member = "member@example.invalid";
    private const string FeedbackBody = """{"clientId":"c-1","text":"salaam"}""";

    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public void StartApi() => factory = TestApi.Create();

    [OneTimeTearDown]
    public void StopApi() => factory.Dispose();

    [SetUp]
    public Task CleanAsync() => TestDatabase.ExecuteAsync(
        "truncate identity.users, identity.account_deletion_requests restart identity cascade");

    [Test]
    public async Task No_credentials_is_401_not_authenticated()
    {
        var reply = await PostFeedbackAsync([new(TestApi.Outcome, "missing")]);

        AssertDetail(reply, HttpStatusCode.Unauthorized, "Not authenticated");
    }

    [Test]
    public async Task An_invalid_token_is_401_invalid_auth_token()
    {
        var reply = await PostFeedbackAsync([new(TestApi.Outcome, "invalid")]);

        AssertDetail(reply, HttpStatusCode.Unauthorized, "Invalid auth token");
    }

    [Test]
    public async Task A_token_without_an_email_is_401_email_not_present()
    {
        var reply = await PostFeedbackAsync([new(TestApi.Outcome, "noemail")]);

        AssertDetail(reply, HttpStatusCode.Unauthorized, "Email not present in token");
    }

    [Test]
    public async Task A_lookup_route_with_no_row_is_404_and_creates_nothing()
    {
        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-new", "new@example.invalid"));

        AssertDetail(reply, HttpStatusCode.NotFound, "User not found");
        Assert.That(await CountUsersAsync(), Is.EqualTo(0));
    }

    [Test]
    public async Task A_lookup_route_with_an_unverified_email_match_is_404_and_stamps_no_uid()
    {
        await InsertUserAsync(900001, Member);

        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-x", Member, verified: false));

        AssertDetail(reply, HttpStatusCode.NotFound, "User not found");
        Assert.That((await UserAsync(900001))["firebase_uid"], Is.Null);
    }

    [Test]
    public async Task A_create_route_with_an_unverified_email_match_is_404_and_creates_nothing()
    {
        await InsertUserAsync(900001, Member);

        var reply = await LinkAsync(TestApi.SignedInAs("uid-x", Member, verified: false));

        AssertDetail(reply, HttpStatusCode.NotFound, "User not found");
        Assert.That(await CountUsersAsync(), Is.EqualTo(1));
    }

    [Test]
    public async Task A_guest_row_is_403_registration_incomplete_on_both_route_kinds()
    {
        await InsertUserAsync(0, "guest@example.invalid", "uid-guest");
        var headers = TestApi.SignedInAs("uid-guest", "guest@example.invalid");

        AssertDetail(await PostFeedbackAsync(headers), HttpStatusCode.Forbidden, "Registration incomplete");
        AssertDetail(await LinkAsync(headers), HttpStatusCode.Forbidden, "Registration incomplete");
    }

    [Test]
    public async Task A_pending_deletion_is_403_with_its_status_on_a_route_off_the_allow_list()
    {
        await InsertUserAsync(900001, Member, "uid-1");
        await InsertDeletionAsync(900001, "pending");

        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-1", Member));

        AssertDetail(reply, HttpStatusCode.Forbidden, "Account deletion pending");
        Assert.That(reply.Body.GetProperty("deletion_status").GetString(), Is.EqualTo("pending"));
    }

    [Test]
    public async Task Awaiting_prize_delivery_is_a_live_deletion_too()
    {
        await InsertUserAsync(900001, Member, "uid-1");
        await InsertDeletionAsync(900001, "awaiting_prize_delivery");

        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-1", Member));

        Assert.That(reply.Body.GetProperty("deletion_status").GetString(), Is.EqualTo("awaiting_prize_delivery"));
    }

    [Test]
    public async Task A_cancelled_deletion_blocks_nothing()
    {
        await InsertUserAsync(900001, Member, "uid-1");
        await InsertDeletionAsync(900001, "cancelled");

        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-1", Member));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created));
    }

    [Test]
    public async Task A_pending_deletion_still_reaches_the_allow_listed_link_route()
    {
        await InsertUserAsync(900001, Member, "uid-1");
        await InsertDeletionAsync(900001, "pending");

        var reply = await LinkAsync(TestApi.SignedInAs("uid-1", Member));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
    }

    [Test]
    public async Task A_pending_deletion_is_refused_before_the_sign_in_is_recorded()
    {
        await InsertUserAsync(900001, Member, "uid-1");
        await InsertDeletionAsync(900001, "pending");

        await PostFeedbackAsync(TestApi.SignedInAs("uid-1", Member));

        Assert.That((await UserAsync(900001))["lastlogin"], Is.Null);
    }

    [Test]
    public async Task A_completed_deletion_within_two_hours_refuses_a_create_route_for_that_email_in_any_case()
    {
        await InsertCompletedDeletionAsync("Gone@Example.Invalid", "now() - interval '2 hours' + interval '1 minute'");

        var reply = await LinkAsync(TestApi.SignedInAs("uid-new", "gone@example.invalid"));

        AssertDetail(
            reply,
            HttpStatusCode.Forbidden,
            "This account has been deleted. Please sign out and sign in again to start afresh.");
        Assert.That(reply.Body.GetProperty("deletion_status").GetString(), Is.EqualTo("completed"));
        Assert.That(await CountUsersAsync(), Is.EqualTo(0));
    }

    [Test]
    public async Task A_completed_deletion_older_than_two_hours_lets_the_person_start_afresh()
    {
        await InsertCompletedDeletionAsync("gone@example.invalid", "now() - interval '2 hours' - interval '1 minute'");

        var reply = await LinkAsync(TestApi.SignedInAs("uid-new", "gone@example.invalid"));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
    }

    [Test]
    public async Task A_completed_deletion_does_not_change_a_lookup_route()
    {
        await InsertCompletedDeletionAsync("gone@example.invalid", "now()");

        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-new", "gone@example.invalid"));

        AssertDetail(reply, HttpStatusCode.NotFound, "User not found");
    }

    [Test]
    public async Task A_member_is_found_by_firebase_uid_even_when_the_email_differs()
    {
        await InsertUserAsync(900001, Member, "uid-1");

        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-1", "changed@example.invalid"));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created));
    }

    [Test]
    public async Task A_verified_email_claims_a_row_with_no_uid_and_the_uid_is_stamped_on_a_lookup_route()
    {
        await InsertUserAsync(900001, Member);

        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-1", Member));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created));
        Assert.That((await UserAsync(900001))["firebase_uid"], Is.EqualTo("uid-1"));
    }

    [Test]
    public async Task The_email_match_ignores_case()
    {
        await InsertUserAsync(900001, "Member@Example.Invalid");

        var reply = await PostFeedbackAsync(TestApi.SignedInAs("uid-1", "member@example.invalid"));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.Created));
    }

    [Test]
    public async Task A_lookup_route_leaves_another_uid_in_place_but_a_create_route_overwrites_it()
    {
        await InsertUserAsync(900001, Member, "uid-old");

        await PostFeedbackAsync(TestApi.SignedInAs("uid-new", Member));
        Assert.That((await UserAsync(900001))["firebase_uid"], Is.EqualTo("uid-old"));

        await LinkAsync(TestApi.SignedInAs("uid-new", Member));
        Assert.That((await UserAsync(900001))["firebase_uid"], Is.EqualTo("uid-new"));
    }

    [Test]
    public async Task The_first_sign_in_creates_a_member_with_the_next_token_and_a_second_finds_it()
    {
        await InsertUserAsync(900005, "other@example.invalid", "uid-other");
        var headers = TestApi.SignedInAs("uid-new", "new@example.invalid");

        var first = await LinkAsync(headers);
        var second = await LinkAsync(headers);

        Assert.That(first.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(first.Body.GetProperty("me").GetProperty("token").GetInt32(), Is.EqualTo(900006));
        Assert.That(second.Body.GetProperty("me").GetProperty("token").GetInt32(), Is.EqualTo(900006));
        var row = await UserAsync(900006);
        Assert.That(row["email"], Is.EqualTo("new@example.invalid"));
        Assert.That(row["provider"], Is.EqualTo("firebase"));
        Assert.That(row["firebase_uid"], Is.EqualTo("uid-new"));
        Assert.That(row["createdon"], Is.Not.Null);
        Assert.That(await CountUsersAsync(), Is.EqualTo(2));
    }

    [Test]
    public async Task The_first_member_ever_gets_token_1001()
    {
        var reply = await LinkAsync(TestApi.SignedInAs("uid-new", "new@example.invalid"));

        Assert.That(reply.Body.GetProperty("me").GetProperty("token").GetInt32(), Is.EqualTo(1001));
    }

    [Test]
    public async Task The_link_reply_carries_the_identity_fields()
    {
        await InsertUserAsync(900001, Member, "uid-1");

        var reply = await LinkAsync(TestApi.SignedInAs("uid-1", Member));

        var me = reply.Body.GetProperty("me");
        Assert.That(me.GetProperty("id").GetInt32(), Is.GreaterThan(0));
        Assert.That(me.GetProperty("token").GetInt32(), Is.EqualTo(900001));
        Assert.That(me.GetProperty("email").GetString(), Is.EqualTo(Member));
    }

    [Test]
    public async Task Every_request_records_the_sign_in_as_the_limited_role()
    {
        await InsertUserAsync(900001, Member, "uid-1");
        var headers = TestApi.SignedInAs("uid-1", Member).Concat(
        [
            new("X-Forwarded-For", "203.0.113.9"),
            new("User-Agent", "TsrTest/1.0"),
            new("X-Device-Info", "Pixel"),
            new("X-Platform-Info", "Android 15"),
            new("X-App-Version", "1.0.2+10"),
        ]);

        await PostFeedbackAsync(headers);

        var row = await UserAsync(900001);
        Assert.That(row["lastlogin"], Is.Not.Null);
        Assert.That(row["lastloginip"], Is.EqualTo("203.0.113.9"));
        Assert.That(row["lastdevice"], Is.EqualTo("TsrTest/1.0"));
        Assert.That(row["device"], Is.EqualTo("Pixel"));
        Assert.That(row["platform"], Is.EqualTo("Android 15"));
        Assert.That(row["version"], Is.EqualTo("1.0.2+10"));
    }

    [Test]
    public async Task A_header_the_client_did_not_send_keeps_the_stored_value()
    {
        await TestDatabase.ExecuteAsync(
            "insert into identity.users (token, email, firebase_uid, device) values (900001, 'member@example.invalid', 'uid-1', 'Old phone')");

        await PostFeedbackAsync(TestApi.SignedInAs("uid-1", Member));

        Assert.That((await UserAsync(900001))["device"], Is.EqualTo("Old phone"));
    }

    [Test]
    public async Task A_request_with_no_tracking_values_writes_nothing_not_even_lastlogin()
    {
        // PHP's api_update_login_info returns before the UPDATE when every tracking value is empty.
        await InsertUserAsync(900001, Member, "uid-1");

        await PostFeedbackAsync(TestApi.SignedInAs("uid-1", Member));

        Assert.That((await UserAsync(900001))["lastlogin"], Is.Null);
    }

    [Test]
    public async Task A_public_route_needs_no_sign_in()
    {
        using var client = factory.CreateClient();

        var response = await client.GetAsync(new Uri("/health", UriKind.Relative));

        Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK));
    }

    private static void AssertDetail(Reply reply, HttpStatusCode status, string detail)
    {
        Assert.That(reply.Status, Is.EqualTo(status));
        Assert.That(reply.Body.GetProperty("detail").GetString(), Is.EqualTo(detail));
    }

    private static Task<long> CountUsersAsync() =>
        TestDatabase.ScalarAsync<long>("select count(*) from identity.users", TestDatabase.OwnerConnection);

    private static async Task<Dictionary<string, string?>> UserAsync(int token) =>
        await TestDatabase.RowAsync("select * from identity.users where token = " + token) ?? throw new AssertionException("No user " + token);

    private static Task InsertUserAsync(int token, string email, string? uid = null) =>
        TestDatabase.ExecuteAsync(
            "insert into identity.users (token, email, firebase_uid) values (" + token + ", '" + email + "', "
            + (uid is null ? "null" : "'" + uid + "'") + ")");

    private static Task InsertDeletionAsync(int token, string status) =>
        TestDatabase.ExecuteAsync(
            "insert into identity.account_deletion_requests (token, status, contact_email, requested_at) values (" + token + ", '" + status + "', 'x@example.invalid', now())");

    private static Task InsertCompletedDeletionAsync(string email, string completedAt) =>
        TestDatabase.ExecuteAsync(
            "insert into identity.account_deletion_requests (token, status, contact_email, requested_at, completed_at) values (900009, 'completed', '"
            + email + "', now() - interval '3 hours', " + completedAt + ")");

    private Task<Reply> PostFeedbackAsync(IEnumerable<KeyValuePair<string, string>> headers) =>
        SendAsync("/feedback", headers, FeedbackBody);

    private Task<Reply> LinkAsync(IEnumerable<KeyValuePair<string, string>> headers) =>
        SendAsync("/auth/link", headers, null);

    private async Task<Reply> SendAsync(string path, IEnumerable<KeyValuePair<string, string>> headers, string? json)
    {
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Post, new Uri(path, UriKind.Relative));
        if (json is not null)
        {
            request.Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");
        }

        foreach (var (name, value) in headers)
        {
            request.Headers.TryAddWithoutValidation(name, value);
        }

        using var response = await client.SendAsync(request);
        var text = await response.Content.ReadAsStringAsync();
        return new Reply(response.StatusCode, text.Length == 0 ? default : JsonDocument.Parse(text).RootElement.Clone());
    }

    private sealed record Reply(HttpStatusCode Status, JsonElement Body);
}
