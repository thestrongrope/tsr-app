using Microsoft.EntityFrameworkCore;

namespace Tsr.Platform.Api;

/// <summary>
/// The module's public read interface for PHP's <c>lookups</c>: the enumerated lists a form validates against. Registrations
/// store the label text itself, so the labels are what callers compare with (exactly, case-sensitively, as PHP's strict <c>in_array</c>).
/// </summary>
public sealed class Lookups
{
    /// <summary>Safety bound on one list (the longest seeded list has 18 options).</summary>
    private const int MaxRows = 500;

    private readonly PlatformContext _db;

    internal Lookups(PlatformContext db) => _db = db;

    /// <summary>
    /// The active labels of one type in display order (sort order, then id), empty labels left out. A type with no active
    /// row is an unseeded database, not an empty list: it throws (PHP's <c>labelsOrFail</c>, a 500), because an empty list would
    /// silently make every submitted value invalid.
    /// </summary>
    public async Task<IReadOnlyList<string>> LabelsAsync(string type, CancellationToken ct)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(type);
        var labels = await _db.LookupEntries.AsNoTracking()
            .Where(l => l.Type == type && l.IsActive && l.Label != string.Empty)
            .OrderBy(l => l.SortOrder).ThenBy(l => l.Id)
            .Select(l => l.Label)
            .Take(MaxRows)
            .ToListAsync(ct);
        return labels.Count > 0
            ? labels
            : throw new InvalidOperationException("lookups: no active rows for type '" + type + "'. Is the database seeded?");
    }
}
