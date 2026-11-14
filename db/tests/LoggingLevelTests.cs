using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NUnit.Framework;

namespace Tsr.Db.Tests;

/// <summary>
/// The API's log levels when no setting names one: the framework at Warning, the project's own lines at Information.
/// At Information the framework writes every SQL command of every request, which cost about a third of the throughput in the load test of 14 Nov 2026.
/// </summary>
[TestFixture]
public sealed class LoggingLevelTests
{
    [TestCase("Microsoft.EntityFrameworkCore.Database.Command")]
    [TestCase("Microsoft.AspNetCore.Hosting.Diagnostics")]
    [TestCase("Microsoft.AspNetCore.Routing.EndpointMiddleware")]
    [TestCase("System.Net.Http.HttpClient.youtube-feed.LogicalHandler")]
    public void The_framework_logs_warnings_and_not_information(string category)
    {
        using var api = TestApi.Create();
        var logger = api.Services.GetRequiredService<ILoggerFactory>().CreateLogger(category);

        Assert.That(logger.IsEnabled(LogLevel.Information), Is.False);
        Assert.That(logger.IsEnabled(LogLevel.Warning), Is.True);
    }

    [TestCase("Tsr.Content.Api.Domain.ContentRefresh")]
    [TestCase("Microsoft.Hosting.Lifetime")]
    public void The_project_s_own_lines_and_the_start_and_stop_lines_stay_at_information(string category)
    {
        using var api = TestApi.Create();
        var logger = api.Services.GetRequiredService<ILoggerFactory>().CreateLogger(category);

        Assert.That(logger.IsEnabled(LogLevel.Information), Is.True);
    }

    [Test]
    public void A_setting_still_decides_when_it_names_a_level()
    {
        using var api = TestApi.Create().WithWebHostBuilder(builder =>
            builder.UseSetting("Logging:LogLevel:Microsoft.EntityFrameworkCore.Database.Command", "Information"));
        var logger = api.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Microsoft.EntityFrameworkCore.Database.Command");

        Assert.That(logger.IsEnabled(LogLevel.Information), Is.True);
    }
}
