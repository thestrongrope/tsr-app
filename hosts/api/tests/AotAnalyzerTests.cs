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
        Assert.That(AnalyzerProblems(File.ReadAllText(file)), Is.Empty, $"{project} must keep the analyzer plain");
    }

    [TestCase("<Project><PropertyGroup><NoWarn>$(NoWarn);IL2026</NoWarn></PropertyGroup></Project>")]
    [TestCase("<Project><PropertyGroup><WarningsNotAsErrors>IL3050</WarningsNotAsErrors></PropertyGroup></Project>")]
    [TestCase("<Project><PropertyGroup><NoWarn>CS1591;IL2104</NoWarn></PropertyGroup></Project>")]
    [TestCase("<Project><PropertyGroup><IsAotCompatible Condition=\"'$(CI)' == ''\">true</IsAotCompatible></PropertyGroup></Project>")]
    [TestCase("<Project><PropertyGroup Condition=\"'$(Configuration)' == 'Release'\"><IsAotCompatible>true</IsAotCompatible></PropertyGroup></Project>")]
    public void A_project_that_hides_or_conditions_the_analyzer_is_reported(string project) =>
        Assert.That(AnalyzerProblems(project), Is.Not.Empty);

    [TestCase("<Project><PropertyGroup><IsAotCompatible>true</IsAotCompatible><NoWarn>CS1591</NoWarn></PropertyGroup></Project>")]
    [TestCase("<Project><PropertyGroup><WarningsNotAsErrors>CS0618</WarningsNotAsErrors></PropertyGroup></Project>")]
    [TestCase("<Project><PropertyGroup><IsAotCompatible>true</IsAotCompatible></PropertyGroup><PropertyGroup Condition=\"'$(Configuration)' == 'Debug'\"><DebugType>full</DebugType></PropertyGroup></Project>")]
    public void A_project_that_keeps_the_analyzer_plain_is_not_reported(string project) =>
        Assert.That(AnalyzerProblems(project), Is.Empty);

    /// <summary>What would hide the analyzer in a project file: an IL code in NoWarn or WarningsNotAsErrors, or a Condition on the IsAotCompatible element or its PropertyGroup.</summary>
    internal static IReadOnlyList<string> AnalyzerProblems(string projectText)
    {
        var problems = new List<string>();
        var document = XDocument.Parse(projectText);
        foreach (var element in document.Descendants().Where(e => e.Name.LocalName is "NoWarn" or "WarningsNotAsErrors"))
        {
            if (System.Text.RegularExpressions.Regex.IsMatch(element.Value, @"\bIL\d{4}\b"))
            {
                problems.Add($"<{element.Name.LocalName}> names an IL code: {element.Value.Trim()}");
            }
        }

        foreach (var aot in document.Descendants("IsAotCompatible"))
        {
            if (aot.Attribute("Condition") is not null || aot.Parent?.Attribute("Condition") is not null)
            {
                problems.Add("IsAotCompatible has a Condition, on itself or on its PropertyGroup");
            }
        }

        return problems;
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

    /// <summary>CMD-R12: the bridge to Entity Framework carries the reflection attributes, so a converted domain that calls it fails its own build.</summary>
    [Test]
    public async Task The_ef_bridge_fails_the_build_where_the_analyzer_is_on()
    {
        var shared = Path.Combine(RouteCatalog.RepoRoot(), "shared", "api", "Tsr.Shared.Api.csproj");
        var project = $$"""
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup>
                <IsAotCompatible>true</IsAotCompatible>
              </PropertyGroup>
              <ItemGroup>
                <FrameworkReference Include="Microsoft.AspNetCore.App" />
                <ProjectReference Include="{{shared}}" />
              </ItemGroup>
            </Project>
            """;
        const string source = """
            namespace Canary;

            public static class Bridge
            {
                public static Tsr.Shared.Api.DbTx Run(Microsoft.EntityFrameworkCore.DbContext db) => Tsr.Shared.Api.EfTransaction.Join(db);
            }
            """;

        var result = await BuildAsync("ef-bridge", project, source);

        Assert.That(result.ExitCode, Is.Not.Zero, result.Output);
        Assert.That(result.Output, Does.Contain("IL2026"));
        Assert.That(result.Output, Does.Contain("IL3050"));
    }

    /// <summary>
    /// AOT-R2: a slice in the converted form (declared parameters, the request delegate generator on the project, a body read through the shared reader,
    /// a write on DbTx with an outbox event, answers through a source-generated context) builds with no AOT or trim warning in a class library.
    /// </summary>
    [Test]
    public async Task A_slice_that_reads_a_body_builds_with_no_aot_warning()
    {
        var shared = Path.Combine(RouteCatalog.RepoRoot(), "shared", "api", "Tsr.Shared.Api.csproj");
        var project = $$"""
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup>
                <IsAotCompatible>true</IsAotCompatible>
                <EnableRequestDelegateGenerator>true</EnableRequestDelegateGenerator>
              </PropertyGroup>
              <ItemGroup>
                <FrameworkReference Include="Microsoft.AspNetCore.App" />
                <ProjectReference Include="{{shared}}" />
              </ItemGroup>
            </Project>
            """;

        var result = await BuildAsync("slice", project, SliceSource);

        Assert.That(result.ExitCode, Is.Zero, result.Output);
        Assert.That(result.Output, Does.Not.Contain("warning IL"), result.Output);
        Assert.That(result.Output, Does.Not.Contain("error"), result.Output);
    }

    private const string SliceSource = """
        using System.Text.Json;
        using System.Text.Json.Serialization;
        using Microsoft.AspNetCore.Builder;
        using Microsoft.AspNetCore.Http;
        using Microsoft.AspNetCore.Routing;
        using Npgsql;
        using Tsr.Shared.Api;

        namespace Canary;

        internal sealed record Granted(int Id, string Name);

        internal sealed record GrantedEvent(int Id, string Name);

        [JsonSourceGenerationOptions(JsonSerializerDefaults.Web)]
        [JsonSerializable(typeof(Granted))]
        [JsonSerializable(typeof(GrantedEvent))]
        internal sealed partial class CanaryJson : JsonSerializerContext;

        public static class CanarySlice
        {
            public static IEndpointRouteBuilder MapCanary(this IEndpointRouteBuilder routes)
            {
                routes.MapPost("/canary/{token}", HandleAsync);
                return routes;
            }

            private static async Task<IResult> HandleAsync(string token, HttpRequest request, NpgsqlDataSource db, TimeProvider clock, CancellationToken ct)
            {
                var (body, refusal) = await RequestBodies.ReadAsync(request, ct);
                if (refusal is not null)
                {
                    return refusal;
                }

                var name = body!.Get("name").GetString();
                if (string.IsNullOrEmpty(name))
                {
                    return Problem.Detail(StatusCodes.Status422UnprocessableEntity, "name is required");
                }

                await using var tx = await db.BeginAsync(ct);
                var id = await tx.ScalarAsync<int>($"insert into canary.grants (token, name) values ({token}, {name}) returning id", ct);
                await Outbox.WriteAsync(tx, "canary.granted", new GrantedEvent(id!.Value, name), CanaryJson.Default.GrantedEvent, clock, ct);
                await tx.CommitAsync(ct);
                return Results.Json(new Granted(id.Value, name), CanaryJson.Default.Granted);
            }
        }
        """;

    private static Task<(int ExitCode, string Output)> BuildAsync(string name, string member) =>
        BuildAsync(
            name,
            "<Project Sdk=\"Microsoft.NET.Sdk\"><PropertyGroup><IsAotCompatible>true</IsAotCompatible></PropertyGroup></Project>",
            $"namespace Canary;{Environment.NewLine}public static class Probe{Environment.NewLine}{{{Environment.NewLine}    {member}{Environment.NewLine}}}{Environment.NewLine}");

    // The folder is gitignored (obj/) and inside the repo, so the project picks up Directory.Build.props and Directory.Packages.props.
    private static async Task<(int ExitCode, string Output)> BuildAsync(string name, string projectFile, string source)
    {
        var folder = Path.Combine(RouteCatalog.RepoRoot(), "hosts", "api", "tests", "obj", "aot-canary", name);
        Directory.CreateDirectory(folder);
        await File.WriteAllTextAsync(Path.Combine(folder, "Canary.csproj"), projectFile);
        await File.WriteAllTextAsync(Path.Combine(folder, "Canary.cs"), source);

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
