using System.Diagnostics;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using NUnit.Framework;
using Tsr.Platform.Api.Domain;

namespace Tsr.Platform.Api.Tests.Domain;

/// <summary>PHP's api_app_version_catalog(): whatever goes wrong reading or decoding the file, the answer is null (the fallback), never an error.</summary>
public sealed class AppCatalogSourceTests
{
    private string directory = string.Empty;

    [SetUp]
    public void CreateDirectory()
    {
        directory = Directory.CreateTempSubdirectory("catalog-source").FullName;
    }

    [TearDown]
    public void DeleteDirectory()
    {
        Directory.Delete(directory, recursive: true);
    }

    private static async Task<bool> IsNullAsync(string path)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection([new KeyValuePair<string, string?>(AppCatalogSource.SettingName, path)])
            .Build();
        using var document = await new AppCatalogSource(configuration, NullLogger<AppCatalogSource>.Instance).LoadAsync(CancellationToken.None);
        return document is null;
    }

    [Test]
    public async Task A_readable_catalog_is_returned()
    {
        var path = Path.Combine(directory, "catalog.json");
        await File.WriteAllTextAsync(path, "{\"android\":{\"minimumBuild\":2}}");

        Assert.That(await IsNullAsync(path), Is.False);
    }

    [Test]
    public async Task A_catalog_with_a_lone_surrogate_escape_anywhere_is_wholly_invalid()
    {
        var path = Path.Combine(directory, "catalog.json");
        await File.WriteAllTextAsync(path, "{\"unused\":\"\\ud800\",\"android\":{\"minimumBuild\":2}}");

        Assert.That(await IsNullAsync(path), Is.True);
    }

    [Test]
    public async Task A_path_with_a_nul_character_gives_the_fallback()
    {
        Assert.That(await IsNullAsync(Path.Combine(directory, "a\0b.json")), Is.True);
    }

    [Test]
    public async Task A_file_that_cannot_seek_is_read_to_its_end()
    {
        Assume.That(OperatingSystem.IsMacOS() || OperatingSystem.IsLinux(), "needs mkfifo");
        var path = Path.Combine(directory, "catalog.fifo");
        using (var mkfifo = Process.Start("mkfifo", path))
        {
            await mkfifo.WaitForExitAsync();
        }

        var writer = Task.Run(() => File.WriteAllText(path, "{\"android\":{\"minimumBuild\":2}}"));

        Assert.That(await IsNullAsync(path), Is.False);
        await writer;
    }
}
