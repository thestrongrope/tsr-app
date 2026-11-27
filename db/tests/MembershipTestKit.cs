using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;
using ClosedXML.Excel;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace Tsr.Db.Tests;

/// <summary>
/// What the membership operation tests share: a clean membership schema, synthetic members (a user plus a profile row), and a
/// request sent as one of them through the API as the limited database role. Members are named <c>m&lt;token&gt;@example.invalid</c>.
/// </summary>
internal sealed class MembershipTestKit : IDisposable
{
    private readonly WebApplicationFactory<Program> _factory;

    /// <param name="configure">Replaces services of the API under test (for example the PDF renderer, which needs a Gotenberg container).</param>
    public MembershipTestKit(Action<IServiceCollection>? configure = null) =>
        _factory = configure is null ? TestApi.Create() : TestApi.Create().WithWebHostBuilder(builder => builder.ConfigureTestServices(configure));

    /// <summary>The API under test with one more setting (for example <c>TSR_PUBLIC_WEB_BASE</c>, which the test API leaves unset).</summary>
    public MembershipTestKit(string setting, string value) =>
        _factory = TestApi.Create().WithWebHostBuilder(builder => builder.UseSetting(setting, value));

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

    public async Task<Reply> SendAsync(int token, HttpMethod method, string path, string? json = null, string? userAgent = null, CancellationToken ct = default)
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

        using var response = await client.SendAsync(request, ct);
        var text = await response.Content.ReadAsStringAsync(ct);
        return new Reply(response.StatusCode, text);
    }

    /// <summary>A request as nobody (no credentials): 401 expected.</summary>
    public async Task<Reply> SendUnsignedAsync(HttpMethod method, string path, string? json = null)
    {
        var raw = await SendRawAsync(null, method, path, json);
        return new Reply(raw.Status, raw.Body);
    }

    /// <summary>A request as one member (null: nobody) that also returns the Cache-Control header.</summary>
    public async Task<RawReply> SendRawAsync(int? token, HttpMethod method, string path, string? json = null)
    {
        using var client = _factory.CreateClient();
        using var request = new HttpRequestMessage(method, path);
        if (token is null)
        {
            request.Headers.Add(TestApi.Outcome, "missing");
        }
        else
        {
            foreach (var (name, value) in TestApi.SignedInAs("uid-" + token, EmailOf(token.Value)))
            {
                request.Headers.Add(name, value);
            }
        }

        if (json is not null)
        {
            request.Content = new StringContent(json, Encoding.UTF8, new MediaTypeHeaderValue("application/json"));
        }

        using var response = await client.SendAsync(request);
        return new RawReply(response.StatusCode, await response.Content.ReadAsStringAsync(), response.Headers.CacheControl?.ToString());
    }

    /// <summary>A GET as the test API's sign-in stub answers it for <paramref name="outcome"/> ("invalid", "noemail", ...), with the Cache-Control header.</summary>
    public async Task<RawReply> SendWithOutcomeAsync(string outcome, string path)
    {
        using var client = _factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        request.Headers.Add(TestApi.Outcome, outcome);
        using var response = await client.SendAsync(request);
        return new RawReply(response.StatusCode, await response.Content.ReadAsStringAsync(), response.Headers.CacheControl?.ToString());
    }

    /// <summary>A download as one caller (or, with <paramref name="signedIn"/> false, as nobody): the status, the headers that matter and the raw bytes.</summary>
    public async Task<Download> DownloadAsync(int token, string path, bool signedIn = true)
    {
        using var client = _factory.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, path);
        if (signedIn)
        {
            foreach (var (name, value) in TestApi.SignedInAs("uid-" + token, EmailOf(token)))
            {
                request.Headers.Add(name, value);
            }
        }
        else
        {
            request.Headers.Add(TestApi.Outcome, "missing");
        }

        using var response = await client.SendAsync(request);
        return new Download(
            response.StatusCode,
            response.Content.Headers.ContentType?.ToString(),
            response.Content.Headers.ContentDisposition?.ToString(),
            await response.Content.ReadAsByteArrayAsync());
    }

    public void Dispose() => _factory.Dispose();

    /// <summary>One download answer. <see cref="Text"/> is the body read as UTF-8 (for a JSON refusal); <see cref="Cells"/> every non-empty cell of a workbook, as text.</summary>
    internal sealed record Download(HttpStatusCode Status, string? ContentType, string? Disposition, byte[] Bytes)
    {
        public string Text => Encoding.UTF8.GetString(Bytes);

        public XLWorkbook Workbook() => new(new MemoryStream(Bytes));

        public IReadOnlyList<string> Cells()
        {
            using var book = Workbook();
            return [.. book.Worksheets.SelectMany(sheet => sheet.CellsUsed()).Select(cell => cell.GetString())];
        }
    }

    internal sealed record RawReply(HttpStatusCode Status, string Body, string? CacheControl);

    /// <summary>A status and the body text; <see cref="Json"/> parses it.</summary>
    internal sealed record Reply(HttpStatusCode Status, string Body)
    {
        public JsonNode? Json => string.IsNullOrEmpty(Body) ? null : JsonNode.Parse(Body);

        public string? Detail => Json?["detail"]?.GetValue<string>();
    }
}
