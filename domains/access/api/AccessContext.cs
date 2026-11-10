using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Access.Api;

/// <summary>access's tables, schema "access": the permission catalog, role grants and named user grants.</summary>
internal sealed class AccessContext(DbContextOptions<AccessContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "access";

    public DbSet<PermissionEntry> Permissions => Set<PermissionEntry>();

    public DbSet<RolePermission> RolePermissions => Set<RolePermission>();

    public DbSet<UserPermission> UserPermissions => Set<UserPermission>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<PermissionEntry>(entry =>
        {
            entry.ToTable("permissions");
            entry.HasKey(p => p.Name);
            entry.Property(p => p.Name).HasMaxLength(100);
            entry.Property(p => p.Description).HasMaxLength(255);
        });

        modelBuilder.Entity<RolePermission>(grant =>
        {
            grant.Property(g => g.RoleId).HasColumnName("roleid");
            grant.Property(g => g.Permission).HasMaxLength(100);
            grant.HasKey(g => new { g.RoleId, g.Permission });
            grant.HasOne<PermissionEntry>().WithMany().HasForeignKey(g => g.Permission).OnDelete(DeleteBehavior.Restrict);
        });

        // user_id also references identity.users(id); that foreign key is added by hand in the first
        // migration, because a foreign key may not cross two contexts in the model.
        modelBuilder.Entity<UserPermission>(grant =>
        {
            grant.Property(g => g.Permission).HasMaxLength(100);
            grant.Property(g => g.GrantedAt).HasDefaultValueSql("now()");
            grant.HasIndex(g => new { g.UserId, g.Permission }).HasDatabaseName("idx_user_permissions_user");
            grant.HasOne<PermissionEntry>().WithMany().HasForeignKey(g => g.Permission).OnDelete(DeleteBehavior.Restrict);
        });
    }
}

internal sealed class PermissionEntry
{
    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }
}

internal sealed class RolePermission
{
    public int RoleId { get; set; }

    public string Permission { get; set; } = string.Empty;
}

internal sealed class UserPermission
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public string Permission { get; set; } = string.Empty;

    public int? GrantedBy { get; set; }

    public DateTimeOffset GrantedAt { get; set; }

    public DateTimeOffset? RevokedAt { get; set; }
}
