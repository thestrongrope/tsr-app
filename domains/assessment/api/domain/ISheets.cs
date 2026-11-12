namespace Tsr.Assessment.Api.Domain;

/// <summary>
/// Google Sheets behind one interface, at the boundary: the standard MCQ source sheet and the quiz competition sheets are read and written only through it
/// (PHP's <c>GoogleSheetsHelper</c>, functions.php:915). The real implementation is <see cref="GoogleSheets"/>; unit tests use a fake. Every failure is a <see cref="SheetsException"/>.
/// </summary>
internal interface ISheets
{
    /// <summary>The cells of an A1 range (for example <c>English-Abuzar!A2:M</c>) as text, row by row; a row ends at its last non-empty cell, a range with no values is an empty list.</summary>
    Task<IReadOnlyList<IReadOnlyList<string>>> ReadAsync(string spreadsheetId, string range, CancellationToken ct);
}

/// <summary>Any failure of a sheet call: not configured, token refused, timeout, a non-success answer. The message never holds a credential, a token or sheet content.</summary>
internal sealed class SheetsException : Exception
{
    public SheetsException(string message)
        : base(message)
    {
    }

    public SheetsException(string message, Exception inner)
        : base(message, inner)
    {
    }
}
