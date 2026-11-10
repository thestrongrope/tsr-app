using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using MySqlConnector;
using Tsr.Shared.Api;

namespace Tsr.Content.Api.Features.ListPublishedArticles;

// One vertical slice: GET /articles. Public: no caller, no permission. The rule that only
// published articles are public lives in the query below, not in the site that renders them.
// Contract: domains/content/spec/api.yaml. Behaviour: domains/content/spec/tests.

internal sealed record ArticleResponse(string Slug, string Title, string Body, DateTimeOffset PublishedAt);

internal sealed record ListPublishedArticlesResponse(IReadOnlyList<ArticleResponse> Articles);

internal static class ListPublishedArticlesEndpoint
{
    public static IEndpointRouteBuilder MapListPublishedArticles(this IEndpointRouteBuilder routes)
    {
        routes.MapGet(
            "/articles",
            (HttpContext context, ListPublishedArticlesHandler handler) => handler.HandleAsync(context.RequestAborted));
        return routes;
    }
}

/// <summary>Reads the published articles, newest first, up to <see cref="MaxArticles"/>.</summary>
internal sealed class ListPublishedArticlesHandler(Db db, TimeProvider clock)
{
    /// <summary>Bound on one response (MUST 2). Paging comes when the site has more than this.</summary>
    public const int MaxArticles = 500;

    public async Task<IResult> HandleAsync(CancellationToken ct)
    {
        await using var connection = await db.OpenAsync(ct);
        await using var command = new MySqlCommand(
            """
            select slug, title, body, published_at from articles
             where published_at is not null and published_at <= @now
             order by published_at desc, id desc
             limit @limit
            """,
            connection);
        command.Parameters.AddWithValue("@now", clock.GetUtcNow().UtcDateTime);
        command.Parameters.AddWithValue("@limit", MaxArticles);

        var articles = new List<ArticleResponse>();
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
        {
            var publishedAt = DateTime.SpecifyKind(reader.GetDateTime(3), DateTimeKind.Utc);
            articles.Add(new ArticleResponse(reader.GetString(0), reader.GetString(1), reader.GetString(2), publishedAt));
        }

        return Results.Ok(new ListPublishedArticlesResponse(articles));
    }
}
