using System.Diagnostics;
using System.Xml.Linq;
using NUnit.Framework;

namespace Tsr.Host.Api.Tests;

/// <summary>
/// AOT-R7: a project that must stay free of reflection sets IsAotCompatible, so the trim and AOT analyzers
/// fail its build (TreatWarningsAsErrors). The canary proves the mechanism once, without a committed fixture project.
/// </summary>
public sealed class AotAnalyzerTests
{
    private const int BuildTimeoutSeconds = 120;

    // Each domain issue adds its own project here when it converts.
    private static readonly string[] AotProjects = ["shared/api/Tsr.Shared.Api.csproj"];

    [TestCaseSource(nameof(AotProjects))]
    public void Each_listed_project_has_the_aot_analyzer_on(string project)
    {
        var file = Path.Combine(RouteCatalog.RepoRoot(), project);
        Assert.That(file, Does.Exist);

        var value = XDocument.Load(file).Descendants("IsAotCompatible").Select(e => e.Value.Trim()).SingleOrDefault();

        Assert.That(value, Is.EqualTo("true"), $"{project} must set <IsAotCompatible>true</IsAotCompatible>");
    }

    [Test]
    public async Task A_reflection_call_fails_the_build_where_the_analyzer_is_on()
    {
        var control = await BuildAsync("control", "public static string Run(int value) => value.ToString(System.Globalization.CultureInfo.InvariantCulture);");
        var canary = await BuildAsync("reflection", "public static string Run(object value) => System.Text.Json.JsonSerializer.Serialize(value);");

        Assert.That(control.ExitCode, Is.Zero, $"The control must build, or the canary proves nothing:{Environment.NewLine}{control.Output}");
        Assert.That(canary.ExitCode, Is.Not.Zero, canary.Output);
        Assert.That(canary.Output, Does.Contain("IL2026"));
    }

    // The folder is gitignored (obj/) and inside the repo, so the project picks up Directory.Build.props and Directory.Packages.props.
    private static async Task<(int ExitCode, string Output)> BuildAsync(string name, string member)
    {
        var folder = Path.Combine(RouteCatalog.RepoRoot(), "hosts", "api", "tests", "obj", "aot-canary", name);
        Directory.CreateDirectory(folder);
        await File.WriteAllTextAsync(Path.Combine(folder, "Canary.csproj"),
            "<Project Sdk=\"Microsoft.NET.Sdk\"><PropertyGroup><IsAotCompatible>true</IsAotCompatible></PropertyGroup></Project>");
        await File.WriteAllTextAsync(Path.Combine(folder, "Canary.cs"),
            $"namespace Canary;{Environment.NewLine}public static class Probe{Environment.NewLine}{{{Environment.NewLine}    {member}{Environment.NewLine}}}{Environment.NewLine}");

        var start = new ProcessStartInfo("dotnet", ["build", Path.Combine(folder, "Canary.csproj"), "--nologo", "-nodeReuse:false"])
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        using var process = Process.Start(start) ?? throw new InvalidOperationException("dotnet did not start.");
        var output = process.StandardOutput.ReadToEndAsync();
        var error = process.StandardError.ReadToEndAsync();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(BuildTimeoutSeconds));
        try
        {
            await process.WaitForExitAsync(timeout.Token);
        }
        catch (OperationCanceledException)
        {
            process.Kill(entireProcessTree: true);
            throw new TimeoutException($"dotnet build did not finish in {BuildTimeoutSeconds} s.");
        }
        return (process.ExitCode, await output + await error);
    }
}
