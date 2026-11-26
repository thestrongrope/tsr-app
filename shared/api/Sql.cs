using System.Runtime.CompilerServices;
using System.Text;
using Npgsql;
using NpgsqlTypes;

namespace Tsr.Shared.Api;

/// <summary>
/// A SQL text with its values, built from an interpolated string: <c>$"... where id = {id}"</c>. The text between the holes is
/// kept as written; each hole becomes a typed parameter named <c>@p0</c>, <c>@p1</c>, ... as Entity Framework names them, so a value
/// never becomes SQL text (rule 5) and the query text moves from EF to here unchanged. A repeated value is two parameters.
/// There is deliberately no generic <c>AppendFormatted&lt;T&gt;</c>: a hole of a type listed here is typed exactly, any other type
/// does not compile, so a wrongly typed value cannot reach the database as a guess.
/// </summary>
[InterpolatedStringHandler]
public struct Sql
{
    private readonly StringBuilder _text;
    private readonly List<NpgsqlParameter> _parameters;

    public Sql(int literalLength, int formattedCount)
    {
        _text = new StringBuilder(literalLength + (formattedCount * 4));
        _parameters = new List<NpgsqlParameter>(formattedCount);
    }

    /// <summary>True for <c>default(Sql)</c>, which was not built from an interpolated string and holds no text.</summary>
    internal readonly bool IsDefault => _text is null;

    internal readonly string Text => _text.ToString();

    internal readonly NpgsqlParameter[] Parameters => [.. _parameters];

    public readonly void AppendLiteral(string value) => _text.Append(value);

    public readonly void AppendFormatted(string? value) => Add(NpgsqlDbType.Text, value);

    public readonly void AppendFormatted(short value) => Add(NpgsqlDbType.Smallint, value);

    public readonly void AppendFormatted(short? value) => Add(NpgsqlDbType.Smallint, value);

    public readonly void AppendFormatted(int value) => Add(NpgsqlDbType.Integer, value);

    public readonly void AppendFormatted(int? value) => Add(NpgsqlDbType.Integer, value);

    public readonly void AppendFormatted(long value) => Add(NpgsqlDbType.Bigint, value);

    public readonly void AppendFormatted(long? value) => Add(NpgsqlDbType.Bigint, value);

    public readonly void AppendFormatted(bool value) => Add(NpgsqlDbType.Boolean, value);

    public readonly void AppendFormatted(bool? value) => Add(NpgsqlDbType.Boolean, value);

    public readonly void AppendFormatted(decimal value) => Add(NpgsqlDbType.Numeric, value);

    public readonly void AppendFormatted(double value) => Add(NpgsqlDbType.Double, value);

    public readonly void AppendFormatted(Guid value) => Add(NpgsqlDbType.Uuid, value);

    // Npgsql refuses a timestamptz value whose offset is not zero, so the conversion happens here, once.
    public readonly void AppendFormatted(DateTimeOffset value) => Add(NpgsqlDbType.TimestampTz, value.ToUniversalTime());

    public readonly void AppendFormatted(DateTimeOffset? value) => Add(NpgsqlDbType.TimestampTz, value?.ToUniversalTime());

    // A DateTime converts to DateTimeOffset implicitly and an Unspecified one would be shifted by the machine's offset, so these exist only to make that a compile error.
    [Obsolete("Pass a DateTimeOffset: a DateTime has no offset.", error: true)]
    public readonly void AppendFormatted(DateTime value) => throw new NotSupportedException("Pass a DateTimeOffset: a DateTime has no offset.");

    [Obsolete("Pass a DateTimeOffset: a DateTime has no offset.", error: true)]
    public readonly void AppendFormatted(DateTime? value) => throw new NotSupportedException("Pass a DateTimeOffset: a DateTime has no offset.");

    public readonly void AppendFormatted(DateOnly value) => Add(NpgsqlDbType.Date, value);

    public readonly void AppendFormatted(TimeOnly value) => Add(NpgsqlDbType.Time, value);

    public readonly void AppendFormatted(TimeOnly? value) => Add(NpgsqlDbType.Time, value);

    // A wall-clock value for a "timestamp without time zone" column: the wrapper is the only way past the DateTime guard above.
    public readonly void AppendFormatted(LocalTimestamp value) => Add(NpgsqlDbType.Timestamp, value.Value);

    public readonly void AppendFormatted(LocalTimestamp? value) => Add(NpgsqlDbType.Timestamp, value?.Value);

    public readonly void AppendFormatted(string?[] value) => Add(NpgsqlDbType.Array | NpgsqlDbType.Text, value);

    public readonly void AppendFormatted(int[] value) => Add(NpgsqlDbType.Array | NpgsqlDbType.Integer, value);

    private readonly void Add(NpgsqlDbType type, object? value)
    {
        var name = "p" + _parameters.Count;
        _parameters.Add(new NpgsqlParameter(name, type) { Value = value ?? DBNull.Value });
        _text.Append('@').Append(name);
    }
}

/// <summary>A date and time read in a row's own time zone, for a <c>timestamp without time zone</c> column. Its <see cref="DateTime.Kind"/> must be <see cref="DateTimeKind.Unspecified"/>.</summary>
public readonly record struct LocalTimestamp
{
    public LocalTimestamp(DateTime value)
    {
        if (value.Kind != DateTimeKind.Unspecified)
        {
            throw new ArgumentException("A local timestamp must have the kind Unspecified.", nameof(value));
        }

        Value = value;
    }

    public DateTime Value { get; }
}
