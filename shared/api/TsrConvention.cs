using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Microsoft.EntityFrameworkCore.Metadata.Conventions;

namespace Tsr.Shared.Api;

/// <summary>
/// The schema rules every domain gets without writing them per column:
/// snake_case table and column names (a name set explicitly wins), every text column is
/// <c>citext</c> (case-insensitive, as on MariaDB) unless its type is set explicitly (jsonb), and a
/// text column with a length keeps it as <c>CHECK (char_length(col) &lt;= n)</c>, because citext has no citext(n).
/// A column that must be case-sensitive is declared with an explicit column type and a written reason
/// (db/tests/SchemaGuardTests.cs keeps the allow-list).
/// </summary>
internal sealed class TsrConvention : IModelFinalizingConvention
{
    private const string TextType = "citext";

    public void ProcessModelFinalizing(
        IConventionModelBuilder modelBuilder,
        IConventionContext<IConventionModelBuilder> context)
    {
        foreach (var entityType in modelBuilder.Metadata.GetEntityTypes())
        {
            if (entityType.IsOwned() || entityType.BaseType is not null)
            {
                continue;
            }

            ApplyTo(entityType);
        }
    }

    internal static string SnakeCase(string name)
    {
        var result = new System.Text.StringBuilder(name.Length + 4);
        for (var i = 0; i < name.Length; i++)
        {
            var c = name[i];
            if (char.IsUpper(c) && i > 0 && !char.IsUpper(name[i - 1]) && name[i - 1] != '_')
            {
                result.Append('_');
            }

            result.Append(char.ToLowerInvariant(c));
        }

        return result.ToString();
    }

    private static void ApplyTo(IConventionEntityType entityType)
    {
        var table = entityType.GetTableName();
        if (table is null)
        {
            return;
        }

        entityType.Builder.ToTable(SnakeCase(table));
        var tableName = SnakeCase(table);
        foreach (var property in entityType.GetDeclaredProperties())
        {
            property.Builder.HasColumnName(SnakeCase(property.GetColumnName()));
            if (property.ClrType == typeof(string))
            {
                ApplyText(entityType, property, tableName);
            }
        }
    }

    private static void ApplyText(IConventionEntityType entityType, IConventionProperty property, string tableName)
    {
        if (property.GetColumnType() is null)
        {
            property.Builder.HasColumnType(TextType);
        }

        var length = property.GetMaxLength();
        if (length is null || property.GetColumnType() != TextType)
        {
            return;
        }

        var column = property.GetColumnName();
        entityType.Builder.HasCheckConstraint(
            "ck_" + tableName + "_" + column + "_length",
            "char_length(\"" + column + "\") <= " + length.Value.ToString(System.Globalization.CultureInfo.InvariantCulture));
    }
}
