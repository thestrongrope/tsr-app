using System.Text.Json;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP's <c>api_manage_timezones</c>: the static timezone list of <c>ClassesModel::getTimezones()</c> (data/timezones.json, embedded, PHP's 143 pairs in order), the first label kept
/// for each zone, HTML entities in the label decoded. Wire: <c>{timezone, label}</c>.
/// </summary>
internal static class Timezones
{
    private static readonly JsonSerializerOptions Options = new() { PropertyNameCaseInsensitive = true };
    private static readonly Lazy<List<Dictionary<string, object?>>> List = new(Load);

    public static IReadOnlyList<Dictionary<string, object?>> All => List.Value;

    private sealed record Pair(string Timezone, string Label);

    private static List<Dictionary<string, object?>> Load()
    {
        using var stream = typeof(Timezones).Assembly.GetManifestResourceStream("timezones.json")
            ?? throw new InvalidOperationException("The embedded timezones.json is missing");
        var pairs = JsonSerializer.Deserialize<List<Pair>>(stream, Options)
            ?? throw new InvalidOperationException("timezones.json is empty");
        return pairs
            .GroupBy(p => p.Timezone)
            .Select(g => new Dictionary<string, object?> { ["timezone"] = g.Key, ["label"] = PhpText.HtmlDecode(g.First().Label) })
            .ToList();
    }
}
