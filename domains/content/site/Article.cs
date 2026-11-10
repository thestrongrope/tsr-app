namespace Tsr.Content.Site;

/// <summary>
/// An article as GET /articles returns it (domains/content/spec/api.yaml). A copy of the contract's
/// shape, not of the api project's type: the site reads the published contract, like any client.
/// </summary>
public sealed record Article(string Slug, string Title, string Body, DateTimeOffset PublishedAt)
{
    public IEnumerable<string> Paragraphs() =>
        Body.Split("\n\n", StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}

public sealed record ArticleList(IReadOnlyList<Article> Articles);
