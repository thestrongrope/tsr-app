using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Identity.Api;

/// <summary>identity's tables, schema "identity". Owns the <c>users</c> row (a sample slice of production's).</summary>
internal sealed class IdentityContext(DbContextOptions<IdentityContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "identity";

    public DbSet<User> Users => Set<User>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(user =>
        {
            user.Property(u => u.RoleId).HasColumnName("roleid");
            user.Property(u => u.Email).HasMaxLength(255);
            user.HasIndex(u => u.Token).HasDatabaseName("idx_users_token");
        });
    }
}

internal sealed class User
{
    public int Id { get; set; }

    public int Token { get; set; }

    public int RoleId { get; set; }

    public short? Gender { get; set; }

    public string? Email { get; set; }
}
