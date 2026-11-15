using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Shared.Api;

namespace Tsr.Content.Api.Domain;

internal enum RefreshResult
{
    /// <summary>The tables now equal the content files.</summary>
    Refreshed,

    /// <summary>The content files are what the tables already hold; nothing was written.</summary>
    Unchanged,

    /// <summary>The last set was kept; <see cref="RefreshOutcome.Cause"/> says why.</summary>
    Kept,
}

internal sealed record RefreshOutcome(RefreshResult Result, string? Cause = null);

/// <summary>
/// One refresh of content's copy of the published content files (LIB-R20 to LIB-R24). The files are the source; the three tables are replaced in one transaction,
/// so a reader sees the last complete set or the new one. A read that fails, finds no published article, or finds fewer than half of the last count keeps the last set and records why.
/// One worker instance is the supported setup (docs/testing.md): two ticks at once are not guarded against here.
/// </summary>
internal static partial class ContentRefresh
{
    public const string TooFewArticles = "too few articles";

    private const int StateId = 1;

    private const int MaxCauseLength = 200;

    public static Task<RefreshOutcome> TickAsync(ContentContext db, string? directory, TimeProvider clock, ILogger log, CancellationToken ct) =>
        TickAsync(db, directory, clock, log, beforeCommit: null, ct);

    /// <summary><paramref name="beforeCommit"/> is awaited inside the transaction just before the commit: the one seam, for the test that reads while a refresh is open.</summary>
    internal static async Task<RefreshOutcome> TickAsync(
        ContentContext db, string? directory, TimeProvider clock, ILogger log, Func<CancellationToken, Task>? beforeCommit, CancellationToken ct)
    {
        var read = ContentFiles.Read(directory, clock, ct);
        return await StoreAsync(db, read, clock, log, beforeCommit, ct);
    }

    /// <summary>Rules 3 to 6 over one read: what the tick does once the files are in memory (or could not be read).</summary>
    internal static async Task<RefreshOutcome> StoreAsync(
        ContentContext db, Result<ContentSet> read, TimeProvider clock, ILogger log, Func<CancellationToken, Task>? beforeCommit, CancellationToken ct)
    {
        var state = await db.RefreshStates.SingleOrDefaultAsync(s => s.Id == StateId, ct);
        if (!read.IsSuccess)
        {
            return await KeepAsync(db, state, read.Error!, clock, log, ct);
        }

        var set = read.Value!;
        // A missing row counts as 0, which switches the half rule off.
        if (set.Articles.Count == 0 || set.Articles.Count * 2 < (state?.ArticleCount ?? 0))
        {
            return await KeepAsync(db, state, TooFewArticles, clock, log, ct);
        }

        var hash = Hash(set);
        if (state is not null && string.Equals(state.ContentHash, hash, StringComparison.Ordinal))
        {
            return new RefreshOutcome(RefreshResult.Unchanged);
        }

        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.PublishedArticles.ExecuteDeleteAsync(ct);
        await db.Categories.ExecuteDeleteAsync(ct);
        await db.Publications.ExecuteDeleteAsync(ct);
        db.PublishedArticles.AddRange(set.Articles);
        db.Categories.AddRange(set.Categories);
        db.Publications.AddRange(set.Publications);
        state = state ?? db.RefreshStates.Add(new RefreshState { Id = StateId }).Entity;
        state.ContentHash = hash;
        state.ArticleCount = set.Articles.Count;
        state.RefreshedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
        if (beforeCommit is not null)
        {
            await beforeCommit(ct);
        }

        await transaction.CommitAsync(ct);
        LogRefreshed(log, set.Articles.Count, set.Categories.Count, set.Publications.Count);
        return new RefreshOutcome(RefreshResult.Refreshed);
    }

    /// <summary>Records why the last set was kept (inserting the one row when no refresh has ever succeeded) and logs one warning. A cause names a file at most, cut to what the column holds.</summary>
    private static async Task<RefreshOutcome> KeepAsync(ContentContext db, RefreshState? state, string cause, TimeProvider clock, ILogger log, CancellationToken ct)
    {
        var stored = cause.Length > MaxCauseLength ? cause[..MaxCauseLength] : cause;
        state ??= db.RefreshStates.Add(new RefreshState { Id = StateId }).Entity;
        state.LastFailureAt = clock.GetUtcNow();
        state.LastFailureCause = stored;
        await db.SaveChangesAsync(ct);
        LogKept(log, stored);
        return new RefreshOutcome(RefreshResult.Kept, stored);
    }

    /// <summary>SHA-256 of the set's canonical JSON: every stored field of every article (by slug), category (by slug) and publication (by position), so a change to any field is a change.</summary>
    private static string Hash(ContentSet set)
    {
        using var buffer = new MemoryStream();
        using (var json = new Utf8JsonWriter(buffer))
        {
            json.WriteStartObject();
            json.WriteStartArray("articles");
            foreach (var article in set.Articles.OrderBy(a => a.Slug, StringComparer.Ordinal))
            {
                Write(json, article);
            }

            json.WriteEndArray();
            json.WriteStartArray("categories");
            foreach (var category in set.Categories.OrderBy(c => c.Slug, StringComparer.Ordinal))
            {
                Write(json, category);
            }

            json.WriteEndArray();
            json.WriteStartArray("publications");
            foreach (var publication in set.Publications.OrderBy(p => p.Position))
            {
                Write(json, publication);
            }

            json.WriteEndArray();
            json.WriteEndObject();
        }

        return Convert.ToHexStringLower(SHA256.HashData(buffer.GetBuffer().AsSpan(0, (int)buffer.Length)));
    }

    private static void Write(Utf8JsonWriter json, PublishedArticle article)
    {
        json.WriteStartObject();
        json.WriteString("slug", article.Slug);
        json.WriteString("slugDecoded", article.SlugDecoded);
        WriteNumber(json, "legacyId", article.LegacyId);
        json.WriteString("title", article.Title);
        json.WriteString("excerpt", article.Excerpt);
        json.WriteString("bodyMarkdown", article.BodyMarkdown);
        json.WriteString("bodyHtml", article.BodyHtml);
        json.WriteNumber("publishedAt", article.PublishedAt.UtcTicks);
        json.WriteString("publishedDateText", article.PublishedDateText);
        WriteNumber(json, "modifiedAt", article.ModifiedAt?.UtcTicks);
        json.WriteString("modifiedDateText", article.ModifiedDateText);
        json.WriteString("author", article.Author);
        json.WriteString("language", article.Language);
        json.WriteNumber("readingMinutes", article.ReadingMinutes);
        WriteList(json, "categories", article.Categories);
        WriteList(json, "tags", article.Tags);
        json.WriteEndObject();
    }

    private static void Write(Utf8JsonWriter json, Category category)
    {
        json.WriteStartObject();
        json.WriteString("slug", category.Slug);
        json.WriteString("title", category.Title);
        json.WriteString("description", category.Description);
        json.WriteNumber("sortOrder", category.SortOrder);
        json.WriteString("parentSlug", category.ParentSlug);
        json.WriteEndObject();
    }

    private static void Write(Utf8JsonWriter json, Publication publication)
    {
        json.WriteStartObject();
        json.WriteNumber("position", publication.Position);
        json.WriteString("title", publication.Title);
        json.WriteString("summary", publication.Summary);
        json.WriteString("type", publication.Type);
        json.WriteString("size", publication.Size);
        json.WriteString("updated", publication.Updated);
        json.WriteString("language", publication.Language);
        json.WriteString("file", publication.File);
        json.WriteString("readOnlineUrl", publication.ReadOnlineUrl);
        json.WriteBoolean("downloadOnly", publication.DownloadOnly);
        json.WriteEndObject();
    }

    private static void WriteNumber(Utf8JsonWriter json, string name, long? value)
    {
        if (value is null)
        {
            json.WriteNull(name);
            return;
        }

        json.WriteNumber(name, value.Value);
    }

    private static void WriteList(Utf8JsonWriter json, string name, string[] values)
    {
        json.WriteStartArray(name);
        foreach (var value in values)
        {
            json.WriteStringValue(value);
        }

        json.WriteEndArray();
    }

    [LoggerMessage(Level = LogLevel.Information, Message = "Content refresh: copied {Articles} articles, {Categories} categories, {Publications} publications")]
    private static partial void LogRefreshed(ILogger logger, int articles, int categories, int publications);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Content refresh: kept the last set: {Cause}")]
    private static partial void LogKept(ILogger logger, string cause);
}
