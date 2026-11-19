namespace Tsr.Shared.Site;

/// <summary>
/// One page a domain contributes to the static site: where it is written, its title, and the
/// Razor component (with its parameters) that renders its body. The site host adds the frame; the
/// component writes its own &lt;main&gt;, as each page of the present website does.
/// </summary>
/// <param name="Path">Site path, starting and ending with '/', e.g. "/articles/". Written as Path/index.html.</param>
/// <param name="Title">The whole text of the page's &lt;title&gt;.</param>
/// <param name="Description">The page's meta description; null gives the site's own.</param>
/// <param name="Files">
/// Static files the page shows, each as its site address (e.g. "/images/donate-qr.jpeg"). The host stops the build when one
/// is not among its static files, so a page is never published with a broken image.
/// </param>
/// <param name="Script">
/// A script of the host's static files that only this page loads, after site.js (e.g. "/self-reflection.js"). Checked like <paramref name="Files"/>:
/// a missing file stops the build.
/// </param>
/// <param name="RefreshTo">Site path the page sends the reader to at once, written as a refresh in the head (the static server has no redirect rules).</param>
public sealed record SitePage(
    string Path,
    string Title,
    Type Component,
    IReadOnlyDictionary<string, object?> Parameters,
    string? Description = null,
    IReadOnlyList<string>? Files = null,
    string? Script = null,
    string? RefreshTo = null);

/// <summary>
/// One category in the frame's menu, as a domain hands it to the site host. A parent is always listed; the domain leaves out
/// the children it does not want shown.
/// </summary>
public sealed record MenuCategory(string Slug, string Title, IReadOnlyList<MenuCategory> Subcategories);
