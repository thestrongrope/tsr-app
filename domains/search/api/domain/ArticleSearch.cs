using Microsoft.Extensions.Logging;

namespace Tsr.Search.Api.Domain;

/// <summary>What <c>GET /api/v1/search</c> asked for: the trimmed text, one category or none, and the page.</summary>
internal sealed record ArticleSearchRequest(string Q, string? Category, int Limit, int Offset);

/// <summary>The articles to send and the engine that found them: <c>elasticsearch</c>, or <c>fuse</c> for the database fallback (the website's own word for its fallback).</summary>
internal sealed record ArticleSearchOutcome(IReadOnlyList<ArticleResult> Results, string Engine);

/// <summary>The database fallback of article search: the published articles read through <c>content.v_published_articles</c>. A database boundary, so an interface for the unit tests.</summary>
internal interface IArticleFallback
{
    Task<IReadOnlyList<ArticleResult>> SearchAsync(ArticleSearchRequest request, CancellationToken ct);
}

/// <summary>
/// The engine choice of article search (SRCH-R6, tsr-web <c>search()</c>): the engine when it is configured and answers; otherwise, for whatever reason, the database. The reason is logged by its fixed wording only: no query text (SRCH-Q3).
/// A request the caller gave up is not a failure of the engine.
/// </summary>
internal static partial class ArticleSearch
{
    public static async Task<ArticleSearchOutcome> RunAsync(ILibraryIndex index, IArticleFallback fallback, ArticleSearchRequest request, ILogger log, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(index);
        ArgumentNullException.ThrowIfNull(fallback);
        ArgumentNullException.ThrowIfNull(request);
        ArgumentNullException.ThrowIfNull(log);
        if (index.IsConfigured)
        {
            try
            {
                var body = ArticleSearchQuery.Body(request.Q, request.Category, request.Limit, request.Offset);
                var answer = await index.SearchAsync(ArticleSearchQuery.IndexName, body, ct);
                return new ArticleSearchOutcome(ArticleSearchQuery.ReadHits(answer), "elasticsearch");
            }
            catch (SearchUnavailableException unavailable)
            {
                LogFallback(log, unavailable.Message);
            }
        }

        return new ArticleSearchOutcome(await fallback.SearchAsync(request, ct), "fuse");
    }

    [LoggerMessage(Level = LogLevel.Warning, Message = "Article search: the engine could not answer ({Reason}); answering from the database")]
    private static partial void LogFallback(ILogger logger, string reason);
}
