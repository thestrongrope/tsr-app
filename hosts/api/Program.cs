using Tsr.Access.Api;
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

// Registration order is migration order: identity owns users, which other domains reference.
if (migrating)
{
    builder.Services.AddIdentityTables();
}
else
{
    builder.Services.AddIdentity(builder.Environment, builder.Configuration);
}

builder.Services.AddAccess();
builder.Services.AddPlatform();
builder.Services.AddMembership();
builder.Services.AddContent();
// Tables only so far (schema phase); registered after platform, whose migration creates the collation classes uses.
builder.Services.AddClasses();
builder.Services.AddAssessment();
builder.Services.AddNotifications();
builder.Services.AddSearch();

var app = builder.Build();

// One-off migrate job (docker-compose.dev.yml "migrate", a Dokploy job in production): apply every
// domain's migrations in registration order, then exit without serving.
if (migrating)
{
    await app.Services.MigrateDatabasesAsync(CancellationToken.None);
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
