using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Content.Api;

/// <summary>content's tables, schema "content". Today: the articles the public site shows.</summary>
internal sealed class ContentContext(DbContextOptions<ContentContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "content";

    public DbSet<Article> Articles => Set<Article>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Article>(article =>
        {
            article.Property(a => a.Slug).HasMaxLength(120);
            article.Property(a => a.Title).HasMaxLength(200);
            article.HasIndex(a => a.Slug).IsUnique().HasDatabaseName("uq_articles_slug");
            article.HasIndex(a => a.PublishedAt).HasDatabaseName("idx_articles_published");
        });
    }
}

/// <summary>An article is public only once PublishedAt is set and not in the future (UTC). Null is a draft.</summary>
internal sealed class Article
{
    public int Id { get; set; }

    public string Slug { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public DateTimeOffset? PublishedAt { get; set; }
}
