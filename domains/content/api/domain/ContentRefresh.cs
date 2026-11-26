using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Npgsql;
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

    /// <summary>What the last copy recorded: the two columns the rules read. Null when no copy or failure has ever been recorded.</summary>
    private sealed record StoredState(string ContentHash, int ArticleCount);

    public static Task<RefreshOutcome> TickAsync(NpgsqlDataSource source, string? directory, TimeProvider clock, ILogger log, CancellationToken ct) =>
        TickAsync(source, directory, clock, log, beforeCommit: null, ct);

    /// <summary><paramref name="beforeCommit"/> is awaited inside the transaction just before the commit: the one seam, for the test that reads while a refresh is open.</summary>
    internal static async Task<RefreshOutcome> TickAsync(
        NpgsqlDataSource source, string? directory, TimeProvider clock, ILogger log, Func<CancellationToken, Task>? beforeCommit, CancellationToken ct)
    {
        var read = ContentFiles.Read(directory, clock, ct);
        return await StoreAsync(source, read, clock, log, beforeCommit, ct);
    }

    /// <summary>Rules 3 to 6 over one read: what the tick does once the files are in memory (or could not be read).</summary>
    internal static async Task<RefreshOutcome> StoreAsync(
        NpgsqlDataSource source, Result<ContentSet> read, TimeProvider clock, ILogger log, Func<CancellationToken, Task>? beforeCommit, CancellationToken ct)
    {
        // Read on its own pooled connection, released before the transaction opens: no path holds two.
        var state = await ReadStateAsync(source, ct);
        if (!read.IsSuccess)
        {
            return await KeepAsync(source, state, read.Error!, clock, log, ct);
        }

        var set = read.Value!;
        // A missing row counts as 0, which switches the half rule off.
        if (set.Articles.Count == 0 || set.Articles.Count * 2 < (state?.ArticleCount ?? 0))
        {
            return await KeepAsync(source, state, TooFewArticles, clock, log, ct);
        }

        var hash = Hash(set);
        if (state is not null && string.Equals(state.ContentHash, hash, StringComparison.Ordinal))
        {
            return new RefreshOutcome(RefreshResult.Unchanged);
        }

        await using var tx = await source.BeginAsync(ct);
        await ReplaceRowsAsync(tx, set, ct);
        await WriteStateAsync(tx, state is null, hash, set.Articles.Count, clock.GetUtcNow(), ct);
        if (beforeCommit is not null)
        {
            await beforeCommit(ct);
        }

        await tx.CommitAsync(ct);
        LogRefreshed(log, set.Articles.Count, set.Categories.Count, set.Publications.Count);
        return new RefreshOutcome(RefreshResult.Refreshed);
    }

    private static async Task<StoredState?> ReadStateAsync(NpgsqlDataSource source, CancellationToken ct)
    {
        var rows = await source.ListAsync(
            $"select content_hash, article_count from content.refresh_state where id = {StateId}",
            row => new StoredState(row.Text("content_hash"), row.Int("article_count")),
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    // One insert per row (plan, Approach 4). Delete, never truncate: truncate's lock would block readers (CON-R4).
    private static async Task ReplaceRowsAsync(DbTx tx, ContentSet set, CancellationToken ct)
    {
        _ = await tx.ExecuteAsync($"delete from content.published_articles", ct);
        _ = await tx.ExecuteAsync($"delete from content.categories", ct);
        _ = await tx.ExecuteAsync($"delete from content.publications", ct);
        foreach (var article in set.Articles)
        {
            _ = await tx.ExecuteAsync(
                $"""
                insert into content.published_articles
                    (slug, slug_decoded, legacy_id, title, excerpt, body_markdown, body_html, published_at, published_date_text,
                     modified_at, modified_date_text, author, language, reading_minutes, categories, tags)
                values
                    ({article.Slug}, {article.SlugDecoded}, {article.LegacyId}, {article.Title}, {article.Excerpt}, {article.BodyMarkdown}, {article.BodyHtml}, {article.PublishedAt}, {article.PublishedDateText},
                     {article.ModifiedAt}, {article.ModifiedDateText}, {article.Author}, {article.Language}, {article.ReadingMinutes}, {article.Categories}, {article.Tags})
                """,
                ct);
        }

        foreach (var category in set.Categories)
        {
            _ = await tx.ExecuteAsync(
                $"""
                insert into content.categories (slug, title, description, sort_order, parent_slug)
                values ({category.Slug}, {category.Title}, {category.Description}, {category.SortOrder}, {category.ParentSlug})
                """,
                ct);
        }

        foreach (var publication in set.Publications)
        {
            _ = await tx.ExecuteAsync(
                $"""
                insert into content.publications (position, title, summary, type, size, updated, language, file, read_online_url, download_only)
                values ({publication.Position}, {publication.Title}, {publication.Summary}, {publication.Type}, {publication.Size}, {publication.Updated}, {publication.Language}, {publication.File}, {publication.ReadOnlineUrl}, {publication.DownloadOnly})
                """,
                ct);
        }
    }

    // As EF wrote it: an insert when no row was read, else an update of the three columns a store changes.
    private static async Task WriteStateAsync(DbTx tx, bool insert, string hash, int count, DateTimeOffset now, CancellationToken ct)
    {
        var changed = insert
            ? await tx.ExecuteAsync(
                $"insert into content.refresh_state (id, content_hash, article_count, refreshed_at) values ({StateId}, {hash}, {count}, {now})",
                ct)
            : await tx.ExecuteAsync(
                $"update content.refresh_state set content_hash = {hash}, article_count = {count}, refreshed_at = {now} where id = {StateId}",
                ct);
        RequireOneStateRow(changed);
    }

    // As EF's update did: a state write that changes no row (the row went between the read and the write) is a failure, so the copy rolls back.
    private static void RequireOneStateRow(int changed)
    {
        if (changed != 1)
        {
            throw new InvalidOperationException($"The content refresh state write changed {changed} rows, not 1.");
        }
    }

    /// <summary>Records why the last set was kept (inserting the one row when no refresh has ever succeeded) and logs one warning. A cause names a file at most, cut to what the column holds.</summary>
    private static async Task<RefreshOutcome> KeepAsync(NpgsqlDataSource source, StoredState? state, string cause, TimeProvider clock, ILogger log, CancellationToken ct)
    {
        var stored = cause.Length > MaxCauseLength ? cause[..MaxCauseLength] : cause;
        var now = clock.GetUtcNow();
        var changed = state is null
            ? await source.ExecuteAsync(
                $"insert into content.refresh_state (id, content_hash, article_count, last_failure_at, last_failure_cause) values ({StateId}, '', 0, {now}, {stored})",
                ct)
            : await source.ExecuteAsync(
                $"update content.refresh_state set last_failure_at = {now}, last_failure_cause = {stored} where id = {StateId}",
                ct);
        RequireOneStateRow(changed);
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
