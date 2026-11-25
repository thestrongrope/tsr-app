using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace Tsr.Assessment.Api.Domain;

/// <summary>The one optional setting: <c>TSR_GOOGLE_SERVICE_ACCOUNT_B64</c>, a service account's JSON key in base64 (as PHP's <c>FIREBASE_SERVICE_ACCOUNT_B64</c>). Absent: the API starts and every sheet call fails.</summary>
internal sealed class GoogleSheetsSettings
{
    public const string Key = "TSR_GOOGLE_SERVICE_ACCOUNT_B64";

    public string? ServiceAccountB64 { get; set; }

    /// <summary>Optional <c>TSR_QUIZ_SETTINGS_SHEET_ID</c> (PHP <c>QUIZ_SETTINGS_GOOGLE_SHEET_ID</c>): the spreadsheet the quiz settings are read from. Absent: a settings refresh answers 502.</summary>
    public const string QuizSettingsSheetKey = "TSR_QUIZ_SETTINGS_SHEET_ID";

    public string? QuizSettingsSheetId { get; set; }
}

/// <summary>
/// The real <see cref="ISheets"/>: the Google Sheets REST API over HTTP, no SDK. A service-account JWT (RS256, signed with the built-in RSA) is exchanged at the key's token endpoint
/// for an access token that is cached for its lifetime less a minute. The credential and the tokens are never logged or put in a message. Every call is bounded by the HttpClient's timeout.
/// Not exercised against Google in the build-out phase: lane-sheets-notes.md lists which shapes are unverified.
/// </summary>
internal sealed class GoogleSheets(HttpClient http, IOptions<GoogleSheetsSettings> settings, TimeProvider clock) : ISheets, IDisposable
{
    private const string Scope = "https://www.googleapis.com/auth/spreadsheets";
    private const string DefaultTokenUri = "https://oauth2.googleapis.com/token";
    private const string ApiBase = "https://sheets.googleapis.com/v4/spreadsheets/";
    private const int MaxRows = 50_000;

    private readonly SemaphoreSlim _tokenLock = new(1, 1);
    private string? _token;
    private DateTimeOffset _tokenExpires;

    public async Task<IReadOnlyList<IReadOnlyList<string>>> ReadAsync(string spreadsheetId, string range, CancellationToken ct)
    {
        var uri = new Uri(ApiBase + Uri.EscapeDataString(spreadsheetId) + "/values/" + Uri.EscapeDataString(range));
        using var request = new HttpRequestMessage(HttpMethod.Get, uri);
        using var response = await SendAsync(request, ct);
        var bytes = await response.Content.ReadAsByteArrayAsync(ct);
        return ParseValues(bytes);
    }

    public async Task WriteAsync(string spreadsheetId, string range, IReadOnlyList<IReadOnlyList<object?>> rows, CancellationToken ct)
    {
        var uri = new Uri(ApiBase + Uri.EscapeDataString(spreadsheetId) + "/values/" + Uri.EscapeDataString(range) + "?valueInputOption=RAW");
        using var request = new HttpRequestMessage(HttpMethod.Put, uri)
        {
            Content = ValuesBody(range, rows),
        };
        using var response = await SendAsync(request, ct);
    }

    public void Dispose() => _tokenLock.Dispose();

    /// <summary>The values.update body <c>{"range":...,"majorDimension":"ROWS","values":[[...]]}</c>, written by hand: a cell is text, a number, a flag or null (an empty cell).</summary>
    private static ByteArrayContent ValuesBody(string range, IReadOnlyList<IReadOnlyList<object?>> rows)
    {
        using var buffer = new MemoryStream();
        using (var writer = new Utf8JsonWriter(buffer))
        {
            writer.WriteStartObject();
            writer.WriteString("range", range);
            writer.WriteString("majorDimension", "ROWS");
            writer.WriteStartArray("values");
            foreach (var row in rows)
            {
                writer.WriteStartArray();
                foreach (var cell in row)
                {
                    WriteCell(writer, cell);
                }

                writer.WriteEndArray();
            }

            writer.WriteEndArray();
            writer.WriteEndObject();
        }

        var content = new ByteArrayContent(buffer.ToArray());
        content.Headers.ContentType = new MediaTypeHeaderValue("application/json") { CharSet = "utf-8" };
        return content;
    }

    private static void WriteCell(Utf8JsonWriter writer, object? cell)
    {
        switch (cell)
        {
            case null:
                writer.WriteNullValue();
                break;
            case string text:
                writer.WriteStringValue(text);
                break;
            case long number:
                writer.WriteNumberValue(number);
                break;
            case int number:
                writer.WriteNumberValue(number);
                break;
            case bool flag:
                writer.WriteBooleanValue(flag);
                break;
            default:
                throw new ArgumentException("A sheet cell is text, a whole number, a flag or null.", nameof(cell));
        }
    }

    /// <summary>The response of values.get: <c>{"range":..., "majorDimension":"ROWS", "values":[["a","b"],...]}</c>; <c>values</c> is absent for an empty range. A cell that is not text is read as its raw text.</summary>
    internal static IReadOnlyList<IReadOnlyList<string>> ParseValues(byte[] body)
    {
        try
        {
            using var document = JsonDocument.Parse(body);
            if (document.RootElement.ValueKind != JsonValueKind.Object || !document.RootElement.TryGetProperty("values", out var values))
            {
                return [];
            }

            if (values.ValueKind != JsonValueKind.Array || values.GetArrayLength() > MaxRows)
            {
                throw new SheetsException("Google Sheets answered with an unusable range");
            }

            return values.EnumerateArray().Select(Row).ToList();
        }
        catch (JsonException e)
        {
            throw new SheetsException("Google Sheets answered something that is not JSON", e);
        }
    }

    private static List<string> Row(JsonElement row) =>
        row.ValueKind != JsonValueKind.Array
            ? []
            : row.EnumerateArray().Select(cell => cell.ValueKind == JsonValueKind.String ? cell.GetString() ?? string.Empty : cell.GetRawText()).ToList();

    private async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
    {
        var token = await AccessTokenAsync(ct);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        try
        {
            var response = await http.SendAsync(request, ct);
            if (response.IsSuccessStatusCode)
            {
                return response;
            }

            var status = (int)response.StatusCode;
            response.Dispose();
            throw new SheetsException("Google Sheets answered " + status);
        }
        catch (HttpRequestException e)
        {
            throw new SheetsException("Google Sheets is unreachable", e);
        }
        catch (TaskCanceledException e) when (!ct.IsCancellationRequested)
        {
            throw new SheetsException("Google Sheets did not answer in time", e);
        }
    }

    private async Task<string> AccessTokenAsync(CancellationToken ct)
    {
        await _tokenLock.WaitAsync(ct);
        try
        {
            if (_token is not null && clock.GetUtcNow() < _tokenExpires)
            {
                return _token;
            }

            var account = ServiceAccount.Parse(settings.Value.ServiceAccountB64);
            var issued = clock.GetUtcNow();
            using var form = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                ["assertion"] = account.SignedJwt(issued),
            });
            var (token, lifetime) = await ExchangeAsync(account.TokenUri, form, ct);
            _token = token;
            _tokenExpires = issued.AddSeconds(Math.Max(0, lifetime - 60));
            return token;
        }
        finally
        {
            _tokenLock.Release();
        }
    }

    private async Task<(string Token, int Lifetime)> ExchangeAsync(Uri tokenUri, HttpContent form, CancellationToken ct)
    {
        try
        {
            using var response = await http.PostAsync(tokenUri, form, ct);
            if (!response.IsSuccessStatusCode)
            {
                throw new SheetsException("Google token endpoint answered " + (int)response.StatusCode);
            }

            using var document = JsonDocument.Parse(await response.Content.ReadAsByteArrayAsync(ct));
            var root = document.RootElement;
            var token = root.ValueKind == JsonValueKind.Object && root.TryGetProperty("access_token", out var t) ? t.GetString() : null;
            if (string.IsNullOrEmpty(token))
            {
                throw new SheetsException("Google token endpoint answered without a token");
            }

            var lifetime = root.TryGetProperty("expires_in", out var e) && e.TryGetInt32(out var seconds) ? seconds : 3600;
            return (token, lifetime);
        }
        catch (HttpRequestException e)
        {
            throw new SheetsException("Google token endpoint is unreachable", e);
        }
        catch (TaskCanceledException e) when (!ct.IsCancellationRequested)
        {
            throw new SheetsException("Google token endpoint did not answer in time", e);
        }
        catch (JsonException e)
        {
            throw new SheetsException("Google token endpoint answered something that is not JSON", e);
        }
    }

    /// <summary>The parts of a service-account key file this client uses.</summary>
    private sealed record ServiceAccount(string ClientEmail, string PrivateKeyPem, Uri TokenUri)
    {
        public static ServiceAccount Parse(string? base64)
        {
            if (string.IsNullOrWhiteSpace(base64))
            {
                throw new SheetsException("Google Sheets: " + GoogleSheetsSettings.Key + " is not configured");
            }

            try
            {
                using var document = JsonDocument.Parse(Convert.FromBase64String(base64));
                var root = document.RootElement;
                var email = root.GetProperty("client_email").GetString();
                var key = root.GetProperty("private_key").GetString();
                var uri = root.TryGetProperty("token_uri", out var u) ? u.GetString() : null;
                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(key))
                {
                    throw new SheetsException("Google Sheets: the service account key has no client_email or private_key");
                }

                return new ServiceAccount(email, key, new Uri(string.IsNullOrEmpty(uri) ? DefaultTokenUri : uri));
            }
            catch (Exception e) when (e is FormatException or JsonException or KeyNotFoundException or InvalidOperationException or UriFormatException)
            {
                throw new SheetsException("Google Sheets: " + GoogleSheetsSettings.Key + " is not a service account key", e);
            }
        }

        /// <summary>The RS256 JWT the token endpoint exchanges: iss the account, scope, aud the token endpoint, iat now, exp an hour later.</summary>
        public string SignedJwt(DateTimeOffset now)
        {
            var header = Base64Url(Encoding.UTF8.GetBytes("""{"alg":"RS256","typ":"JWT"}"""));
            var claims = Base64Url(ClaimsJson(now));
            var unsigned = header + "." + claims;
            using var rsa = RSA.Create();
            try
            {
                rsa.ImportFromPem(PrivateKeyPem);
            }
            catch (Exception e) when (e is ArgumentException or CryptographicException)
            {
                throw new SheetsException("Google Sheets: the service account private key cannot be read", e);
            }

            var signature = rsa.SignData(Encoding.ASCII.GetBytes(unsigned), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
            return unsigned + "." + Base64Url(signature);
        }

        private byte[] ClaimsJson(DateTimeOffset now)
        {
            using var buffer = new MemoryStream();
            using (var writer = new Utf8JsonWriter(buffer))
            {
                writer.WriteStartObject();
                writer.WriteString("iss", ClientEmail);
                writer.WriteString("scope", Scope);
                writer.WriteString("aud", TokenUri.ToString());
                writer.WriteNumber("iat", now.ToUnixTimeSeconds());
                writer.WriteNumber("exp", now.AddHours(1).ToUnixTimeSeconds());
                writer.WriteEndObject();
            }

            return buffer.ToArray();
        }

        private static string Base64Url(byte[] bytes) => Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }
}
