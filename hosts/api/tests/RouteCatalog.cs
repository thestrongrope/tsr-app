namespace Tsr.Host.Api.Tests;

/// <summary>One line of docs/specs/initial-build/operations.csv: the route catalog every test here compares the running API with.</summary>
internal sealed record CatalogRoute(string Method, string Path, string Domain, string Auth, string State)
{
    public bool IsBuilt => State == "built";

    /// <summary>The path with every parameter name replaced by <c>{}</c>, so PHP's names and C# names compare equal.</summary>
    public string Shape => RouteCatalog.Shape(Path);

    public string Key => Method + " " + Shape;

    /// <summary>A concrete request path: each parameter becomes one segment (PHP's "any non-slash segment").</summary>
    public string Concrete => RouteCatalog.Concrete(Path);
}

internal static class RouteCatalog
{
    /// <summary>Routes that exist in the new API and are not in PHP's router. Listed here so an extra route cannot slip in unseen.</summary>
    public static readonly IReadOnlySet<string> NotInPhp = new HashSet<string>
    {
        "GET /articles",
        "GET /api/v1/articles",
        "GET /api/v1/articles/{}",
        "GET /api/v1/taxonomies/categories",
        "GET /api/v1/taxonomies/tags",
        "GET /api/v1/publications",
        "GET /api/v1/youtube",
    };

    public static IReadOnlyList<CatalogRoute> Load()
    {
        var file = Path.Combine(RepoRoot(), "docs", "specs", "initial-build", "operations.csv");
        return File.ReadAllLines(file)
            .Skip(1)
            .Where(line => line.Length > 0)
            .Select(line => line.Split(','))
            .Select(f => new CatalogRoute(f[0], f[1], f[2], f[3], f[4]))
            .ToList();
    }

    public static string Shape(string path) => System.Text.RegularExpressions.Regex.Replace(path, @"\{[^}/]+\}", "{}");

    public static string Concrete(string path) => System.Text.RegularExpressions.Regex.Replace(path, @"\{[^}/]+\}", "x1");

    public static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, "TsrApp.slnx")))
        {
            dir = dir.Parent;
        }

        return dir?.FullName ?? throw new InvalidOperationException("TsrApp.slnx not found above " + AppContext.BaseDirectory);
    }
}
