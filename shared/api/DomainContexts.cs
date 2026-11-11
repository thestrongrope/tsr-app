using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace Tsr.Shared.Api;

/// <summary>A registered domain context, in registration order: the order migrations run in.</summary>
internal sealed record MigrationTarget(Type ContextType, string Schema);

/// <summary>
/// Registers each domain's DbContext and applies all domains' migrations (the one-off migrate job),
/// then grants the API's limited role its rights on the domain schemas.
/// </summary>
public static partial class DomainContexts
{
    /// <summary>The limited database role the API connects as. Created by infrastructure (db/init/01-app-role.sql locally).</summary>
    public const string AppRole = "tsr_app";

    private const int TimeoutSeconds = 5;
    private const int MigrationTimeoutSeconds = 300;

    /// <summary>
    /// Registers a domain's context, scoped per request. The migration history table lives in the
    /// domain's own schema. Register domains in dependency order: a domain's migrations may refer to
    /// tables another domain owns, and they run in this order.
    /// </summary>
    public static IServiceCollection AddDomainContext<TContext>(this IServiceCollection services, string schema)
        where TContext : TsrDbContext
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentException.ThrowIfNullOrWhiteSpace(schema);
        if (!SchemaName().IsMatch(schema))
        {
            throw new ArgumentException("A schema name is lowercase letters and underscores only.", nameof(schema));
        }

        services.AddDbContext<TContext>((provider, options) =>
        {
            var settings = provider.GetRequiredService<DbSettings>();
            var connection = new NpgsqlConnectionStringBuilder(settings.ConnectionString)
            {
                Timeout = TimeoutSeconds,
                CommandTimeout = TimeoutSeconds,
            };
            options.UseNpgsql(
                connection.ConnectionString,
                npgsql => npgsql.MigrationsHistoryTable("__ef_migrations_history", schema));
        });
        services.AddSingleton(new MigrationTarget(typeof(TContext), schema));
        return services;
    }

    /// <summary>
    /// Applies every registered domain's pending migrations, in registration order, then grants
    /// <see cref="AppRole"/> select/insert/update/delete on each schema's tables and usage on its sequences,
    /// with default privileges so tables a later migration creates are covered. Idempotent. Run as the owner role.
    /// </summary>
    public static async Task MigrateDatabasesAsync(this IServiceProvider services, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(services);
        await using var scope = services.CreateAsyncScope();
        foreach (var target in scope.ServiceProvider.GetServices<MigrationTarget>())
        {
            var context = (DbContext)scope.ServiceProvider.GetRequiredService(target.ContextType);
            context.Database.SetCommandTimeout(TimeSpan.FromSeconds(MigrationTimeoutSeconds));
            await context.Database.MigrateAsync(ct);
            await GrantAppRoleAsync(context, target.Schema, ct);
        }
    }

    // The schema is checked against SchemaName() when the domain is registered; the role is a constant.
    // Identifiers cannot be SQL parameters.
    private static async Task GrantAppRoleAsync(DbContext context, string schema, CancellationToken ct)
    {
        var connection = context.Database.GetDbConnection();
        await context.Database.OpenConnectionAsync(ct);
        try
        {
            await using var command = connection.CreateCommand();
            command.CommandText =
                $"""
                GRANT USAGE ON SCHEMA "{schema}" TO {AppRole};
                GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA "{schema}" TO {AppRole};
                GRANT USAGE ON ALL SEQUENCES IN SCHEMA "{schema}" TO {AppRole};
                ALTER DEFAULT PRIVILEGES IN SCHEMA "{schema}" GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {AppRole};
                ALTER DEFAULT PRIVILEGES IN SCHEMA "{schema}" GRANT USAGE ON SEQUENCES TO {AppRole};
                REVOKE ALL ON "{schema}".__ef_migrations_history FROM {AppRole};
                -- A published view is read-only to the API role (domains/CLAUDE.md rule 2): the blanket grant above also covers views.
                DO $$
                DECLARE v text;
                BEGIN
                    FOR v IN SELECT quote_ident(schemaname) || '.' || quote_ident(viewname) FROM pg_views WHERE schemaname = '{schema}' LOOP
                        EXECUTE 'REVOKE ALL ON ' || v || ' FROM {AppRole}';
                        EXECUTE 'GRANT SELECT ON ' || v || ' TO {AppRole}';
                    END LOOP;
                END $$;
                """;
            command.CommandTimeout = MigrationTimeoutSeconds;
            await command.ExecuteNonQueryAsync(ct);
        }
        finally
        {
            await context.Database.CloseConnectionAsync();
        }
    }

    [GeneratedRegex("^[a-z_]+$")]
    private static partial Regex SchemaName();
}
