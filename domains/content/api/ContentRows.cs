namespace Tsr.Content.Api;

/// <summary>One published article of the content files, as the last refresh read it. A draft is never copied here.</summary>
internal sealed class PublishedArticle
{
    /// <summary>The slug as written in the file (may hold percent-encoded characters).</summary>
    public string Slug { get; set; } = string.Empty;

    /// <summary>The slug after percent-decoding: what a request path is matched against.</summary>
    public string SlugDecoded { get; set; } = string.Empty;

    public int? LegacyId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Excerpt { get; set; }

    public string BodyMarkdown { get; set; } = string.Empty;

    public string BodyHtml { get; set; } = string.Empty;

    public DateTimeOffset PublishedAt { get; set; }

    /// <summary>The file's own date string, sent back unchanged.</summary>
    public string PublishedDateText { get; set; } = string.Empty;

    public DateTimeOffset? ModifiedAt { get; set; }

    public string? ModifiedDateText { get; set; }

    public string Author { get; set; } = string.Empty;

    public string Language { get; set; } = string.Empty;

    public int ReadingMinutes { get; set; }

    /// <summary>Category slugs, in file order.</summary>
    public string[] Categories { get; set; } = [];

    /// <summary>Tag names, in file order.</summary>
    public string[] Tags { get; set; } = [];
}

/// <summary>One category of the content files; a child names its parent's slug.</summary>
internal sealed class Category
{
    public string Slug { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public string? Description { get; set; }

    public int SortOrder { get; set; }

    public string? ParentSlug { get; set; }
}

/// <summary>One entry of the publications page; Position is its place in the file.</summary>
internal sealed class Publication
{
    public int Position { get; set; }

    public string Title { get; set; } = string.Empty;

    public string? Summary { get; set; }

    public string? Type { get; set; }

    public string? Size { get; set; }

    public string? Updated { get; set; }

    public string? Language { get; set; }

    public string? File { get; set; }

    public string? ReadOnlineUrl { get; set; }

    public bool DownloadOnly { get; set; }
}
