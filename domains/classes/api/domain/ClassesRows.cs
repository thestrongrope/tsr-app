using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>Small helpers over the data source that several of this domain's reads repeat: "is there a row".</summary>
internal static class ClassesRows
{
    /// <summary>True when the select returns at least one row. The select names one column <c>"Value"</c>, typed int.</summary>
    public static async Task<bool> AnyAsync(this NpgsqlDataSource source, Sql sql, CancellationToken ct) =>
        (await source.ListAsync(sql, row => row.Int("Value"), ct)).Count > 0;

    /// <summary>As <see cref="AnyAsync(NpgsqlDataSource, Sql, CancellationToken)"/>, on the caller's transaction.</summary>
    public static async Task<bool> AnyAsync(this DbTx tx, Sql sql, CancellationToken ct) =>
        (await tx.ListAsync(sql, row => row.Int("Value"), ct)).Count > 0;

    /// <summary>
    /// A nullable <c>date</c> column selected as <c>col::text</c> (ISO <c>yyyy-MM-dd</c>): <c>DbRow</c> has no nullable date reader.
    /// </summary>
    public static DateOnly? DateOrNull(string? isoText) =>
        isoText is null ? null : DateOnly.ParseExact(isoText, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);

    /// <summary><see cref="PhpDateBound.Bound"/> as an instant (the bound is already UTC), the type a <c>timestamptz</c> parameter takes.</summary>
    public static DateTimeOffset? Bound(string? raw) => PhpDateBound.Bound(raw) is { } bound ? new DateTimeOffset(bound) : null;
}
