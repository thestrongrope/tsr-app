namespace Tsr.Shared.Api;

/// <summary>
/// A query's rows are not the shape its row reader expects: a column is missing, extra, read twice, null where a value is required, or of another type.
/// A bug in the query or its reader, never a user error (domains/CLAUDE.md rule 5), so it is an exception. The message starts with the caller's
/// file and member, then names the column.
/// </summary>
public sealed class DbShapeException : Exception
{
    public DbShapeException(string message)
        : base(message)
    {
    }

    public DbShapeException(string message, Exception inner)
        : base(message, inner)
    {
    }
}
