namespace Tsr.Shared.Api;

/// <summary>
/// Text of the CHECK constraints the domain contexts share. Enums and SETs of MariaDB become text with a CHECK listing
/// the values; a JSON column kept as text keeps MariaDB's <c>json_valid</c> guarantee. Values are code constants, never input.
/// </summary>
public static class CheckSql
{
    /// <summary>A CHECK that the column holds one of the values. A NULL passes, as a nullable MariaDB enum accepts NULL.</summary>
    public static string In(string column, params string[] values)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(column);
        return column + " in (" + string.Join(", ", values.Select(v => "'" + v.Replace("'", "''", StringComparison.Ordinal) + "'")) + ")";
    }

    /// <summary>A CHECK that the column holds valid JSON. The column is citext, so it is read as text first.</summary>
    public static string IsJson(string column)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(column);
        return column + "::text is json";
    }
}
