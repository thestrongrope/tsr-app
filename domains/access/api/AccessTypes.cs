namespace Tsr.Access.Api;

/// <summary>
/// What a permission check is about (PHP's <c>$target</c>): nothing (the action anywhere), one class, a gender
/// (a registration's or class's), or the gender of a teacher looked up, under the teacher gender rule.
/// </summary>
public sealed record AccessTarget
{
    private AccessTarget()
    {
    }

    /// <summary>The check is not about one thing: holding the action at any scope is enough.</summary>
    public static AccessTarget None { get; } = new();

    public int? ClassId { get; private init; }

    public int? Gender { get; private init; }

    public int? TeacherGender { get; private init; }

    public bool IsNone => ClassId is null && Gender is null && TeacherGender is null;

    public static AccessTarget ForClass(int classId) => new() { ClassId = classId };

    public static AccessTarget ForGender(int gender) => new() { Gender = gender };

    public static AccessTarget ForTeacherGender(int gender) => new() { TeacherGender = gender };
}

/// <summary>
/// What a list may show for one action, with every answer PHP's reach calls give. The owning domain applies it to
/// its own query. A consumer must read <see cref="AssignedOnlyIds"/> before <see cref="ClassIds"/>: a coordinator
/// with no classes has an empty list (show nothing), which is different from null (not limited that way).
/// </summary>
/// <param name="All">Every class (managedReach).</param>
/// <param name="Gender">One gender's classes, for the gender scope (managedReach).</param>
/// <param name="ClassIds">The assigned classes, one entry per matching rule as PHP lists them (managedReach ids).</param>
/// <param name="AssignedOnlyIds">The classes a query must be limited to when assigned is the only reach (assignedOnlyIds); null when not limited that way.</param>
/// <param name="GenderLock">The gender a page must pin its data to, or null (genderLock).</param>
/// <param name="Search">What a search may find (searchReach).</param>
public sealed record Reach(
    bool All,
    int? Gender,
    IReadOnlyList<int> ClassIds,
    IReadOnlyList<int>? AssignedOnlyIds,
    int? GenderLock,
    SearchReach Search);

/// <summary>
/// What a search may find (PHP searchReach): every way in, not only the management scopes. <paramref name="ClassIds"/>
/// unions the assigned, own, taught and enrolled classes the grant reaches (each once, sorted); <paramref name="Self"/>
/// is the caller's token when the action is held at scope self.
/// </summary>
public sealed record SearchReach(bool All, int? Gender, IReadOnlyList<int> ClassIds, int? Self);

/// <summary>
/// What each scope resolves to for one user (PHP's <c>scopes</c>): the admin's gender, and the active classes
/// they are assigned to, own (taught or MCQ-flagged), teach and attend. All id lists are sorted.
/// </summary>
public sealed record AccessScopes(
    int? Gender,
    IReadOnlyList<int> Assigned,
    IReadOnlyList<int> AssignedGenders,
    IReadOnlyList<int> Own,
    IReadOnlyList<int> Taught,
    IReadOnlyList<int> Enrolled);

/// <summary>Everything a user may do: the permission names (catalog order) and what their scopes resolve to.</summary>
public sealed record UserAccess(IReadOnlyList<string> Permissions, AccessScopes Scopes)
{
    /// <summary>A guest, an unknown user: nothing.</summary>
    public static UserAccess None { get; } = new([], new AccessScopes(null, [], [], [], [], []));
}
