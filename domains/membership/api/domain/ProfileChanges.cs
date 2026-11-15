using Tsr.Shared.Api;
using System.Text.Json;

namespace Tsr.Membership.Api.Domain;

/// <summary>
/// The fields a PATCH /me body names, among the nine PHP lets through, in PHP's validation order. Presence is array_key_exists, so an
/// explicit null counts. A field outside the nine is ignored.
/// </summary>
internal sealed class ProfileChanges
{
    private readonly List<KeyValuePair<string, JsonElement>> _sent;

    private ProfileChanges(List<KeyValuePair<string, JsonElement>> sent) => _sent = sent;

    public bool IsEmpty => _sent.Count == 0;

    public static ProfileChanges From(JsonBody body)
    {
        ArgumentNullException.ThrowIfNull(body);
        var sent = ProfileFields.Updatable.Where(body.Has).Select(f => new KeyValuePair<string, JsonElement>(f, body.Get(f))).ToList();
        return new ProfileChanges(sent);
    }

    /// <summary>The first validation error in PHP's order, or null.</summary>
    public string? FirstError() => _sent.Select(e => ProfileFields.Validate(e.Key, e.Value)).FirstOrDefault(error => error is not null);

    public bool Has(string field) => _sent.Any(e => e.Key == field);

    /// <summary>PHP's <c>isset($updates[$field])</c>: sent and not null.</summary>
    public bool IsSet(string field) => _sent.Any(e => e.Key == field && e.Value.ValueKind != JsonValueKind.Null);

    public JsonElement Value(string field) => _sent.First(e => e.Key == field).Value;

    /// <summary>The field's string cast for the place rules (PHP's <c>strval</c>: null is empty), or <paramref name="fallback"/> when it was not sent.</summary>
    public string TextOr(string field, string fallback) => Has(field) ? PhpValue.Text(Value(field)) : fallback;
}
