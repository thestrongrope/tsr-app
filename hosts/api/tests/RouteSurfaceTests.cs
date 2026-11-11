using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// The API's whole route surface against the catalog (docs/specs/initial-build/operations.csv): every operation of PHP's router is
/// routed, a built one by its slice and a planned one by a placeholder that signs the caller in and answers 501. Signed-in
/// answers of the placeholders need the database: db/tests/PlannedRoutesTests.cs.
/// </summary>
public sealed class RouteSurfaceTests
{
    private static readonly IReadOnlyList<CatalogRoute> Catalog = RouteCatalog.Load();

    private static readonly string[] States = ["built", "planned"];
    private static readonly string[] AuthKinds = ["public", "member", "create"];

    private ApiHost api = null!;

    public static IEnumerable<TestCaseData> PlannedRoutes() =>
        Catalog.Where(r => !r.IsBuilt).Select(r => new TestCaseData(r.Method, r.Concrete, r.Auth == "public").SetName(r.Method + " " + r.Path));

    [OneTimeSetUp]
    public void StartApi() => api = new ApiHost();

    [OneTimeTearDown]
    public void StopApi() => api.Dispose();

    [Test]
    public void The_catalog_lists_each_operation_once_in_a_known_state()
    {
        var duplicates = Catalog.GroupBy(r => r.Key).Where(g => g.Count() > 1).Select(g => g.Key).ToList();

        Assert.That(duplicates, Is.Empty);
        Assert.That(Catalog.Select(r => r.State).Distinct(), Is.SubsetOf(States));
        Assert.That(Catalog.Select(r => r.Auth).Distinct(), Is.SubsetOf(AuthKinds));
        Assert.That(Catalog.Select(r => r.Domain).Distinct().Order(), Is.EqualTo(Modules.All.Select(m => m.Name).Order()));
    }

    [Test]
    public void The_route_table_is_the_catalog_and_nothing_else_but_the_listed_extras()
    {
        var mapped = MappedRoutes().Select(r => r.Key).ToList();

        Assert.That(mapped.Distinct().Count(), Is.EqualTo(mapped.Count), "a method and path is mapped twice");
        Assert.That(Catalog.Select(r => r.Key).Except(mapped), Is.Empty, "in the catalog, not routed");
        Assert.That(mapped.Except(Catalog.Select(r => r.Key)).Order(), Is.EqualTo(RouteCatalog.NotInPhp.Order()), "routed, not in the catalog");
    }

    [Test]
    public void Built_routes_are_not_placeholders_and_planned_routes_are()
    {
        var mapped = MappedRoutes().ToDictionary(r => r.Key);
        var wrong = Catalog
            .Where(r => mapped[r.Key].Endpoint.Metadata.GetMetadata<PlannedRoute>() is not null == r.IsBuilt)
            .Select(r => r.Key + " is " + r.State + " in the catalog")
            .ToList();

        Assert.That(wrong, Is.Empty);
    }

    [Test]
    public void Every_route_asks_for_the_sign_in_the_catalog_names()
    {
        var mapped = MappedRoutes().ToDictionary(r => r.Key);
        var wrong = Catalog.Where(r => ExpectedSignIn(r) != ActualSignIn(mapped[r.Key].Endpoint)).Select(r => r.Key).ToList();

        Assert.That(wrong, Is.Empty);
    }

    [TestCaseSource(nameof(PlannedRoutes))]
    public async Task A_planned_route_answers_501_when_public_and_401_without_a_token_otherwise(string method, string path, bool isPublic)
    {
        var (status, body) = await api.SendAsync(method, path);

        Assert.That((status, body), isPublic
            ? Is.EqualTo((StatusCodes.Status501NotImplemented, """{"detail":"Not implemented"}"""))
            : Is.EqualTo((StatusCodes.Status401Unauthorized, """{"detail":"Not authenticated"}""")));
    }

    [Test]
    public async Task An_unknown_path_is_404_not_found_in_the_detail_envelope()
    {
        var (status, body) = await api.SendAsync("GET", "/no/such/path");

        Assert.That((status, body), Is.EqualTo((StatusCodes.Status404NotFound, """{"detail":"Not Found"}""")));
    }

    [TestCase("POST", "/health")]
    [TestCase("PUT", "/search")]
    [TestCase("DELETE", "/me/children/links")]
    public async Task A_known_path_with_another_verb_is_405_method_not_allowed_even_without_a_token(string method, string path)
    {
        var (status, body) = await api.SendAsync(method, path);

        Assert.That((status, body), Is.EqualTo((StatusCodes.Status405MethodNotAllowed, """{"detail":"Method Not Allowed"}""")));
    }

    [Test]
    public async Task Overlapping_routes_resolve_as_PHP_does_the_literal_first_one()
    {
        var overlaps = OverlappingPairs().ToList();
        Assert.That(overlaps, Has.Count.GreaterThanOrEqualTo(8), "PHP's router has 8 overlapping pairs today");

        var wrong = new List<string>();
        foreach (var (winner, loser, path) in overlaps)
        {
            await api.SendAsync(winner.Method, path);
            var resolved = api.ResolvedPattern(winner.Method, path);
            if (resolved is null || RouteCatalog.Shape(resolved) != winner.Shape)
            {
                wrong.Add(winner.Method + " " + path + " went to " + resolved + ", not " + winner.Path + " (over " + loser.Path + ")");
            }
        }

        Assert.That(wrong, Is.Empty);
    }

    private IEnumerable<(string Key, RouteEndpoint Endpoint)> MappedRoutes() =>
        api.Endpoints.SelectMany(e => (e.Metadata.GetMetadata<HttpMethodMetadata>()?.HttpMethods ?? [])
            .Select(m => (m + " " + RouteCatalog.Shape(e.RoutePattern.RawText ?? string.Empty), e)));

    private static string ExpectedSignIn(CatalogRoute route) => route is { IsBuilt: true, Auth: "create" } ? "create"
        : route.Auth == "public" ? "public"
        : "member";

    private static string ActualSignIn(RouteEndpoint endpoint) => endpoint.Metadata.GetMetadata<MemberRoute>() switch
    {
        null => "public",
        { CreatesMember: true } => "create",
        _ => "member",
    };

    /// <summary>
    /// Pairs of same-verb routes some path matches both of. PHP takes the one listed first, and in every pair today that is the one with
    /// a literal where the other has a parameter, at the first place they differ; ASP.NET prefers literals in the same way.
    /// </summary>
    private static IEnumerable<(CatalogRoute Winner, CatalogRoute Loser, string Path)> OverlappingPairs()
    {
        foreach (var a in Catalog)
        {
            foreach (var b in Catalog.Where(b => a.Method == b.Method && a != b))
            {
                var path = OverlapPath(a.Path, b.Path);
                if (path is not null && FirstLiteralWins(a.Path, b.Path))
                {
                    yield return (a, b, path);
                }
            }
        }
    }

    private static string? OverlapPath(string a, string b)
    {
        var left = a.Split('/');
        var right = b.Split('/');
        if (left.Length != right.Length)
        {
            return null;
        }

        var parts = new List<string>();
        for (var i = 0; i < left.Length; i++)
        {
            var leftIsParam = left[i].StartsWith('{');
            var rightIsParam = right[i].StartsWith('{');
            if (!leftIsParam && !rightIsParam && left[i] != right[i])
            {
                return null;
            }

            parts.Add(leftIsParam ? (rightIsParam ? "x1" : right[i]) : left[i]);
        }

        return string.Join('/', parts);
    }

    private static bool FirstLiteralWins(string a, string b)
    {
        var left = a.Split('/');
        var right = b.Split('/');
        for (var i = 0; i < left.Length; i++)
        {
            var leftIsParam = left[i].StartsWith('{');
            if (leftIsParam != right[i].StartsWith('{'))
            {
                return !leftIsParam;
            }
        }

        return false;
    }
}
