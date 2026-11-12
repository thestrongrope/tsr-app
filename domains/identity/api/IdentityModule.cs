using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using Tsr.Identity.Api.Features.AdminDeletionComplete;
using Tsr.Identity.Api.Features.AdminDeletionConfirmationSent;
using Tsr.Identity.Api.Features.AdminDeletionHold;
using Tsr.Identity.Api.Features.AdminDeletionList;
using Tsr.Identity.Api.Features.AdminDeletionRaise;
using Tsr.Identity.Api.Features.DebugToken;
using Tsr.Identity.Api.Features.DeletionRequestCancel;
using Tsr.Identity.Api.Features.DeletionRequestCreate;
using Tsr.Identity.Api.Features.DeletionRequestGet;
using Tsr.Identity.Api.Features.LinkAccount;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>identity (AuthN): who is calling. Public interface of the module.</summary>
public static class IdentityModule
{
    /// <summary>
    /// Other domain modules this one may use (domains/CLAUDE.md rule 7): access (permissions of the deletion routes), platform and notifications (the erasure commands
    /// of account deletion). It also reads <c>membership.v_members</c> (a published view, no reference): membership references identity, so membership is not listed;
    /// it supplies <see cref="IMemberErasure"/> instead.
    /// </summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access", "platform", "notifications"];

    /// <summary>
    /// Registers only identity's tables, for the one-off migrate job, which serves no requests and
    /// so needs no Firebase settings. The API itself starts with <see cref="AddIdentity"/>.
    /// </summary>
    public static IServiceCollection AddIdentityTables(this IServiceCollection services)
    {
        services.AddDomainContext<IdentityContext>(IdentityContext.SchemaName);
        return services;
    }

    /// <summary>
    /// Registers sign-in. Fails closed: without a Firebase project id, or with the emulator on outside
    /// Development, this throws and the API does not start (<see cref="FirebaseSettings"/>).
    /// </summary>
    public static IServiceCollection AddIdentity(this IServiceCollection services, IHostEnvironment env, IConfiguration configuration)
    {
        var settings = FirebaseSettings.Create(configuration, env);
        services.AddIdentityTables();
        services.AddFirebaseVerification(settings);
        services.AddScoped<MemberDirectory>();
        services.TryAddScoped<IProfileSink, NoProfileSink>();
        services.TryAddScoped<IMemberErasure, NoMemberErasure>();
        services.TryAddSingleton<MemberRateLimit>();
        AddFirebaseAccounts(services, settings, configuration);
        services.AddScoped(provider => new UserDirectory(provider.GetRequiredService<IdentityContext>()));
        return services;
    }

    // Which Firebase deleter: the emulator's no-op in emulator mode; the real client when the service account is set; otherwise one that refuses (PHP without its credentials).
    private static void AddFirebaseAccounts(IServiceCollection services, FirebaseSettings settings, IConfiguration configuration)
    {
        if (settings.UseEmulator)
        {
            services.AddSingleton<IFirebaseAccounts, EmulatorFirebaseAccounts>();
            return;
        }

        var encoded = configuration[GoogleFirebaseAccounts.SettingKey];
        if (string.IsNullOrWhiteSpace(encoded))
        {
            services.AddSingleton<IFirebaseAccounts, UnconfiguredFirebaseAccounts>();
            return;
        }

        var account = GoogleServiceAccount.Parse(encoded);
        services.AddHttpClient(GoogleFirebaseAccounts.ClientName, client => client.Timeout = TimeSpan.FromSeconds(10));
        services.AddSingleton<IFirebaseAccounts>(provider => new GoogleFirebaseAccounts(
            provider.GetRequiredService<IHttpClientFactory>(), account, settings.ProjectId, provider.GetRequiredService<TimeProvider>()));
    }

    public static IApplicationBuilder UseIdentity(this IApplicationBuilder app) =>
        app.UseMiddleware<CallerMiddleware>();

    public static IEndpointRouteBuilder MapIdentity(this IEndpointRouteBuilder routes)
    {
        routes.MapLinkAccount();
        routes.MapDebugToken();
        routes.MapDeletionRequestCreate();
        routes.MapDeletionRequestGet();
        routes.MapDeletionRequestCancel();
        routes.MapAdminDeletionList();
        routes.MapAdminDeletionRaise();
        routes.MapAdminDeletionHold();
        routes.MapAdminDeletionConfirmationSent();
        routes.MapAdminDeletionComplete();
        return routes;
    }
}
