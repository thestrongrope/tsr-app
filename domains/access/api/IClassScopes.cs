namespace Tsr.Access.Api;

/// <summary>
/// The one interface between access and another domain. access decides from class facts (who teaches, who
/// attends, a class's gender and city), and those tables belong to <c>classes</c>, which itself depends on
/// access: the port breaks the cycle. <c>classes</c> supplies it; until it exists <c>NoClasses</c> answers
/// "no classes", which is true of the new API today. Every class returned is active.
/// </summary>
public interface IClassScopes
{
    /// <summary>The active classes this member teaches, holds an MCQ flag on (the flag only: taught classes are in Taught), or attends.</summary>
    Task<ClassMemberships> MembershipsAsync(int token, CancellationToken ct);

    /// <summary>The class, or null when it does not exist or is not active.</summary>
    Task<ClassFacts?> ActiveClassAsync(int classId, CancellationToken ct);

    /// <summary>Every active class: what a class access rule is matched against.</summary>
    Task<IReadOnlyList<ClassFacts>> ActiveClassesAsync(CancellationToken ct);
}

/// <summary>Active class ids for one member (PHP: classes.teacher, class_students.mcq_admin, class_students.status).</summary>
public sealed record ClassMemberships(IReadOnlyList<int> Taught, IReadOnlyList<int> McqFlagged, IReadOnlyList<int> Enrolled);

/// <summary>The facts about one active class that access decides from. Gender is 1 (gents) or 2 (ladies).</summary>
public sealed record ClassFacts(int Id, int Gender, string? City, string? Country, int? LevelId, IReadOnlyList<string> Tags);

/// <summary>The default port: no classes exist yet (domains/access/CLAUDE.md). <c>classes</c> replaces it.</summary>
internal sealed class NoClasses : IClassScopes
{
    public Task<ClassMemberships> MembershipsAsync(int token, CancellationToken ct) =>
        Task.FromResult(new ClassMemberships([], [], []));

    public Task<ClassFacts?> ActiveClassAsync(int classId, CancellationToken ct) => Task.FromResult<ClassFacts?>(null);

    public Task<IReadOnlyList<ClassFacts>> ActiveClassesAsync(CancellationToken ct) =>
        Task.FromResult<IReadOnlyList<ClassFacts>>([]);
}
