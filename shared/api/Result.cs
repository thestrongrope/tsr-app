namespace Tsr.Shared.Api;

/// <summary>
/// The one mechanism for expected failures (CODING-GUIDELINES.md rule 5): a value or a reason.
/// Exceptions are for bugs and infrastructure failures only. Create with
/// <see cref="Result.Ok{T}"/> and <see cref="Result.Fail{T}"/>.
/// </summary>
public readonly record struct Result<T>
{
    internal Result(T? value, string? error)
    {
        Value = value;
        Error = error;
    }

    public T? Value { get; }

    public string? Error { get; }

    public bool IsSuccess => Error is null;
}

public static class Result
{
    public static Result<T> Ok<T>(T value) => new(value, null);

    public static Result<T> Fail<T>(string error)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(error);
        return new Result<T>(default, error);
    }
}
