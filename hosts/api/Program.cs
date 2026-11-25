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
HostLogging.AddDefaults(builder.Configuration);

// The server's own cap on a request body, for a route that forgets the bounded reader (shared/api/RequestBodies.cs). Twice the slices' limit, so a
// body between the two still gets the slice's 413 with its detail. Production has no proxy of its own that caps the body.
builder.WebHost.ConfigureKestrel(options => options.Limits.MaxRequestBodySize = 2L * RequestBodies.MaxBytes);

// The one-off migrate job (below) serves no requests: it registers identity's tables but no caller
// verifier, so it runs in any environment. Normal start-up still fails closed outside Development.
// The native build has no Entity Framework: it refuses the migrate job before it reads any other setting (HostServices.CanMigrate).
var migrating = args.Contains("--migrate");
if (migrating && !HostServices.CanMigrate)
{
    throw new InvalidOperationException(HostServices.NoMigrations);
}

var connectionString = builder.Configuration["TSR_DB"]
    ?? throw new InvalidOperationException("TSR_DB is not set. Locally it comes from docker-compose.dev.yml.");

builder.Services.AddSingleton(new DbSettings(connectionString));
builder.Services.AddSingleton(TimeProvider.System);

// The one-off content load (docker-compose.yml "content-load"): copy the content files at TSR_CONTENT_DIR into the database, then exit; no routes. --migrate wins if both are given.
var loadingContent = args.Contains("--load-content") && !migrating;

// The worker run mode (hosts/api/WorkerMode.cs): background workers named in TSR_WORKERS, no API routes. It loads the same modules as the API, so it needs the same settings. Put --workers LAST on a command line:
// the command line reader takes the argument after a bare switch as its value.
var workerMode = args.Contains("--workers") && !migrating && !loadingContent;

var mode = migrating ? RunMode.Migrate : loadingContent ? RunMode.LoadContent : workerMode ? RunMode.Workers : RunMode.Api;
HostServices.AddDomains(builder.Services, builder.Environment, builder.Configuration, mode);

// Only in the worker run mode, and only the workers TSR_WORKERS names; an unknown name stops the start here.
var enabledWorkers = WorkerMode.Register(builder.Services, workerMode, builder.Configuration[WorkerMode.Setting]);

// The browser origins that may call the API (hosts/api/CorsSetting.cs). None listed, the default: no CORS middleware at all.
var corsEnabled = CorsSetting.Register(builder.Services, builder.Configuration[CorsSetting.Name]);

var app = builder.Build();

// One-off migrate job (docker-compose.dev.yml "migrate", a Dokploy job in production): apply every
// domain's migrations in registration order, then exit without serving.
if (migrating)
{
    await HostServices.MigrateAsync(app.Services, CancellationToken.None);
    return;
}

// Content load: one refresh, bounded to 5 minutes. Exit 0 when the tables now hold the files (or already did), 1 when the last set was kept.
if (loadingContent)
{
    using var loadTimeout = new CancellationTokenSource(TimeSpan.FromMinutes(5));
    if (!await ContentModule.LoadContentAsync(app.Services, loadTimeout.Token))
    {
        Environment.ExitCode = 1;
    }

    // The console logger writes from a queue: disposing the host flushes it, so the line that says why a load failed is not lost.
    await app.DisposeAsync();

    return;
}

// Worker mode: the hosted workers run; the only route is a health check, so a platform can tell the process is up.
if (workerMode)
{
    WorkerMode.Announce(app.Logger, enabledWorkers);
    // Fixed text, not a serialised object: the native build has no reflection writer (the API's own /health is platform's slice).
    app.MapGet("/health", () => Results.Content("{\"status\":\"ok\"}", "application/json; charset=utf-8"));
    app.Run();
    return;
}

app.UseRouterErrors();

// Before sign-in: a browser's preflight request carries no token, and a refusal (401) must carry the permission too, or the page
// cannot read why it was refused.
if (corsEnabled)
{
    app.UseCors();
}

app.UseRouting();
app.UseIdentity();
app.UsePermissionsRevision();
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
