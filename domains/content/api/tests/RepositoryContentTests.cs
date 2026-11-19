using NUnit.Framework;

namespace Tsr.Content.Api.Tests;

/// <summary>The guard over the repository's own <c>content/</c> folder (LIB-R27, LIB-R28, LIB-R31). Run it before <c>content/</c> is committed.</summary>
public sealed class RepositoryContentTests
{
    [Test]
    public void The_repository_content_has_no_problem()
    {
        var directory = System.IO.Path.Combine(RepositoryRoot(), "content");

        var problems = ContentGuard.Problems(directory);

        Assert.That(problems, Is.Empty, "content/ holds problems (import it with tools/content-import.sh):\n" + string.Join('\n', problems.Take(50)));
    }

    private static string RepositoryRoot()
    {
        for (var folder = new DirectoryInfo(TestContext.CurrentContext.TestDirectory); folder is not null; folder = folder.Parent)
        {
            if (File.Exists(System.IO.Path.Combine(folder.FullName, "TsrApp.slnx")))
            {
                return folder.FullName;
            }
        }

        throw new InvalidOperationException("TsrApp.slnx was not found above the test folder");
    }
}
