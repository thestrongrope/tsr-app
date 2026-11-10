using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Access.Api;

/// <summary>
/// access's tables, schema "access": the roles, the permission catalog, what each role grants, named grants to
/// one user, each user's role, and the class access rules. Column names follow PHP's, so the data move is a copy.
/// </summary>
internal sealed class AccessContext(DbContextOptions<AccessContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "access";

    public DbSet<Role> Roles => Set<Role>();

    public DbSet<PermissionEntry> Permissions => Set<PermissionEntry>();

    public DbSet<RolePermission> RolePermissions => Set<RolePermission>();

    public DbSet<UserPermission> UserPermissions => Set<UserPermission>();

    public DbSet<UserRole> UserRoles => Set<UserRole>();

    public DbSet<ClassAccessRule> ClassAccessRules => Set<ClassAccessRule>();

    public DbSet<ClassAccessRuleCondition> ClassAccessRuleConditions => Set<ClassAccessRuleCondition>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Role>(role =>
        {
            role.Property(r => r.Id).ValueGeneratedNever();
            role.Property(r => r.Name).HasMaxLength(30);
        });

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
            grant.HasOne<Role>().WithMany().HasForeignKey(g => g.RoleId).OnDelete(DeleteBehavior.Restrict);
        });

        // user_id is a plain id: another domain's table is never referenced by a foreign key (domains/CLAUDE.md).
        modelBuilder.Entity<UserPermission>(grant =>
        {
            grant.Property(g => g.Permission).HasMaxLength(100);
            grant.Property(g => g.Reason).HasMaxLength(300);
            grant.Property(g => g.RevokeReason).HasMaxLength(300);
            grant.Property(g => g.GrantedAt).HasDefaultValueSql("now()");
            grant.HasIndex(g => new { g.UserId, g.Permission }).HasDatabaseName("idx_user_permissions_user");
            grant.HasOne<PermissionEntry>().WithMany().HasForeignKey(g => g.Permission).OnDelete(DeleteBehavior.Restrict);
        });

        // One row per user whose role is not 0 (a member). user_id is a plain id; no foreign key to identity.
        modelBuilder.Entity<UserRole>(userRole =>
        {
            userRole.HasKey(u => u.UserId);
            userRole.Property(u => u.UserId).ValueGeneratedNever();
            userRole.Property(u => u.RoleId).HasColumnName("roleid");
            userRole.HasOne<Role>().WithMany().HasForeignKey(u => u.RoleId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ClassAccessRule>(rule =>
        {
            rule.Property(r => r.Note).HasMaxLength(255);
            rule.Property(r => r.Reason).HasMaxLength(300);
            rule.Property(r => r.RevokeReason).HasMaxLength(300);
            rule.Property(r => r.CreatedAt).HasDefaultValueSql("now()");
            rule.HasIndex(r => r.Token).HasDatabaseName("idx_class_access_rules_token");
            rule.ToTable(t => t.HasCheckConstraint("ck_class_access_rules_gender", "gender in (1, 2)"));
        });

        modelBuilder.Entity<ClassAccessRuleCondition>(condition =>
        {
            condition.Property(c => c.Field).HasMaxLength(20);
            condition.Property(c => c.Value).HasMaxLength(300);
            condition.HasOne<ClassAccessRule>().WithMany().HasForeignKey(c => c.RuleId).OnDelete(DeleteBehavior.Restrict);
            condition.HasIndex(c => c.RuleId).HasDatabaseName("idx_class_access_rule_conditions_rule");
            condition.ToTable(t =>
            {
                t.HasCheckConstraint("ck_class_access_rule_conditions_field", "field in ('city', 'country', 'level', 'tag')");
                t.HasCheckConstraint(
                    "ck_class_access_rule_conditions_value",
                    "(field = 'level' and level_id is not null and value is null) or (field <> 'level' and value is not null and level_id is null)");
            });
        });
    }
}

internal sealed class Role
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;
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

    public string? Reason { get; set; }

    public DateTimeOffset? RevokedAt { get; set; }

    public int? RevokedBy { get; set; }

    public string? RevokeReason { get; set; }
}

internal sealed class UserRole
{
    public int UserId { get; set; }

    public int RoleId { get; set; }
}

internal sealed class ClassAccessRule
{
    public int Id { get; set; }

    public int Token { get; set; }

    public int? Gender { get; set; }

    public string Note { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }

    public int? GrantedBy { get; set; }

    public string? Reason { get; set; }

    public DateTimeOffset? RevokedAt { get; set; }

    public int? RevokedBy { get; set; }

    public string? RevokeReason { get; set; }
}

internal sealed class ClassAccessRuleCondition
{
    public int Id { get; set; }

    public int RuleId { get; set; }

    public string Field { get; set; } = string.Empty;

    public bool Negate { get; set; }

    public string? Value { get; set; }

    public int? LevelId { get; set; }
}
