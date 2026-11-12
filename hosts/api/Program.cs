using Tsr.Access.Api;
using Tsr.Host.Api;
using Tsr.Assessment.Api;
using Tsr.Classes.Api;
using Tsr.Content.Api;
using Tsr.Identity.Api;
using Tsr.Membership.Api;
using Tsr.Notifications.Api;
using Tsr.Platform.Api;
using Tsr.Search.Api;
using Tsr.Shared.Api;

// Composition root: wiring only, never a rule. Each module registers its own services and maps
// its own endpoints; this file decides which modules this host loads and the middleware order.

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration["TSR_DB"]
    ?? throw new InvalidOperationException("TSR_DB is not set. Locally it comes from docker-compose.dev.yml.");

builder.Services.AddSingleton(new DbSettings(connectionString));
builder.Services.AddSingleton(TimeProvider.System);

// The one-off migrate job (below) serves no requests: it registers identity's tables but no caller
// verifier, so it runs in any environment. Normal start-up still fails closed outside Development.
var migrating = args.Contains("--migrate");

// The worker run mode (hosts/api/WorkerMode.cs): background workers named in TSR_WORKERS, no API routes. It loads the same modules as the API, so it needs the same settings. Put --workers LAST on a command line:
// the command line reader takes the argument after a bare switch as its value.
var workerMode = args.Contains("--workers") && !migrating;

var mode = migrating ? RunMode.Migrate : workerMode ? RunMode.Workers : RunMode.Api;
HostServices.AddDomains(builder.Services, builder.Environment, builder.Configuration, mode);

// Only in the worker run mode, and only the workers TSR_WORKERS names; an unknown name stops the start here.
var enabledWorkers = WorkerMode.Register(builder.Services, workerMode, builder.Configuration[WorkerMode.Setting]);

var app = builder.Build();

// One-off migrate job (docker-compose.dev.yml "migrate", a Dokploy job in production): apply every
// domain's migrations in registration order, then exit without serving.
if (migrating)
{
    await app.Services.MigrateDatabasesAsync(CancellationToken.None);
    return;
}

// Worker mode: the hosted workers run; the only route is a health check, so a platform can tell the process is up.
if (workerMode)
{
    WorkerMode.Announce(app.Logger, enabledWorkers);
    app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
    app.Run();
    return;
}

app.UseRouterErrors();
app.UseRouting();
app.UseIdentity();
app.MapIdentity();
app.MapAccess();
app.MapPlatform();
app.MapMembership();
app.MapContent();
app.MapClasses();
app.MapAssessment();
app.MapNotifications();
app.MapSearch();

app.Run();

/// <summary>Entry point, public so tests can host the API in-process.</summary>
public partial class Program;
