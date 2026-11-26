using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Npgsql;
using Tsr.Content.Api.Domain;
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
internal sealed class ListPublishedArticlesHandler(NpgsqlDataSource source, TimeProvider clock)
{
    /// <summary>Bound on one response (MUST 2). Paging comes when the site has more than this.</summary>
    public const int MaxArticles = 500;

    public async Task<IResult> HandleAsync(CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var articles = await source.ListAsync(
            $"""
                select slug as "Slug", title as "Title", body as "Body", published_at as "PublishedAt"
                from content.articles
                where published_at is not null and published_at <= {now}
                order by published_at desc, id desc
                limit {MaxArticles}
                """,
            row => new ArticleResponse(row.Text("Slug"), row.Text("Title"), row.Text("Body"), row.Instant("PublishedAt")),
            ct);

        return Results.Json(new ListPublishedArticlesResponse(articles), ContentJson.Answers.ListPublishedArticlesResponse);
    }
}
