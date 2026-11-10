namespace Tsr.Shared.Site;

/// <summary>
/// One page a domain contributes to the static site: where it is written, its title, and the
/// Razor component (with its parameters) that renders its body. The site host adds the layout.
/// </summary>
/// <param name="Path">Site path, starting and ending with '/', e.g. "/articles/". Written as Path/index.html.</param>
/// <param name="NavTitle">Shown in the site's navigation when set; most pages leave it null.</param>
public sealed record SitePage(
    string Path,
    string Title,
    Type Component,
    IReadOnlyDictionary<string, object?> Parameters,
    string? NavTitle = null);
