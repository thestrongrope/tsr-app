using System.Globalization;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;
using Tsr.Content.Api;
using Tsr.Content.Api.Domain;

namespace Tsr.Db.Tests;

/// <summary>A throwaway content directory in the layout of the website's content files, written by a test. Invented text only.</summary>
internal sealed class ContentTestFiles : IDisposable
{
    private readonly DirectoryInfo root = Directory.CreateTempSubdirectory("tsr-content-");

    public string Root => root.FullName;

    public void Dispose() => root.Delete(recursive: true);

    public void Write(string folder, string fileName, string text)
    {
        Directory.CreateDirectory(Path.Combine(Root, folder));
        File.WriteAllText(Path.Combine(Root, folder, fileName), text);
    }

    public void Delete(string folder, string fileName) => File.Delete(Path.Combine(Root, folder, fileName));

    /// <summary>One article file named after its slug. Published on day <paramref name="day"/> of January 2024.</summary>
    public void Article(string slug, string status = "publish", string? title = null, string body = "Body text.\n", string tag = "Shared Tag", string category = "shared-category", int day = 1) =>
        Write("articles", slug + ".md", string.Create(CultureInfo.InvariantCulture, $"""
            ---
            title: {title ?? "Title of " + slug}
            slug: {slug}
            publishedDate: '2024-01-{day:00}T08:00:00.000Z'
            excerpt: 'Excerpt of {slug}'
            author: admin
            tags:
              - {tag}
            status: {status}
            language: en
            categories:
              - {category}
            ---
            {body}
            """));

    public void Category(string slug, string frontMatter) => Write("categories", slug + ".md", "---\n" + frontMatter + "\n---\n");
}

/// <summary>The synthetic set of db/synthetic/content (its README.md says what is in it), copied into the test database by one refresh.</summary>
internal static class SyntheticContent
{
    public static async Task LoadAsync(WebApplicationFactory<Program> factory)
    {
        await TestDatabase.ExecuteAsync("truncate content.published_articles, content.categories, content.publications, content.refresh_state");
        await using var scope = factory.Services.CreateAsyncScope();
        var directory = Path.Combine(TestDatabase.RepoRoot(), "db", "synthetic", "content");
        var outcome = await ContentRefresh.TickAsync(scope.ServiceProvider.GetRequiredService<ContentContext>(), directory, TimeProvider.System, NullLogger.Instance, CancellationToken.None);
        Assert.That(outcome.Result, Is.EqualTo(RefreshResult.Refreshed));
    }
}
