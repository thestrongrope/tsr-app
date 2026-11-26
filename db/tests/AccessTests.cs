using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using NUnit.Framework;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Db.Tests;

/// <summary>
/// access against a real database, as the limited role: the catalog the migrations seed (copied from PHP), the
/// role and grants it reads, and the three permission routes over HTTP. The decision rules themselves are unit
/// tested in domains/access/api; the HTTP contract against PHP is domains/access/spec/tests.
/// </summary>
public sealed class AccessTests
{
    private WebApplicationFactory<Program> factory = null!;

    [OneTimeSetUp]
    public void StartApi() => factory = TestApi.Create();

    [OneTimeTearDown]
    public void StopApi() => factory.Dispose();

    [SetUp]
    public Task CleanAsync() => TestDatabase.ExecuteAsync(
        """
        truncate identity.users restart identity cascade;
        truncate access.user_roles, access.user_permissions;
        insert into identity.users (token, email, firebase_uid) values
          (900101, 'member@example.invalid', 'uid-member'),
          (900102, 'admin@example.invalid', 'uid-admin'),
          (900103, 'gents@example.invalid', 'uid-gents'),
          (900104, 'granted@example.invalid', 'uid-granted'),
          (0, 'guest@example.invalid', 'uid-guest');
        insert into access.user_roles (user_id, roleid)
          select id, case token when 900102 then 1 when 900103 then 3 end from identity.users where token in (900102, 900103);
        insert into access.user_permissions (user_id, permission, revoked_at)
          select id, 'standard-mcqs:update:all', null from identity.users where token = 900104
          union all
          select id, 'summary-report:read:all', now() from identity.users where token = 900104;
        """);

    // --- schema and catalog ---

    [Test]
    public async Task The_catalog_is_PHPs_102_permissions_and_7_roles()
    {
        Assert.That(await CountAsync("access.permissions"), Is.EqualTo(102));
        Assert.That(await CountAsync("access.roles"), Is.EqualTo(7));
        Assert.That(await CountAsync("access.permissions where name = 'quiz:reset:all'"), Is.EqualTo(1));
    }

    [TestCase(1, 38)]
    [TestCase(3, 18)]
    [TestCase(4, 18)]
    [TestCase(5, 13)]
    [TestCase(7, 1)]
    public async Task Each_role_grants_what_PHPs_role_permissions_grant(int role, int count)
    {
        Assert.That(await CountAsync("access.role_permissions where roleid = " + role), Is.EqualTo(count));
    }

    [Test]
    public async Task Quiz_admin_and_quiz_reset_are_granted_to_no_role()
    {
        Assert.That(await CountAsync("access.role_permissions where permission in ('quiz:admin:all', 'quiz:reset:all')"), Is.EqualTo(0));
    }

    [Test]
    public async Task The_role_no_longer_lives_on_the_identity_users_table()
    {
        Assert.That(
            await CountAsync("information_schema.columns where table_schema = 'identity' and table_name = 'users' and column_name = 'roleid'"),
            Is.EqualTo(0));
    }

    // --- the engine against stored data ---

    [Test]
    public async Task A_member_with_no_role_row_holds_the_member_set_only()
    {
        var access = await ForUserAsync(900101);

        Assert.That(access.Permissions, Has.Count.EqualTo(21));
        Assert.That(access.Scopes.Gender, Is.Null);
    }

    [Test]
    public async Task A_super_admin_holds_the_roles_grants_on_top_of_the_member_set()
    {
        var access = await ForUserAsync(900102);

        Assert.That(access.Permissions, Does.Contain("feedback:review:all").And.Contain("classes:read:all").And.Contain("profile:read:self"));
        Assert.That(access.Permissions, Does.Not.Contain("quiz:admin:all"));
    }

    [Test]
    public async Task A_gents_admin_has_the_gender_scope_1()
    {
        var access = await ForUserAsync(900103);

        Assert.That(access.Scopes.Gender, Is.EqualTo(1));
        Assert.That(access.Permissions, Does.Contain("classes:read:gender"));
    }

    [Test]
    public async Task A_live_named_grant_is_held_and_a_revoked_one_is_not()
    {
        var access = await ForUserAsync(900104);

        Assert.That(access.Permissions, Does.Contain("standard-mcqs:update:all"));
        Assert.That(access.Permissions, Does.Not.Contain("summary-report:read:all"));
    }

    [Test]
    public async Task Permissions_come_back_in_ordinal_catalog_order()
    {
        var access = await ForUserAsync(900102);

        Assert.That(access.Permissions, Is.Ordered.Using<string>(StringComparer.Ordinal));
    }

    [Test]
    public async Task A_guest_holds_nothing_and_is_refused_everything()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var permissions = scope.ServiceProvider.GetRequiredService<Permissions>();
        var guest = new Caller(await UserIdAsync(0), 0);

        var access = await permissions.ForUserAsync(guest, CancellationToken.None);

        Assert.That(access.Permissions, Is.Empty);
        Assert.That(await permissions.CanAsync(guest, "profile:read", AccessTarget.None, CancellationToken.None), Is.False);
    }

    [Test]
    public async Task CanAsync_with_no_target_allows_a_held_action_and_refuses_one_not_held()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var permissions = scope.ServiceProvider.GetRequiredService<Permissions>();
        var member = new Caller(await UserIdAsync(900101), 900101);

        Assert.That(await permissions.CanAsync(member, "feedback:create", AccessTarget.None, CancellationToken.None), Is.True);
        Assert.That(await permissions.CanAsync(member, "feedback:review", AccessTarget.None, CancellationToken.None), Is.False);
    }

    [Test]
    public async Task CanAsync_for_an_unknown_action_throws_because_it_is_a_bug_in_the_caller()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var permissions = scope.ServiceProvider.GetRequiredService<Permissions>();
        var member = new Caller(await UserIdAsync(900101), 900101);

        _ = await Assert.ThrowsAsync<ArgumentException>(() => permissions.CanAsync(member, "feedback:create:self", AccessTarget.None, CancellationToken.None));
    }

    [Test]
    public async Task With_no_classes_a_class_target_is_refused_even_with_scope_all()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var permissions = scope.ServiceProvider.GetRequiredService<Permissions>();
        var admin = new Caller(await UserIdAsync(900102), 900102);

        Assert.That(await permissions.CanAsync(admin, "classes:read", AccessTarget.ForClass(1), CancellationToken.None), Is.False);
        Assert.That(await permissions.CanAsync(admin, "classes:read", AccessTarget.None, CancellationToken.None), Is.True);
    }

    [Test]
    public async Task Reach_for_a_super_admin_is_all_and_for_a_member_is_nothing()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var permissions = scope.ServiceProvider.GetRequiredService<Permissions>();
        var admin = new Caller(await UserIdAsync(900102), 900102);
        var member = new Caller(await UserIdAsync(900101), 900101);

        Assert.That((await permissions.ReachAsync(admin, "classes:read", CancellationToken.None)).All, Is.True);
        Assert.That((await permissions.ReachAsync(member, "classes:read", CancellationToken.None)).All, Is.False);
    }

    // --- the three routes ---

    [Test]
    public async Task Me_permissions_is_401_without_sign_in()
    {
        var reply = await GetAsync("/me/permissions", [new(TestApi.Outcome, "missing")]);

        Assert.That(reply.StatusCode, Is.EqualTo(HttpStatusCode.Unauthorized));
    }

    [Test]
    public async Task Me_permissions_has_PHPs_keys_with_a_null_gender_and_a_microsecond_issued_at()
    {
        var reply = await GetAsync("/me/permissions", TestApi.SignedInAs("uid-member", "member@example.invalid"));
        using var body = JsonDocument.Parse(await reply.Content.ReadAsStringAsync());
        var root = body.RootElement;

        Assert.That(reply.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(root.EnumerateObject().Select(p => p.Name), Is.EqualTo(Expect("version", "issued_at", "permissions", "scopes", "navigation", "revision")));
        Assert.That(root.GetProperty("version").GetInt32(), Is.EqualTo(5));
        Assert.That(root.GetProperty("issued_at").GetString(), Does.Match(@"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}\+00:00$"));
        Assert.That(root.GetProperty("permissions").GetArrayLength(), Is.EqualTo(21));
        var scopes = root.GetProperty("scopes");
        Assert.That(scopes.GetProperty("gender").ValueKind, Is.EqualTo(JsonValueKind.Null));
        foreach (var key in new[] { "assigned", "assigned_genders", "own", "taught", "enrolled" })
        {
            Assert.That(scopes.GetProperty(key).GetArrayLength(), Is.EqualTo(0), key);
        }

        Assert.That(root.GetProperty("navigation").GetRawText(), Is.EqualTo("""{"classes":false,"manage":false}"""));
        Assert.That(root.GetProperty("revision").GetString(), Does.Match("^[0-9a-f]{16}$"));
    }

    [TestCase("uid-member", "member@example.invalid", false, false)]
    [TestCase("uid-admin", "admin@example.invalid", true, true)]
    [TestCase("uid-gents", "gents@example.invalid", true, true)]
    [TestCase("uid-granted", "granted@example.invalid", false, true)]
    public async Task Me_permissions_says_which_tabs_the_member_has(string uid, string email, bool classes, bool manage)
    {
        var reply = await GetAsync("/me/permissions", TestApi.SignedInAs(uid, email));
        using var body = JsonDocument.Parse(await reply.Content.ReadAsStringAsync());
        var navigation = body.RootElement.GetProperty("navigation");

        Assert.That(navigation.GetProperty("classes").GetBoolean(), Is.EqualTo(classes));
        Assert.That(navigation.GetProperty("manage").GetBoolean(), Is.EqualTo(manage));
    }

    [Test]
    public async Task Me_permissions_carries_its_revision_as_the_ETag_and_is_private_to_the_member()
    {
        var reply = await PermissionsAsync(factory, null);
        using var body = JsonDocument.Parse(reply.Body);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.ETag, Is.EqualTo("\"" + body.RootElement.GetProperty("revision").GetString() + "\""));
        Assert.That(reply.CacheControl, Is.EqualTo("private, no-cache"));
        Assert.That(reply.Vary, Is.EqualTo("Authorization"));
    }

    [TestCase("{0}")]
    [TestCase("W/{0}")]
    [TestCase("\"stale\", {0}")]
    [TestCase("*")]
    public async Task Me_permissions_is_304_with_no_body_when_If_None_Match_names_the_tag(string sent)
    {
        var first = await PermissionsAsync(factory, null);

        var reply = await PermissionsAsync(factory, sent.Replace("{0}", first.ETag, StringComparison.Ordinal));

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.NotModified));
        Assert.That(reply.Body, Is.Empty);
        Assert.That(reply.ETag, Is.EqualTo(first.ETag));
        Assert.That(reply.CacheControl, Is.EqualTo("private, no-cache"));
        Assert.That(reply.Vary, Is.EqualTo("Authorization"));
    }

    [TestCase("\"fedcba9876543210\"")]
    [TestCase("\"\"")]
    [TestCase("unquoted")]
    public async Task Me_permissions_is_the_full_answer_when_If_None_Match_names_another_tag(string sent)
    {
        var first = await PermissionsAsync(factory, null);

        var reply = await PermissionsAsync(factory, sent == "unquoted" ? first.ETag!.Trim('"') : sent);

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(reply.ETag, Is.EqualTo(first.ETag));
        Assert.That(reply.Body, Does.Contain("\"revision\""));
    }

    [TestCase(false)]
    [TestCase(true)]
    public async Task Me_permissions_is_503_with_no_ETag_when_the_permissions_cannot_be_loaded_even_for_a_matching_tag(bool wrapped)
    {
        await using var down = factory.WithWebHostBuilder(builder =>
            builder.ConfigureTestServices(services => services.AddScoped<IClassScopes>(_ => new UnreadableClasses(900101, wrapped))));

        var reply = await PermissionsAsync(down, "*");

        Assert.That(reply.Status, Is.EqualTo(HttpStatusCode.ServiceUnavailable));
        Assert.That(reply.Body, Is.EqualTo("""{"detail":"Permissions could not be loaded. Try again."}"""));
        Assert.That(reply.ETag, Is.Null);
    }

    // PHP's json_encode and .NET's writer escape other characters differently, and the revision is a hash of that JSON.
    [Test]
    public async Task Catalog_names_are_plain_so_the_revision_equals_PHPs()
    {
        Assert.That(await CountAsync("access.permissions where name !~ '^[a-z0-9:-]+$'"), Is.EqualTo(0));
    }

    [Test]
    public async Task Every_admin_module_permission_is_an_action_of_the_catalog()
    {
        var names = await TestDatabase.ScalarAsync<string>("select string_agg(name, ',') from access.permissions", TestDatabase.OwnerConnection);
        var actions = names.Split(',').Select(name => name[..name.LastIndexOf(':')]).ToHashSet(StringComparer.Ordinal);

        Assert.That(Tsr.Access.Api.Domain.PermissionsSnapshot.AdminModulePermissions.Select(p => p.Action), Is.SubsetOf(actions));
    }

    [Test]
    public async Task Me_permissions_for_a_guest_is_403_registration_incomplete()
    {
        var reply = await GetAsync("/me/permissions", TestApi.SignedInAs("uid-guest", "guest@example.invalid"));

        Assert.That(reply.StatusCode, Is.EqualTo(HttpStatusCode.Forbidden));
        Assert.That(await reply.Content.ReadAsStringAsync(), Does.Contain("Registration incomplete"));
    }

    [TestCase("/me/permissions/feedback:create")]
    [TestCase("/me/permissions/feedback%3Acreate")]
    public async Task One_permission_answers_the_scopes_held(string path)
    {
        var reply = await GetAsync(path, TestApi.SignedInAs("uid-member", "member@example.invalid"));
        using var body = JsonDocument.Parse(await reply.Content.ReadAsStringAsync());

        Assert.That(reply.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.RootElement.GetProperty("permission").GetString(), Is.EqualTo("feedback:create"));
        Assert.That(body.RootElement.GetProperty("scopes").EnumerateArray().Select(e => e.GetString()), Is.EqualTo(Expect("self")));
    }

    [Test]
    public async Task One_permission_not_held_has_empty_scopes()
    {
        var reply = await GetAsync("/me/permissions/feedback:review", TestApi.SignedInAs("uid-member", "member@example.invalid"));
        using var body = JsonDocument.Parse(await reply.Content.ReadAsStringAsync());

        Assert.That(reply.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(body.RootElement.GetProperty("scopes").GetArrayLength(), Is.EqualTo(0));
    }

    [TestCase("/me/permissions/nope:read")]
    [TestCase("/me/permissions/feedback:create:self")]
    public async Task An_unknown_permission_is_404(string path)
    {
        var reply = await GetAsync(path, TestApi.SignedInAs("uid-member", "member@example.invalid"));

        Assert.That(reply.StatusCode, Is.EqualTo(HttpStatusCode.NotFound));
        Assert.That(await reply.Content.ReadAsStringAsync(), Does.Contain("Unknown permission"));
    }

    [Test]
    public async Task User_permissions_lists_the_role_pages_and_the_class_facts()
    {
        var reply = await GetAsync("/user/permissions", TestApi.SignedInAs("uid-gents", "gents@example.invalid"));
        using var body = JsonDocument.Parse(await reply.Content.ReadAsStringAsync());
        var root = body.RootElement;

        Assert.That(reply.StatusCode, Is.EqualTo(HttpStatusCode.OK));
        Assert.That(root.GetProperty("version").GetInt32(), Is.EqualTo(3));
        Assert.That(root.GetProperty("role_id").GetInt32(), Is.EqualTo(3));
        Assert.That(root.GetProperty("role_name").GetString(), Is.EqualTo("GENTS_ADMIN"));
        Assert.That(root.GetProperty("permissions").GetArrayLength(), Is.EqualTo(5));
        Assert.That(root.GetProperty("applicable_roles")[0].GetProperty("source").GetString(), Is.EqualTo("database_role"));
        Assert.That(root.GetProperty("enrolled").GetBoolean(), Is.False);
        Assert.That(root.GetProperty("class_count").GetInt32(), Is.EqualTo(0));
        Assert.That(root.GetProperty("mcq_admin").GetBoolean(), Is.False);
        Assert.That(root.GetProperty("is_teacher").GetBoolean(), Is.False);
    }

    private static string[] Expect(params string[] items) => items;

    private async Task<UserAccess> ForUserAsync(int token)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var permissions = scope.ServiceProvider.GetRequiredService<Permissions>();
        return await permissions.ForUserAsync(new Caller(await UserIdAsync(token), token), CancellationToken.None);
    }

    private static Task<int> UserIdAsync(int token) =>
        TestDatabase.ScalarAsync<int>("select id from identity.users where token = " + token, TestDatabase.OwnerConnection);

    private static Task<long> CountAsync(string fromWhere) =>
        TestDatabase.ScalarAsync<long>("select count(*) from " + fromWhere, TestDatabase.OwnerConnection);

    private async Task<HttpResponseMessage> GetAsync(string path, IEnumerable<KeyValuePair<string, string>> headers)
    {
        using var client = factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        foreach (var (name, value) in headers)
        {
            request.Headers.Add(name, value);
        }

        return await client.SendAsync(request);
    }

    private sealed record PermissionsReply(HttpStatusCode Status, string Body, string? ETag, string? CacheControl, string? Vary);

    // GET /me/permissions as the plain member, with the headers as the server sent them (not re-formatted by HttpClient).
    private static async Task<PermissionsReply> PermissionsAsync(WebApplicationFactory<Program> api, string? ifNoneMatch)
    {
        using var client = api.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/me/permissions");
        foreach (var (name, value) in TestApi.SignedInAs("uid-member", "member@example.invalid"))
        {
            request.Headers.Add(name, value);
        }

        if (ifNoneMatch is not null)
        {
            Assert.That(request.Headers.TryAddWithoutValidation("If-None-Match", ifNoneMatch), Is.True);
        }

        using var response = await client.SendAsync(request);
        return new PermissionsReply(response.StatusCode, await response.Content.ReadAsStringAsync(), Raw(response, "ETag"), Raw(response, "Cache-Control"), Raw(response, "Vary"));
    }

    private static string? Raw(HttpResponseMessage response, string header) =>
        response.Headers.NonValidated.TryGetValues(header, out var values) ? values.ToString() : null;
}

/// <summary>The classes port with unreadable storage for one member: every question about that member fails as a database does.</summary>
internal sealed class UnreadableClasses(int token, bool wrapped = false) : IClassScopes
{
    // wrapped: the PostgreSQL provider reports a transient failure (a lost connection, a command timeout) as an InvalidOperationException around the database exception.
    public Task<ClassMemberships> MembershipsAsync(int ofToken, CancellationToken ct) =>
        ofToken != token ? Task.FromResult(new ClassMemberships([], [], []))
        : wrapped ? throw new InvalidOperationException("An exception has been raised that is likely due to a transient failure.", new StorageDown())
        : throw new StorageDown();

    public Task<ClassFacts?> ActiveClassAsync(int classId, CancellationToken ct) => Task.FromResult<ClassFacts?>(null);

    public Task<IReadOnlyList<ClassFacts>> ActiveClassesAsync(CancellationToken ct) => Task.FromResult<IReadOnlyList<ClassFacts>>([]);

    private sealed class StorageDown() : System.Data.Common.DbException("storage is down");
}
