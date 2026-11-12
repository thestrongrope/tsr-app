using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Tsr.Notifications.Api.Domain;

/// <summary>
/// FCM HTTP v1 called directly (docs/specs/dotnet-stack.md, "Push"): <c>POST https://fcm.googleapis.com/v1/projects/{project}/messages:send</c> with a Bearer access token
/// from the service account (setting <c>TSR_GOOGLE_SERVICE_ACCOUNT_B64</c>, base64 of the service-account JSON). The token is a signed JWT (RS256) exchanged at Google's fixed token
/// endpoint (the file's own <c>token_uri</c> is ignored on purpose) and cached until five minutes before it expires. A singleton, so the cache is shared.
/// Never logs the credential, an access token or a device token. NOT exercised against Google yet: the request and response shapes are from Google's documentation (lane-notify-core-notes.md).
/// </summary>
internal sealed partial class FcmPushSender : IPushSender, IDisposable
{
    public const string HttpClientName = "fcm";
    public const string SettingName = "TSR_GOOGLE_SERVICE_ACCOUNT_B64";

    private const string TokenEndpoint = "https://oauth2.googleapis.com/token";
    private const string Scope = "https://www.googleapis.com/auth/firebase.messaging";
    private const int MaxResponseChars = 8192;

    private readonly IHttpClientFactory _clients;
    private readonly ILogger<FcmPushSender> _log;
    private readonly TimeProvider _clock;
    private readonly string? _project;
    private readonly string? _clientEmail;
    private readonly RSA? _key;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private string? _accessToken;
    private DateTimeOffset _accessExpires = DateTimeOffset.MinValue;

    public FcmPushSender(IConfiguration configuration, IHttpClientFactory clients, ILogger<FcmPushSender> log, TimeProvider clock)
    {
        ArgumentNullException.ThrowIfNull(configuration);
        _clients = clients;
        _log = log;
        _clock = clock;
        var setting = configuration[SettingName];
        if (string.IsNullOrWhiteSpace(setting))
        {
            return;
        }

        try
        {
            using var document = JsonDocument.Parse(Convert.FromBase64String(setting.Trim()));
            _project = document.RootElement.GetProperty("project_id").GetString();
            _clientEmail = document.RootElement.GetProperty("client_email").GetString();
            var pem = document.RootElement.GetProperty("private_key").GetString();
            _key = RSA.Create();
            _key.ImportFromPem(pem);
        }
        catch (Exception e) when (e is FormatException or JsonException or KeyNotFoundException or ArgumentException or CryptographicException or InvalidOperationException)
        {
            _key?.Dispose();
            _key = null;
            _project = null;
            LogUnusableSetting(_log, SettingName);
        }
    }

    public bool IsConfigured => _key is not null && !string.IsNullOrEmpty(_project) && !string.IsNullOrEmpty(_clientEmail);

    public async Task<PushResult> SendAsync(PushMessage message, string deviceToken, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(message);
        if (!IsConfigured)
        {
            return PushResult.Failed;
        }

        var access = await AccessTokenAsync(ct);
        if (access is null)
        {
            return PushResult.Failed;
        }

        using var request = new HttpRequestMessage(HttpMethod.Post, $"https://fcm.googleapis.com/v1/projects/{Uri.EscapeDataString(_project!)}/messages:send")
        {
            Content = new StringContent(BuildBody(message, deviceToken), Encoding.UTF8, "application/json"),
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", access);
        try
        {
            using var response = await _clients.CreateClient(HttpClientName).SendAsync(request, ct);
            if (response.IsSuccessStatusCode)
            {
                return PushResult.Sent;
            }

            return await ClassifyAsync(response, ct);
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            LogRequestFailed(_log, e.GetType().Name);
            return PushResult.Failed;
        }
    }

    internal static string BuildBody(PushMessage message, string deviceToken)
    {
        var payload = new Dictionary<string, object>
        {
            ["message"] = new Dictionary<string, object>
            {
                ["token"] = deviceToken,
                ["notification"] = new Dictionary<string, string> { ["title"] = message.Title, ["body"] = message.Body },
                ["data"] = message.Data,
                ["android"] = new Dictionary<string, object>
                {
                    ["priority"] = "HIGH",
                    ["notification"] = new Dictionary<string, string> { ["sound"] = "default", ["channel_id"] = "high_importance_channel" },
                },
                ["apns"] = new Dictionary<string, object>
                {
                    ["payload"] = new Dictionary<string, object>
                    {
                        ["aps"] = new Dictionary<string, object> { ["sound"] = "default", ["badge"] = 1 },
                    },
                },
            },
        };
        return JsonSerializer.Serialize(payload);
    }

    // UNREGISTERED (404) is a dead token. INVALID_ARGUMENT (400) is a dead token only when its message names the registration token: it can also mean a bad payload, and one
    // payload mistake must never make the cleanup delete every device. Everything else (401, 403 sender mismatch, 429, 5xx) is a failure that leaves the token alone.
    internal static PushResult Classify(HttpStatusCode status, string body)
    {
        var detail = ReadError(body);
        if (detail.ErrorCode == "UNREGISTERED" || detail.Status == "NOT_FOUND")
        {
            return PushResult.TokenInvalid;
        }

        var namesToken = detail.Message.Contains("registration token", StringComparison.OrdinalIgnoreCase);
        if ((detail.ErrorCode == "INVALID_ARGUMENT" || detail.Status == "INVALID_ARGUMENT" || status == HttpStatusCode.BadRequest) && namesToken)
        {
            return PushResult.TokenInvalid;
        }

        return PushResult.Failed;
    }

    private async Task<PushResult> ClassifyAsync(HttpResponseMessage response, CancellationToken ct)
    {
        var text = await ReadLimitedAsync(response, ct);
        if (response.StatusCode == HttpStatusCode.Unauthorized)
        {
            await ForgetAccessTokenAsync(ct);
        }

        var result = Classify(response.StatusCode, text);
        if (result == PushResult.Failed)
        {
            LogRefused(_log, (int)response.StatusCode);
        }

        return result;
    }

    private sealed record ErrorDetail(string Status, string Message, string ErrorCode);

    private static ErrorDetail ReadError(string body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            if (!document.RootElement.TryGetProperty("error", out var error) || error.ValueKind != JsonValueKind.Object)
            {
                return new ErrorDetail(string.Empty, string.Empty, string.Empty);
            }

            var code = string.Empty;
            if (error.TryGetProperty("details", out var details) && details.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in details.EnumerateArray())
                {
                    if (item.ValueKind == JsonValueKind.Object && item.TryGetProperty("errorCode", out var errorCode) && errorCode.ValueKind == JsonValueKind.String)
                    {
                        code = errorCode.GetString() ?? string.Empty;
                    }
                }
            }

            return new ErrorDetail(Text(error, "status"), Text(error, "message"), code);
        }
        catch (JsonException)
        {
            return new ErrorDetail(string.Empty, string.Empty, string.Empty);
        }
    }

    private static string Text(JsonElement parent, string name) =>
        parent.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : string.Empty;

    private static async Task<string> ReadLimitedAsync(HttpResponseMessage response, CancellationToken ct)
    {
        using var reader = new StreamReader(await response.Content.ReadAsStreamAsync(ct));
        var buffer = new char[MaxResponseChars];
        var read = await reader.ReadBlockAsync(buffer.AsMemory(), ct);
        return new string(buffer, 0, read);
    }

    private async Task ForgetAccessTokenAsync(CancellationToken ct)
    {
        await _gate.WaitAsync(ct);
        try
        {
            _accessToken = null;
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task<string?> AccessTokenAsync(CancellationToken ct)
    {
        await _gate.WaitAsync(ct);
        try
        {
            var now = _clock.GetUtcNow();
            if (_accessToken is not null && now < _accessExpires)
            {
                return _accessToken;
            }

            return await ExchangeAsync(now, ct);
        }
        finally
        {
            _gate.Release();
        }
    }

    private async Task<string?> ExchangeAsync(DateTimeOffset now, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, TokenEndpoint)
        {
            Content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                ["assertion"] = SignedAssertion(now),
            }),
        };
        try
        {
            using var response = await _clients.CreateClient(HttpClientName).SendAsync(request, ct);
            var text = await ReadLimitedAsync(response, ct);
            if (!response.IsSuccessStatusCode)
            {
                LogTokenRefused(_log, (int)response.StatusCode);
                return null;
            }

            using var document = JsonDocument.Parse(text);
            _accessToken = document.RootElement.GetProperty("access_token").GetString();
            var seconds = document.RootElement.TryGetProperty("expires_in", out var expires) && expires.TryGetInt32(out var value) ? value : 3600;
            _accessExpires = now.AddSeconds(Math.Max(60, seconds - 300));
            return _accessToken;
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or JsonException or KeyNotFoundException && !ct.IsCancellationRequested)
        {
            LogTokenFailed(_log, e.GetType().Name);
            return null;
        }
    }

    private string SignedAssertion(DateTimeOffset now)
    {
        var issued = now.ToUnixTimeSeconds();
        var header = Base64Url(Encoding.UTF8.GetBytes("""{"alg":"RS256","typ":"JWT"}"""));
        var claims = JsonSerializer.Serialize(new Dictionary<string, object>
        {
            ["iss"] = _clientEmail!,
            ["scope"] = Scope,
            ["aud"] = TokenEndpoint,
            ["iat"] = issued,
            ["exp"] = issued + 3600,
        });
        var unsigned = header + "." + Base64Url(Encoding.UTF8.GetBytes(claims));
        var signature = _key!.SignData(Encoding.ASCII.GetBytes(unsigned), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return unsigned + "." + Base64Url(signature);
    }

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    public void Dispose()
    {
        _key?.Dispose();
        _gate.Dispose();
    }

    [LoggerMessage(Level = LogLevel.Error, Message = "{Setting} is set but is not a usable service account")]
    private static partial void LogUnusableSetting(ILogger logger, string setting);

    [LoggerMessage(Level = LogLevel.Warning, Message = "An FCM request failed: {Kind}")]
    private static partial void LogRequestFailed(ILogger logger, string kind);

    [LoggerMessage(Level = LogLevel.Warning, Message = "FCM refused a push with status {Status}")]
    private static partial void LogRefused(ILogger logger, int status);

    [LoggerMessage(Level = LogLevel.Error, Message = "Google refused the FCM access token request with status {Status}")]
    private static partial void LogTokenRefused(ILogger logger, int status);

    [LoggerMessage(Level = LogLevel.Error, Message = "The FCM access token request failed: {Kind}")]
    private static partial void LogTokenFailed(ILogger logger, string kind);
}
