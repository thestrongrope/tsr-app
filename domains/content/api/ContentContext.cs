using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Content.Api;

/// <summary>
/// content's tables, schema "content". The articles the public site shows, the surah list (PHP holy_quran) and the copy of the
/// published content files the Library reads answer from (published_articles, categories, publications, refresh_state).
/// </summary>
internal sealed class ContentContext(DbContextOptions<ContentContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "content";

    private const string CaseSensitiveText = "text";

    public DbSet<Article> Articles => Set<Article>();

    public DbSet<HolyQuranSurah> HolyQuran => Set<HolyQuranSurah>();

    public DbSet<PublishedArticle> PublishedArticles => Set<PublishedArticle>();

    public DbSet<Category> Categories => Set<Category>();

    public DbSet<Publication> Publications => Set<Publication>();

    public DbSet<RefreshState> RefreshStates => Set<RefreshState>();

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

        ConfigureLibrary(modelBuilder);
    }

    /// <summary>
    /// The copy of the published content files. Written exception to "every text column is citext" (db/tests/SchemaGuardTests.cs
    /// allow-list): an article's slug and decoded slug, its categories and tags, and a category's slug and parent slug are plain
    /// case-sensitive text, because an address, a category and a tag match exactly on today's website (LIB-R3, LIB-R4, LIB-R11).
    /// </summary>
    private static void ConfigureLibrary(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<PublishedArticle>(article =>
        {
            article.HasKey(a => a.Slug);
            article.Property(a => a.Slug).HasColumnType(CaseSensitiveText);
            article.Property(a => a.SlugDecoded).HasColumnType(CaseSensitiveText);
            article.Property(a => a.Title).HasMaxLength(500);
            article.Property(a => a.PublishedDateText).HasMaxLength(40);
            article.Property(a => a.ModifiedDateText).HasMaxLength(40);
            article.Property(a => a.Author).HasMaxLength(100);
            article.Property(a => a.Language).HasMaxLength(10);
            article.HasIndex(a => a.SlugDecoded).IsUnique().HasDatabaseName("uq_published_articles_slug_decoded");
            article.HasIndex(a => a.PublishedAt).HasDatabaseName("idx_published_articles_published_at");
            article.HasIndex(a => a.Categories).HasMethod("gin").HasDatabaseName("idx_published_articles_categories");
            article.HasIndex(a => a.Tags).HasMethod("gin").HasDatabaseName("idx_published_articles_tags");
        });

        modelBuilder.Entity<Category>(category =>
        {
            category.HasKey(c => c.Slug);
            category.Property(c => c.Slug).HasColumnType(CaseSensitiveText).HasMaxLength(255);
            category.Property(c => c.Title).HasMaxLength(255);
            category.Property(c => c.ParentSlug).HasColumnType(CaseSensitiveText).HasMaxLength(255);
            category.ToTable(t =>
            {
                // The two case-sensitive columns are not citext, so the convention writes no length check for them.
                t.HasCheckConstraint("ck_categories_slug_length", "char_length(\"slug\") <= 255");
                t.HasCheckConstraint("ck_categories_parent_slug_length", "char_length(\"parent_slug\") <= 255");
            });
        });

        modelBuilder.Entity<Publication>(publication =>
        {
            publication.HasKey(p => p.Position);
            publication.Property(p => p.Position).ValueGeneratedNever();
            publication.Property(p => p.Title).HasMaxLength(500);
            publication.Property(p => p.Type).HasMaxLength(50);
            publication.Property(p => p.Size).HasMaxLength(50);
            publication.Property(p => p.Updated).HasMaxLength(50);
            publication.Property(p => p.Language).HasMaxLength(50);
            publication.Property(p => p.File).HasMaxLength(500);
            publication.Property(p => p.ReadOnlineUrl).HasMaxLength(500);
        });

        modelBuilder.Entity<RefreshState>(state =>
        {
            state.ToTable("refresh_state");
            state.Property(s => s.Id).ValueGeneratedNever();
            state.Property(s => s.ContentHash).HasMaxLength(64);
            state.Property(s => s.LastFailureCause).HasMaxLength(200);
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

/// <summary>The one row (Id 1) that says what the last refresh copied and why the last failed one kept the old set.</summary>
internal sealed class RefreshState
{
    public int Id { get; set; }

    public string ContentHash { get; set; } = string.Empty;

    public int ArticleCount { get; set; }

    /// <summary>When the last refresh that copied a set finished; null while none has (a failure can come first).</summary>
    public DateTimeOffset? RefreshedAt { get; set; }

    public DateTimeOffset? LastFailureAt { get; set; }

    public string? LastFailureCause { get; set; }
}
