using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;

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
internal sealed class ListPublishedArticlesHandler(ContentContext db, TimeProvider clock)
{
    /// <summary>Bound on one response (MUST 2). Paging comes when the site has more than this.</summary>
    public const int MaxArticles = 500;

    public async Task<IResult> HandleAsync(CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        var articles = await db.Articles.AsNoTracking()
            .Where(a => a.PublishedAt != null && a.PublishedAt <= now)
            .OrderByDescending(a => a.PublishedAt)
            .ThenByDescending(a => a.Id)
            .Take(MaxArticles)
            .Select(a => new ArticleResponse(a.Slug, a.Title, a.Body, a.PublishedAt!.Value))
            .ToListAsync(ct);

        return Results.Ok(new ListPublishedArticlesResponse(articles));
    }
}
