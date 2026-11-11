using System.Text.RegularExpressions;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// The gateway (hosts/gateway/default.conf) sends every path of the catalog to the new API and keeps a fallback for the rest.
/// A path no location matches would fall to the fallback and answer 404 although the API routes it.
/// </summary>
public sealed partial class GatewayTests
{
    private static readonly IReadOnlyList<CatalogRoute> Catalog = RouteCatalog.Load();

    [GeneratedRegex(@"^\s*location\s+(=|\^~|~)?\s*(\S+)\s*\{\s*proxy_pass\s+http://new_api;", RegexOptions.Multiline)]
    private static partial Regex ProxyLocation();

    [Test]
    public void Every_catalog_path_reaches_the_new_api()
    {
        var locations = ProxyLocation().Matches(File.ReadAllText(ConfigPath()))
            .Select(m => (Kind: m.Groups[1].Value, Pattern: m.Groups[2].Value))
            .ToList();

        var unrouted = Catalog.Select(r => r.Concrete).Distinct().Where(path => !locations.Any(l => Matches(l.Kind, l.Pattern, path))).ToList();

        Assert.That(unrouted, Is.Empty);
    }

    [Test]
    public void Unknown_paths_keep_a_fallback_location()
    {
        Assert.That(File.ReadAllText(ConfigPath()), Does.Match(@"location\s+/\s*\{"));
    }

    private static bool Matches(string kind, string pattern, string path) => kind switch
    {
        "=" => path == pattern,
        "^~" => path.StartsWith(pattern, StringComparison.Ordinal),
        "~" => Regex.IsMatch(path, pattern),
        _ => path.StartsWith(pattern, StringComparison.Ordinal),
    };

    private static string ConfigPath() => Path.Combine(RouteCatalog.RepoRoot(), "hosts", "gateway", "default.conf");
}
