using System.Data.Common;
using System.Diagnostics.CodeAnalysis;

namespace Tsr.Shared.Api;

/// <summary>
/// One row of a query, read by column name. A row reader reads every selected column once and never lets a value decide which columns it reads;
/// the count of columns read is compared with the count selected on every row, and the names are checked on the first row, so a missing, extra,
/// reordered or wrongly typed column fails with the query's name instead of returning a wrong value. Wraps <see cref="DbDataReader"/> so unit tests need no database.
/// The caller (<c>Db</c>) calls <see cref="Begin"/> before and <see cref="End"/> after each row reader runs.
/// </summary>
[SuppressMessage("Naming", "CA1720:Identifier contains type name", Justification = "Int, Long, Decimal and Guid are the reader names every domain uses; each is named for the value it returns.")]
public sealed class DbRow
{
    private readonly DbDataReader _reader;
    private readonly string _query;
    private Dictionary<string, int>? _ordinals;
    private string[] _names = [];
    private bool[] _seen = [];
    private int _readCount;
    private int _rowNumber;

    /// <param name="reader">The open reader, positioned on a row by the caller.</param>
    /// <param name="query">The caller's file and member, put in front of every error message.</param>
    internal DbRow(DbDataReader reader, string query)
    {
        _reader = reader;
        _query = query;
    }

    public string Text(string column) => Required<string>(column);

    public string? TextOrNull(string column) => OrNull<string>(column);

    public int Int(string column) => Required<int>(column);

    public int? IntOrNull(string column) => OrNullValue<int>(column);

    public long Long(string column) => Required<long>(column);

    public long? LongOrNull(string column) => OrNullValue<long>(column);

    public bool Bool(string column) => Required<bool>(column);

    public bool? BoolOrNull(string column) => OrNullValue<bool>(column);

    public decimal Decimal(string column) => Required<decimal>(column);

    public DateTimeOffset Instant(string column) => Required<DateTimeOffset>(column);

    public DateTimeOffset? InstantOrNull(string column) => OrNullValue<DateTimeOffset>(column);

    public DateOnly Date(string column) => Required<DateOnly>(column);

    public string[] TextArray(string column) => Required<string[]>(column);

    public string[]? TextArrayOrNull(string column) => OrNull<string[]>(column);

    public int[] IntArray(string column) => Required<int[]>(column);

    public Guid Guid(string column) => Required<Guid>(column);

    internal void Begin()
    {
        _rowNumber++;
        if (_ordinals is null)
        {
            MapColumns();
        }

        Array.Clear(_seen);
        _readCount = 0;
    }

    internal void End()
    {
        if (_readCount == _names.Length)
        {
            return;
        }

        if (_rowNumber > 1)
        {
            throw Shape($"row {_rowNumber} read {_readCount} of {_names.Length} columns; a row reader must read every column on every row");
        }

        var unread = _names.Where((_, i) => !_seen[i]).Select(n => "'" + n + "'");
        throw Shape($"column {string.Join(", ", unread)} selected and not read; read it or leave it out of the select");
    }

    private void MapColumns()
    {
        _names = new string[_reader.FieldCount];
        _seen = new bool[_names.Length];
        _ordinals = new Dictionary<string, int>(_names.Length, StringComparer.Ordinal);
        for (var i = 0; i < _names.Length; i++)
        {
            _names[i] = _reader.GetName(i);
            if (!_ordinals.TryAdd(_names[i], i))
            {
                throw Shape($"column '{_names[i]}' is selected twice; give each column its own name");
            }
        }
    }

    private int Claim(string column)
    {
        if (_ordinals is null || !_ordinals.TryGetValue(column, out var ordinal))
        {
            throw Shape($"column '{column}' is not selected");
        }

        if (_seen[ordinal])
        {
            throw Shape($"column '{column}' was read twice");
        }

        _seen[ordinal] = true;
        _readCount++;
        return ordinal;
    }

    private T Required<T>(string column)
    {
        var ordinal = Claim(column);
        if (_reader.IsDBNull(ordinal))
        {
            throw Shape($"column '{column}' is null; read it with an OrNull reader if null is allowed");
        }

        return Value<T>(column, ordinal);
    }

    private T? OrNull<T>(string column)
        where T : class
    {
        var ordinal = Claim(column);
        return _reader.IsDBNull(ordinal) ? null : Value<T>(column, ordinal);
    }

    private T? OrNullValue<T>(string column)
        where T : struct
    {
        var ordinal = Claim(column);
        return _reader.IsDBNull(ordinal) ? null : Value<T>(column, ordinal);
    }

    private T Value<T>(string column, int ordinal)
    {
        try
        {
            return _reader.GetFieldValue<T>(ordinal);
        }
        catch (InvalidCastException e)
        {
            throw Shape($"column '{column}' is of type {_reader.GetFieldType(ordinal).Name} but the row reader reads {typeof(T).Name}", e);
        }
    }

    private DbShapeException Shape(string problem, Exception? inner = null)
    {
        var message = _query + ": " + problem;
        return inner is null ? new DbShapeException(message) : new DbShapeException(message, inner);
    }
}
