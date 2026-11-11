using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Tsr.Db.Tests;

/// <summary>
/// What the membership operation tests share: a clean membership schema, synthetic members (a user plus a profile row), and a
/// request sent as one of them through the API as the limited database role. Members are named <c>m&lt;token&gt;@example.invalid</c>.
/// </summary>
internal sealed class MembershipTestKit : IDisposable
{
    private readonly WebApplicationFactory<Program> _factory = TestApi.Create();

    public static Task ResetAsync() => TestDatabase.ExecuteAsync(
        """
        truncate identity.users, identity.account_deletion_requests, access.user_roles, membership.member_profiles,
          membership.class_registrations, membership.class_registrations_languages, membership.student_interests,
          membership.user_guardians restart identity cascade
        """);

    /// <summary>A member with a profile row. Returns the user id.</summary>
    public static async Task<int> AddMemberAsync(int token, string? name = null, string? gender = null, string? firstName = null)
    {
        var id = await TestDatabase.ScalarAsync<int>(
            $"insert into identity.users (token, email, firebase_uid) values ({token}, '{EmailOf(token)}', 'uid-{token}') returning id",
            TestDatabase.OwnerConnection);
        await TestDatabase.ExecuteAsync(
            "insert into membership.member_profiles (user_id, name, gender, first_name) values "
            + $"({id}, {Quote(name ?? "Member " + token)}, {Quote(gender)}, {Quote(firstName)})");
        return id;
    }

    public static string EmailOf(int token) => "m" + token + "@example.invalid";

    public static string Quote(string? value) => value is null ? "null" : "'" + value.Replace("'", "''", StringComparison.Ordinal) + "'";

    public static Task<long> CountAsync(string table, string where = "true") =>
        TestDatabase.ScalarAsync<long>($"select count(*) from {table} where {where}", TestDatabase.OwnerConnection);

    public async Task<Reply> SendAsync(int token, HttpMethod method, string path, string? json = null, string? userAgent = null)
    {
        using var client = _factory.CreateClient();
        using var request = new HttpRequestMessage(method, path);
        foreach (var (name, value) in TestApi.SignedInAs("uid-" + token, EmailOf(token)))
        {
            request.Headers.Add(name, value);
        }

        if (userAgent is not null)
        {
            request.Headers.TryAddWithoutValidation("User-Agent", userAgent);
        }

        if (json is not null)
        {
            request.Content = new StringContent(json, Encoding.UTF8, new MediaTypeHeaderValue("application/json"));
        }

        using var response = await client.SendAsync(request);
        var text = await response.Content.ReadAsStringAsync();
        return new Reply(response.StatusCode, text);
    }

    public void Dispose() => _factory.Dispose();

    /// <summary>A status and the body text; <see cref="Json"/> parses it.</summary>
    internal sealed record Reply(HttpStatusCode Status, string Body)
    {
        public JsonNode? Json => string.IsNullOrEmpty(Body) ? null : JsonNode.Parse(Body);

        public string? Detail => Json?["detail"]?.GetValue<string>();
    }
}
