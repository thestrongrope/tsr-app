using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Access.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// The response header <c>X-Permissions-Revision</c> (PHP lib/auth.php api_authenticate, lib/permissions_snapshot.php): every
/// response of a request whose sign-in passed carries the member's revision as it was when they signed in, whatever the route
/// then answers; a request refused at sign-in, an unsigned route and unreadable permissions carry none.
/// </summary>
public sealed class PermissionsRevisionHeaderTests
{
    private const string Header = "X-Permissions-Revision";
    private static readonly KeyValuePair<string, string>[] Member = [.. TestApi.SignedInAs("uid-rev-member", "rev.member@example.invalid")];
    private static readonly KeyValuePair<string, string>[] Admin = [.. TestApi.SignedInAs("uid-rev-admin", "rev.admin@example.invalid")];

    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public void StartApi() => factory = TestApi.Create();

    [OneTimeTearDown]
    public void StopApi() => factory.Dispose();

    [SetUp]
    public Task SeedAsync() => TestDatabase.ExecuteAsync(
        """
        truncate identity.users, identity.account_deletion_requests restart identity cascade;
        truncate access.user_roles, access.user_permissions;
        insert into identity.users (token, email, firebase_uid) values
          (900701, 'rev.member@example.invalid', 'uid-rev-member'),
          (900702, 'rev.admin@example.invalid', 'uid-rev-admin'),
          (900703, 'rev.leaving@example.invalid', 'uid-rev-leaving'),
          (0, 'rev.guest@example.invalid', 'uid-rev-guest');
        insert into access.user_roles (user_id, roleid) select id, 1 from identity.users where token = 900702;
        insert into access.user_permissions (user_id, permission) select id, 'quiz:admin:all' from identity.users where token = 900702;
        insert into identity.account_deletion_requests (id, token, status, source, contact_name, contact_email, reason, requested_at)
          values (97001, 900703, 'pending', 'app', 'Contact', 'x@example.invalid', 'because', now());
        """);

    [Test]
    public async Task The_header_is_the_revision_of_me_permissions_for_each_member()
    {
        var member = await SendAsync(HttpMethod.Get, "/me/permissions", Member);
        var admin = await SendAsync(HttpMethod.Get, "/me/permissions", Admin);

        Assert.That(member.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(member.Revision, Does.Match("^[0-9a-f]{16}$"));
        Assert.That(member.Revision, Is.EqualTo(RevisionIn(member.Body)));
        Assert.That(admin.Revision, Is.EqualTo(RevisionIn(admin.Body)));
        Assert.That(admin.Revision, Is.Not.EqualTo(member.Revision));
    }

    [Test]
    public async Task The_header_is_on_a_304_a_404_a_403_and_a_422_of_a_signed_in_request()
    {
        var adminRevision = await RevisionOfAsync(Admin);
        var memberRevision = await RevisionOfAsync(Member);

        var notModified = await SendAsync(HttpMethod.Get, "/me/permissions", [.. Member, new("If-None-Match", "*")]);
        var notFound = await SendAsync(HttpMethod.Get, "/me/permissions/nope:read", Member);
        var forbidden = await SendAsync(HttpMethod.Get, "/admin/permissions/members", Member);
        var unprocessable = await SendAsync(HttpMethod.Post, "/admin/permissions/members/900701/grants", Admin, "not json");

        Assert.That((notModified.Status, notModified.Revision), Is.EqualTo((HttpStatusCode.NotModified, memberRevision)));
        Assert.That((notFound.Status, notFound.Revision), Is.EqualTo((HttpStatusCode.NotFound, memberRevision)));
        Assert.That((forbidden.Status, forbidden.Revision), Is.EqualTo((HttpStatusCode.Forbidden, memberRevision)));
        Assert.That((unprocessable.Status, unprocessable.Revision), Is.EqualTo((HttpStatusCode.UnprocessableEntity, adminRevision)));
    }

    [Test]
    public async Task The_header_is_on_a_download()
    {
        var file = await SendAsync(HttpMethod.Get, "/reports/active-teachers/download?format=xlsx", Admin);

        Assert.That(file.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(file.ContentType, Does.Contain("spreadsheetml"));
        Assert.That(file.Revision, Is.EqualTo(await RevisionOfAsync(Admin)));
    }

    [TestCase("missing")]
    [TestCase("invalid")]
    [TestCase("noemail")]
    public async Task A_401_has_no_header(string outcome)
    {
        var reply = await SendAsync(HttpMethod.Get, "/me/permissions", [new(TestApi.Outcome, outcome)]);

        Assert.That((reply.Status, reply.Revision), Is.EqualTo((HttpStatusCode.Unauthorized, (string?)null)));
    }

    [Test]
    public async Task A_public_route_has_no_header_even_with_credentials()
    {
        var reply = await SendAsync(HttpMethod.Get, "/app-version", Member);

        Assert.That((reply.Status, reply.Revision), Is.EqualTo((HttpStatusCode.OK, (string?)null)));
    }

    [Test]
    public async Task A_request_refused_at_sign_in_has_no_header()
    {
        var guest = await SendAsync(HttpMethod.Get, "/me/permissions", TestApi.SignedInAs("uid-rev-guest", "rev.guest@example.invalid"));
        var unknown = await SendAsync(HttpMethod.Post, "/feedback", TestApi.SignedInAs("uid-rev-nobody", "rev.nobody@example.invalid"), "{}");
        var leaving = await SendAsync(HttpMethod.Get, "/me/permissions", TestApi.SignedInAs("uid-rev-leaving", "rev.leaving@example.invalid"));
        var badFormat = await SendAsync(HttpMethod.Get, "/reports/active-teachers/download?format=csv", Admin);

        Assert.That((guest.Status, guest.Revision), Is.EqualTo((HttpStatusCode.Forbidden, (string?)null)));
        Assert.That((unknown.Status, unknown.Revision), Is.EqualTo((HttpStatusCode.NotFound, (string?)null)));
        Assert.That((leaving.Status, leaving.Revision), Is.EqualTo((HttpStatusCode.Forbidden, (string?)null)));
        Assert.That((badFormat.Status, badFormat.Revision), Is.EqualTo((HttpStatusCode.UnprocessableEntity, (string?)null)));
    }

    [Test]
    public async Task A_member_being_deleted_gets_the_header_on_a_route_they_may_still_call()
    {
        var reply = await SendAsync(HttpMethod.Get, "/me/deletion-request", TestApi.SignedInAs("uid-rev-leaving", "rev.leaving@example.invalid"));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.Revision, Is.EqualTo(await RevisionOfAsync(Member)), "a member with no role and no class has the plain member's revision");
    }

    [Test]
    public async Task The_sign_in_that_creates_the_member_carries_the_new_members_revision()
    {
        var plain = await RevisionOfAsync(Member);

        var created = await SendAsync(HttpMethod.Post, "/auth/link", TestApi.SignedInAs("uid-rev-new", "rev.new@example.invalid"));

        Assert.That(created.Status, Is.EqualTo(HttpStatusCode.OK), created.Body);
        Assert.That(created.Revision, Is.EqualTo(plain));
    }

    [Test]
    public async Task The_header_changes_after_a_grant_to_the_member_and_the_granting_request_carries_the_operators_own()
    {
        var before = await RevisionOfAsync(Member);
        var adminRevision = await RevisionOfAsync(Admin);

        var grant = await SendAsync(HttpMethod.Post, "/admin/permissions/members/900701/grants", Admin, """{"permission": "donors:read:all", "reason": "Needs the list"}""");
        var after = await SendAsync(HttpMethod.Get, "/me/permissions/feedback:create", Member);

        Assert.That(grant.Status, Is.EqualTo(HttpStatusCode.OK), grant.Body);
        Assert.That(grant.Revision, Is.EqualTo(adminRevision));
        Assert.That(after.Revision, Is.Not.EqualTo(before));
        Assert.That(after.Revision, Is.EqualTo(await RevisionOfAsync(Member)));
    }

    // PHP sends the header while it signs the member in, before the route runs: the request that changes the caller's own
    // permissions still carries the revision from before the change, and the next request the new one.
    [Test]
    public async Task A_request_that_changes_the_callers_own_permissions_carries_the_revision_from_before_the_change()
    {
        var before = await RevisionOfAsync(Admin);
        var grantId = await TestDatabase.ScalarAsync<int>(
            "select g.id from access.user_permissions g join identity.users u on u.id = g.user_id where u.token = 900702", TestDatabase.OwnerConnection);

        var revoke = await SendAsync(HttpMethod.Post, $"/admin/permissions/grants/{grantId}/revoke", Admin, """{"reason": "Done"}""");
        var after = await RevisionOfAsync(Admin);

        Assert.That(revoke.Status, Is.EqualTo(HttpStatusCode.OK), revoke.Body);
        Assert.That(after, Is.Not.EqualTo(before));
        Assert.That(revoke.Revision, Is.EqualTo(before));
    }

    [TestCase(false)]
    [TestCase(true)]
    public async Task Unreadable_permissions_leave_the_header_out_and_do_not_fail_a_route_that_checks_none(bool wrapped)
    {
        await using var down = factory.WithWebHostBuilder(builder =>
            builder.ConfigureTestServices(services => services.AddScoped<IClassScopes>(_ => new UnreadableClasses(900701, wrapped))));

        var works = await SendAsync(HttpMethod.Post, "/auth/link", Member, api: down);
        var unavailable = await SendAsync(HttpMethod.Get, "/me/permissions", Member, api: down);

        Assert.That((works.Status, works.Revision), Is.EqualTo((HttpStatusCode.OK, (string?)null)), works.Body);
        Assert.That((unavailable.Status, unavailable.Revision), Is.EqualTo((HttpStatusCode.ServiceUnavailable, (string?)null)));
    }

    [Test]
    public async Task The_header_and_the_route_share_one_resolution_of_the_member()
    {
        var counter = new CountingClasses();
        await using var counted = factory.WithWebHostBuilder(builder =>
            builder.ConfigureTestServices(services => services.AddScoped<IClassScopes>(_ => counter)));

        var reply = await SendAsync(HttpMethod.Get, "/me/permissions", Member, api: counted);

        Assert.That(reply.Revision, Is.EqualTo(RevisionIn(reply.Body)));
        Assert.That(counter.Memberships, Is.EqualTo(1));
    }

    private static string? RevisionIn(string body)
    {
        using var json = JsonDocument.Parse(body);
        return json.RootElement.GetProperty("revision").GetString();
    }

    private async Task<string?> RevisionOfAsync(IEnumerable<KeyValuePair<string, string>> who) =>
        RevisionIn((await SendAsync(HttpMethod.Get, "/me/permissions", who)).Body);

    private async Task<HeaderReply> SendAsync(
        HttpMethod method, string path, IEnumerable<KeyValuePair<string, string>> headers, string? json = null, WebApplicationFactory<Program>? api = null)
    {
        using var client = (api ?? factory).CreateClient();
        using var request = new HttpRequestMessage(method, path);
        foreach (var (name, value) in headers)
        {
            Assert.That(request.Headers.TryAddWithoutValidation(name, value), Is.True);
        }

        if (json is not null)
        {
            request.Content = new StringContent(json, Encoding.UTF8, new MediaTypeHeaderValue("application/json"));
        }

        using var response = await client.SendAsync(request);
        var revision = response.Headers.NonValidated.TryGetValues(Header, out var values) ? values.ToString() : null;
        return new HeaderReply(response.StatusCode, await response.Content.ReadAsStringAsync(), revision, response.Content.Headers.ContentType?.ToString());
    }

    private sealed record HeaderReply(HttpStatusCode Status, string Body, string? Revision, string? ContentType);

    /// <summary>The classes port with no classes, counting how often a member's class facts are asked for.</summary>
    private sealed class CountingClasses : IClassScopes
    {
        public int Memberships { get; private set; }

        public Task<ClassMemberships> MembershipsAsync(int ofToken, CancellationToken ct)
        {
            Memberships++;
            return Task.FromResult(new ClassMemberships([], [], []));
        }

        public Task<ClassFacts?> ActiveClassAsync(int classId, CancellationToken ct) => Task.FromResult<ClassFacts?>(null);

        public Task<IReadOnlyList<ClassFacts>> ActiveClassesAsync(CancellationToken ct) => Task.FromResult<IReadOnlyList<ClassFacts>>([]);
    }
}
