using Tsr.Access.Api;
using Tsr.Content.Api;
using Tsr.Identity.Api;
using Tsr.Platform.Api;
using Tsr.Shared.Api;

// Composition root: wiring only, never a rule. Each module registers its own services and maps
// its own endpoints; this file decides which modules this host loads and the middleware order.

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration["TSR_DB"]
    ?? throw new InvalidOperationException("TSR_DB is not set. Locally it comes from docker-compose.dev.yml.");

builder.Services.AddSingleton(new Db(connectionString));
builder.Services.AddSingleton(TimeProvider.System);

builder.Services.AddIdentity(builder.Environment);
builder.Services.AddAccess();
builder.Services.AddPlatform();
builder.Services.AddContent();

var app = builder.Build();

app.UseIdentity();
app.MapPlatform();
app.MapContent();

app.Run();

/// <summary>Entry point, public so tests can host the API in-process.</summary>
public partial class Program;
