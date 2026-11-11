using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Content.Api;

/// <summary>content's tables, schema "content". The articles the public site shows and the surah list (PHP holy_quran).</summary>
internal sealed class ContentContext(DbContextOptions<ContentContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "content";

    public DbSet<Article> Articles => Set<Article>();

    public DbSet<HolyQuranSurah> HolyQuran => Set<HolyQuranSurah>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Article>(article =>
        {
            article.Property(a => a.Slug).HasMaxLength(120);
            article.Property(a => a.Title).HasMaxLength(200);
            article.HasIndex(a => a.Slug).IsUnique().HasDatabaseName("uq_articles_slug");
            article.HasIndex(a => a.PublishedAt).HasDatabaseName("idx_articles_published");
        });

        // PHP holy_quran: the 114 surahs with their verse counts, keyed by the surah number. The recitation columns of classes read it.
        modelBuilder.Entity<HolyQuranSurah>(surah =>
        {
            surah.ToTable("holy_quran");
            surah.Property(s => s.Surah).HasMaxLength(100);
            surah.Property(s => s.Arabic).HasMaxLength(255);
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

/// <summary>One surah of the Quran (PHP <c>holy_quran</c>): its number (<c>Id</c>), name, Arabic name and verse count.</summary>
internal sealed class HolyQuranSurah
{
    public int Id { get; set; }

    public string Surah { get; set; } = string.Empty;

    public string? Arabic { get; set; }

    public int Verses { get; set; }
}
