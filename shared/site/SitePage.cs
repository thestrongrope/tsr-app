namespace Tsr.Shared.Site;

/// <summary>
/// One page a domain contributes to the static site: where it is written, its title, and the
/// Razor component (with its parameters) that renders its body. The site host adds the frame; the
/// component writes its own &lt;main&gt;, as each page of the present website does.
/// </summary>
/// <param name="Path">Site path, starting and ending with '/', e.g. "/articles/". Written as Path/index.html.</param>
/// <param name="Title">The whole text of the page's &lt;title&gt;.</param>
/// <param name="NavTitle">Shown in the home page's list of links when set; most pages leave it null.</param>
/// <param name="Description">The page's meta description; null gives the site's own.</param>
public sealed record SitePage(
    string Path,
    string Title,
    Type Component,
    IReadOnlyDictionary<string, object?> Parameters,
    string? NavTitle = null,
    string? Description = null);

/// <summary>
/// One category in the frame's menu, as a domain hands it to the site host. A parent is always listed; the domain leaves out
/// the children it does not want shown.
/// </summary>
public sealed record MenuCategory(string Slug, string Title, IReadOnlyList<MenuCategory> Subcategories);
