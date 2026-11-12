namespace Tsr.Search.Api.Domain;

/// <summary>One document of the index <c>tsr-search</c> that matched: a pointer (the record's id and the indexed name), never a card.</summary>
internal sealed record SearchHit(long Id, string Name);

/// <summary>"Any of these": the document must hold one of the values in the field (an Elasticsearch <c>terms</c> clause).</summary>
internal sealed record TermsClause(string Field, IReadOnlyList<int> Values);

/// <summary>
/// The row scope of one query. <see cref="Everything"/> is the only way to ask without a filter; a limited scope needs at
/// least one clause, so "no way in" can never turn into "no filter".
/// </summary>
internal sealed record SearchScope
{
    private SearchScope(IReadOnlyList<TermsClause>? anyOf) => AnyOf = anyOf;

    public static SearchScope Everything { get; } = new((IReadOnlyList<TermsClause>?)null);

    /// <summary>The clauses the document must match at least one of; null for <see cref="Everything"/>.</summary>
    public IReadOnlyList<TermsClause>? AnyOf { get; }

    public static SearchScope Limited(IReadOnlyList<TermsClause> anyOf)
    {
        ArgumentNullException.ThrowIfNull(anyOf);
        if (anyOf.Count == 0)
        {
            throw new ArgumentException("A limited scope needs at least one clause.", nameof(anyOf));
        }

        return new SearchScope(anyOf);
    }
}

/// <summary>Elasticsearch could not be reached, is not configured, or refused the request: "search is down", never "nothing matched".</summary>
internal sealed class SearchUnavailableException(string message) : Exception(message);

/// <summary>The external boundary: the Elasticsearch index. Fake in unit tests.</summary>
internal interface ISearchIndex
{
    /// <summary>
    /// The best <paramref name="size"/> documents of <paramref name="kind"/> whose name matches every word of
    /// <paramref name="text"/> and that lie in <paramref name="scope"/>. The text is a value, never query syntax.
    /// </summary>
    /// <exception cref="SearchUnavailableException">The index could not answer.</exception>
    Task<IReadOnlyList<SearchHit>> SearchAsync(string kind, string text, SearchScope scope, int size, CancellationToken ct);
}
