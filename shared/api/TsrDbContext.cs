using Microsoft.EntityFrameworkCore;

namespace Tsr.Shared.Api;

/// <summary>
/// Base of every domain's DbContext: one context and one PostgreSQL schema per domain, so every table
/// has one owner. The conventions (snake_case names, citext text) are applied here, never per column.
/// </summary>
public abstract class TsrDbContext(DbContextOptions options, string schema) : DbContext(options)
{
    protected sealed override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        ArgumentNullException.ThrowIfNull(configurationBuilder);
        base.ConfigureConventions(configurationBuilder);
        configurationBuilder.Conventions.Add(_ => new TsrConvention());
    }

    protected sealed override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ArgumentNullException.ThrowIfNull(modelBuilder);
        modelBuilder.HasDefaultSchema(schema);
        modelBuilder.HasPostgresExtension("citext");
        Configure(modelBuilder);
    }

    /// <summary>The domain's own tables, keys, indexes and column names that differ from snake_case.</summary>
    protected abstract void Configure(ModelBuilder modelBuilder);
}
