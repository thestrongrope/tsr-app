using Tsr.Shared.Site;
using NUnit.Framework;

namespace Tsr.Host.Site.Tests;

/// <summary>The files the old website served from folders whose name starts with a dot (the app link files) must reach the site.</summary>
public sealed class StaticFilesTests
{
    [Test]
    public void A_folder_whose_name_starts_with_a_dot_is_copied()
    {
        var source = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        var root = Directory.CreateTempSubdirectory("tsr-site-test-").FullName;
        Directory.CreateDirectory(Path.Combine(source, ".well-known"));
        File.WriteAllText(Path.Combine(source, ".well-known", "apple-app-site-association"), "{}");

        SiteBuilder.CopyStaticFiles(source, root);

        Assert.That(File.ReadAllText(Path.Combine(root, ".well-known", "apple-app-site-association")), Is.EqualTo("{}"));
        Directory.Delete(source, recursive: true);
        Directory.Delete(root, recursive: true);
    }

    [Test]
    public void The_app_link_files_are_in_the_static_folder()
    {
        var folder = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "wwwroot", ".well-known"));

        Assert.Multiple(() =>
        {
            Assert.That(File.Exists(Path.Combine(folder, "apple-app-site-association")), Is.True);
            Assert.That(File.Exists(Path.Combine(folder, "assetlinks.json")), Is.True);
        });
    }
}
