using System.Globalization;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Tsr.Identity.Api;

/// <summary>The parts of a Google service account JSON the Identity Toolkit calls need. Never logged, never in a message.</summary>
internal sealed record GoogleServiceAccount(string ClientEmail, string PrivateKey, string ProjectId)
{
    private const int MaxJsonBytes = 16 * 1024;

    /// <summary>Reads the base64 of a service account JSON (PHP's FIREBASE_SERVICE_ACCOUNT_B64). Throws, without echoing the value, when it is not one.</summary>
    public static GoogleServiceAccount Parse(string base64)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(base64);
        try
        {
            var bytes = Convert.FromBase64String(base64.Trim());
            if (bytes.Length > MaxJsonBytes)
            {
                throw new FormatException("too large");
            }

            using var document = JsonDocument.Parse(bytes);
            var root = document.RootElement;
            return new GoogleServiceAccount(Text(root, "client_email"), Text(root, "private_key"), Text(root, "project_id"));
        }
        catch (Exception e) when (e is FormatException or JsonException or InvalidOperationException or KeyNotFoundException)
        {
            throw new InvalidOperationException(GoogleFirebaseAccounts.SettingKey + " is not the base64 of a service account JSON with client_email, private_key and project_id.", e);
        }
    }

    private static string Text(JsonElement root, string name)
    {
        if (root.ValueKind != JsonValueKind.Object || !root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String || string.IsNullOrEmpty(value.GetString()))
        {
            throw new KeyNotFoundException(name);
        }

        return value.GetString()!;
    }
}

/// <summary>
/// The real <see cref="IFirebaseAccounts"/>: the Identity Toolkit REST API with a service account access token (a JWT signed with the account's key and exchanged at Google's token endpoint,
/// the "two-legged OAuth" flow). NOT EXERCISED against Google: the request and response shapes below are from Google's documented REST reference and must be proved in the test phase
/// (docs/specs/initial-build/lane-identity-notes.md). Every call has a timeout and honours cancellation; the credential, the token and the member's address never reach a log or a message.
/// </summary>
internal sealed class GoogleFirebaseAccounts(IHttpClientFactory httpClients, GoogleServiceAccount account, string expectedProjectId, TimeProvider clock) : IFirebaseAccounts, IDisposable
{
    public const string SettingKey = "TSR_GOOGLE_SERVICE_ACCOUNT_B64";
    public const string ClientName = "google-identity-toolkit";

    private const string TokenEndpoint = "https://oauth2.googleapis.com/token";
    private const string Scope = "https://www.googleapis.com/auth/identitytoolkit";
    private const string Toolkit = "https://identitytoolkit.googleapis.com/v1/projects/";
    private const int MaxResponseBytes = 64 * 1024;

    private readonly SemaphoreSlim _tokenGate = new(1, 1);
    private string? _accessToken;
    private DateTimeOffset _accessTokenExpires;

    public void Dispose() => _tokenGate.Dispose();

    public async Task DeleteAsync(string? uid, string? email, CancellationToken ct)
    {
        if (!string.Equals(account.ProjectId, expectedProjectId, StringComparison.Ordinal))
        {
            throw new FirebaseAccountException("Firebase project mismatch: the service account belongs to another project than TSR_FIREBASE_PROJECT_ID.");
        }

        var target = uid;
        if (string.IsNullOrEmpty(target) && !string.IsNullOrEmpty(email))
        {
            target = await LookUpByEmailAsync(email, ct);
        }

        if (string.IsNullOrEmpty(target))
        {
            return;
        }

        await DeleteByUidAsync(target, ct);
    }

    // UNVERIFIED shape: POST {Toolkit}{project}/accounts:lookup {"email": ["a@b"]} -> {"users": [{"localId": "..."}]}; no match is {} (no "users"), or an error USER_NOT_FOUND.
    private async Task<string?> LookUpByEmailAsync(string email, CancellationToken ct)
    {
        var body = JsonSerializer.Serialize(new { email = new[] { email } });
        var (status, text) = await PostAsync("accounts:lookup", body, ct);
        if (status == HttpStatusCode.OK)
        {
            return FirstLocalId(text);
        }

        if (IsNotFound(text))
        {
            return null;
        }

        throw new FirebaseAccountException("Firebase refused the account lookup (HTTP " + ((int)status).ToString(CultureInfo.InvariantCulture) + ").");
    }

    // UNVERIFIED shape: POST {Toolkit}{project}/accounts:delete {"localId": "uid"} -> {} on success; an error with message USER_NOT_FOUND means already gone (PHP: "not found" is done).
    private async Task DeleteByUidAsync(string uid, CancellationToken ct)
    {
        var body = JsonSerializer.Serialize(new { localId = uid });
        var (status, text) = await PostAsync("accounts:delete", body, ct);
        if (status == HttpStatusCode.OK || IsNotFound(text))
        {
            return;
        }

        throw new FirebaseAccountException("Firebase refused the account deletion (HTTP " + ((int)status).ToString(CultureInfo.InvariantCulture) + ").");
    }

    private async Task<(HttpStatusCode Status, string Body)> PostAsync(string method, string json, CancellationToken ct)
    {
        var token = await AccessTokenAsync(ct);
        using var client = httpClients.CreateClient(ClientName);
        using var request = new HttpRequestMessage(HttpMethod.Post, new Uri(Toolkit + Uri.EscapeDataString(account.ProjectId) + "/" + method))
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json"),
        };
        request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token);
        return await SendAsync(client, request, ct);
    }

    // UNVERIFIED shape: POST https://oauth2.googleapis.com/token, form grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer and assertion=<signed JWT> -> {"access_token": "...", "expires_in": 3599}.
    private async Task<string> AccessTokenAsync(CancellationToken ct)
    {
        await _tokenGate.WaitAsync(ct);
        try
        {
            var now = clock.GetUtcNow();
            if (_accessToken is not null && now < _accessTokenExpires)
            {
                return _accessToken;
            }

            using var client = httpClients.CreateClient(ClientName);
            using var request = new HttpRequestMessage(HttpMethod.Post, new Uri(TokenEndpoint))
            {
                Content = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    ["assertion"] = SignedAssertion(now),
                }),
            };
            var (status, text) = await SendAsync(client, request, ct);
            if (status != HttpStatusCode.OK)
            {
                throw new FirebaseAccountException("Google refused the service account sign-in (HTTP " + ((int)status).ToString(CultureInfo.InvariantCulture) + ").");
            }

            (_accessToken, _accessTokenExpires) = ReadAccessToken(text, now);
            return _accessToken;
        }
        finally
        {
            _tokenGate.Release();
        }
    }

    private static (string Token, DateTimeOffset Expires) ReadAccessToken(string text, DateTimeOffset now)
    {
        try
        {
            using var document = JsonDocument.Parse(text);
            var root = document.RootElement;
            var token = root.GetProperty("access_token").GetString();
            var seconds = root.TryGetProperty("expires_in", out var expires) && expires.TryGetInt32(out var value) ? value : 300;
            if (string.IsNullOrEmpty(token))
            {
                throw new FirebaseAccountException("Google answered the service account sign-in without an access token.");
            }

            return (token, now.AddSeconds(Math.Max(seconds - 60, 0)));
        }
        catch (Exception e) when (e is JsonException or KeyNotFoundException or InvalidOperationException)
        {
            throw new FirebaseAccountException("Google answered the service account sign-in in an unreadable form.");
        }
    }

    private string SignedAssertion(DateTimeOffset now)
    {
        var issued = now.ToUnixTimeSeconds();
        var header = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new { alg = "RS256", typ = "JWT" }));
        var claims = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new { iss = account.ClientEmail, scope = Scope, aud = TokenEndpoint, iat = issued, exp = issued + 3600 }));
        var signingInput = header + "." + claims;
        using var rsa = RSA.Create();
        try
        {
            rsa.ImportFromPem(account.PrivateKey);
        }
        catch (Exception e) when (e is ArgumentException or CryptographicException)
        {
            throw new FirebaseAccountException("The service account private key could not be read.");
        }

        var signature = rsa.SignData(Encoding.ASCII.GetBytes(signingInput), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return signingInput + "." + Base64Url(signature);
    }

    private static async Task<(HttpStatusCode Status, string Body)> SendAsync(HttpClient client, HttpRequestMessage request, CancellationToken ct)
    {
        try
        {
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, ct);
            await using var stream = await response.Content.ReadAsStreamAsync(ct);
            var buffer = new byte[MaxResponseBytes];
            var read = 0;
            int count;
            while (read < buffer.Length && (count = await stream.ReadAsync(buffer.AsMemory(read), ct)) > 0)
            {
                read += count;
            }

            return (response.StatusCode, Encoding.UTF8.GetString(buffer, 0, read));
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            throw new FirebaseAccountException("Firebase could not be reached (" + e.GetType().Name + ").");
        }
    }

    private static string? FirstLocalId(string text)
    {
        try
        {
            using var document = JsonDocument.Parse(text);
            if (!document.RootElement.TryGetProperty("users", out var users) || users.ValueKind != JsonValueKind.Array || users.GetArrayLength() == 0)
            {
                return null;
            }

            return users[0].TryGetProperty("localId", out var id) && id.ValueKind == JsonValueKind.String ? id.GetString() : null;
        }
        catch (JsonException)
        {
            throw new FirebaseAccountException("Firebase answered the account lookup in an unreadable form.");
        }
    }

    private static bool IsNotFound(string text) =>
        text.Contains("USER_NOT_FOUND", StringComparison.Ordinal) || text.Contains("EMAIL_NOT_FOUND", StringComparison.Ordinal);

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
