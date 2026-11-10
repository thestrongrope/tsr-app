using System.Net;
using System.Text.Json;
using Xunit;

namespace Tsr.Content.Contract.Tests;

/// <summary>
/// GET /articles, as specified in ../api.yaml. Public: no sign-in. Only published articles are
/// public; the synthetic seed (db/synthetic/seed.sql) has one of each kind.
/// </summary>
public sealed class ListPublishedArticlesContractTests
{
    private const string Published = "synthetic-published-article";
    private const string Draft = "synthetic-draft-article";
    private const string Scheduled = "synthetic-scheduled-article";

    [Fact]
    public async Task Anyone_can_list_articles_without_sign_in()
    {
        using var client = Target.Anonymous();

        var response = await client.GetAsync(new Uri("/articles", UriKind.Relative));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task A_published_article_is_listed_with_its_fields()
    {
        var article = Assert.Single(await ArticlesAsync(), a => a.GetProperty("slug").GetString() == Published);

        Assert.False(string.IsNullOrWhiteSpace(article.GetProperty("title").GetString()));
        Assert.False(string.IsNullOrWhiteSpace(article.GetProperty("body").GetString()));
        Assert.True(article.GetProperty("publishedAt").TryGetDateTimeOffset(out _));
    }

    [Theory]
    [InlineData(Draft)]
    [InlineData(Scheduled)]
    public async Task An_unpublished_article_is_never_listed(string slug)
    {
        var slugs = (await ArticlesAsync()).Select(a => a.GetProperty("slug").GetString()).ToList();

        Assert.Contains(Published, slugs);
        Assert.DoesNotContain(slug, slugs);
    }

    private static async Task<List<JsonElement>> ArticlesAsync()
    {
        using var client = Target.Anonymous();
        var response = await client.GetAsync(new Uri("/articles", UriKind.Relative));
        response.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        return json.RootElement.GetProperty("articles").EnumerateArray().Select(a => a.Clone()).ToList();
    }
}
