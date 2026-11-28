using System.Buffers;
using System.Text.Encodings.Web;
using System.Text.Json;
using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Search.Api.Domain;

/// <summary>
/// What the article index should hold, read from <c>content.v_published_articles</c> (the published view of content; rule 2), newest article first and then by slug: tsr-web indexes in the order <c>getAllPosts</c> sorts, newest first.
/// One document per article, its id the slug, the fields of tsr-web's <c>reindexArticles</c> in its order: slug, title, excerpt, content, categories, tags, author, language, publishedDate, modifiedDate, status. An absent excerpt or modified date is left out, as JavaScript
/// leaves out <c>undefined</c>. <c>content</c> is empty and <c>status</c> is <c>publish</c> for every article: the live index holds no article body (owner decision c, 27 Nov 2026), and the view holds published articles only.
/// One run at a time across instances: a session advisory lock (key <see cref="LockKey"/>, <c>pg_try_advisory_lock</c> on the run's own connection, released when the run is disposed); a tick that finds it held is skipped.
/// </summary>
internal sealed class ArticleFeedSource(DbSettings settings)
{
    /// <summary>The advisory lock key of the Library feed. Not used anywhere else (recorded in domains/search/CLAUDE.md).</summary>
    public const long LockKey = 8100002;

    /// <summary>The most articles one run reads (a stop for a table that grew without bound; content's own refresh keeps far fewer).</summary>
    public const int MaxArticles = 10000;

    private const int TimeoutSeconds = 30;

    private static readonly JsonWriterOptions Options = new() { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };

    public async Task<ArticleFeedRun?> TryOpenAsync(CancellationToken ct)
    {
        var builder = new NpgsqlConnectionStringBuilder(settings.ConnectionString) { Timeout = TimeoutSeconds, CommandTimeout = TimeoutSeconds };
        var connection = new NpgsqlConnection(builder.ConnectionString);
        try
        {
            await connection.OpenAsync(ct);
            await using var command = new NpgsqlCommand("select pg_try_advisory_lock(@key)", connection);
            command.Parameters.AddWithValue("key", LockKey);
            if ((bool)(await command.ExecuteScalarAsync(ct))!)
            {
                return new ArticleFeedRun(connection);
            }
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }

        await connection.DisposeAsync();
        return null;
    }

    /// <summary>A run that holds the lock; disposing it releases the lock by closing its connection.</summary>
    internal sealed class ArticleFeedRun(NpgsqlConnection connection) : IAsyncDisposable
    {
        private const string Sql =
            """
            select slug, title::text, excerpt::text, categories, tags, author::text, language::text, published_date_text::text, modified_date_text::text
            from content.v_published_articles
            order by published_at desc, slug asc
            limit @limit
            """;

        public async Task<IReadOnlyList<LibraryDocument>> ArticlesAsync(CancellationToken ct)
        {
            var documents = new List<LibraryDocument>();
            await using var command = new NpgsqlCommand(Sql, connection);
            command.Parameters.AddWithValue("limit", MaxArticles);
            await using var reader = await command.ExecuteReaderAsync(ct);
            while (await reader.ReadAsync(ct))
            {
                var slug = reader.GetString(0);
                documents.Add(new LibraryDocument(slug, Document(reader, slug)));
            }

            return documents;
        }

        // A pooled connection keeps its session locks until it is next used, so the lock is released here, not left to the pool.
        public async ValueTask DisposeAsync()
        {
            try
            {
                await using var release = new NpgsqlCommand("select pg_advisory_unlock(@key)", connection);
                release.Parameters.AddWithValue("key", LockKey);
                _ = await release.ExecuteScalarAsync();
            }
            catch (NpgsqlException)
            {
                // The connection is broken, so its session is gone and the lock with it.
            }
            finally
            {
                await connection.DisposeAsync();
            }
        }

        private static string Document(NpgsqlDataReader reader, string slug)
        {
            var buffer = new ArrayBufferWriter<byte>();
            using (var json = new Utf8JsonWriter(buffer, Options))
            {
                json.WriteStartObject();
                json.WriteString("slug", slug);
                json.WriteString("title", reader.GetString(1));
                if (!reader.IsDBNull(2))
                {
                    json.WriteString("excerpt", reader.GetString(2));
                }

                json.WriteString("content", string.Empty);
                WriteList(json, "categories", reader.GetFieldValue<string[]>(3));
                WriteList(json, "tags", reader.GetFieldValue<string[]>(4));
                json.WriteString("author", reader.GetString(5));
                json.WriteString("language", reader.GetString(6));
                json.WriteString("publishedDate", reader.GetString(7));
                if (!reader.IsDBNull(8))
                {
                    json.WriteString("modifiedDate", reader.GetString(8));
                }

                json.WriteString("status", "publish");
                json.WriteEndObject();
            }

            return System.Text.Encoding.UTF8.GetString(buffer.WrittenSpan);
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
    }
}
