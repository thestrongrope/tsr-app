namespace Tsr.Access.Api.Domain;

/// <summary>What the engine needs to resolve one user: the catalog (ordered), role, stored grants, class facts.</summary>
internal sealed record AccessInputs(
    IReadOnlyList<string> Catalog,
    int RoleId,
    IReadOnlyCollection<string> Stored,
    ClassMemberships Memberships,
    IReadOnlyList<ClassFacts> Assigned);

/// <summary>
/// PHP's PermissionsModel as pure rules: what a user holds (resolve), whether it covers a target (check),
/// and what a list may show (reach). No database; the loader in <see cref="Permissions"/> feeds it.
/// </summary>
internal static class AccessEngine
{
    public const int GenderGents = 1;
    public const int GenderLadies = 2;
    public const int RoleGentsAdmin = 3;
    public const int RoleLadiesAdmin = 4;

    private const char ScopeSeparator = ':';

    /// <summary>The permission names the user holds and what their scopes resolve to.</summary>
    public static UserAccess Resolve(AccessInputs inputs)
    {
        var taught = Sorted(inputs.Memberships.Taught);
        var own = Sorted(inputs.Memberships.Taught.Concat(inputs.Memberships.McqFlagged));
        var held = new HashSet<string>(PermissionSets.Member, StringComparer.Ordinal);
        held.UnionWith(inputs.Stored);
        if (own.Count > 0)
        {
            held.UnionWith(PermissionSets.Own);
        }

        if (taught.Count > 0)
        {
            held.UnionWith(PermissionSets.Taught);
        }

        var scopes = new AccessScopes(
            GenderOfRole(inputs.RoleId),
            inputs.Assigned.Select(c => c.Id).Order().ToList(),
            Sorted(inputs.Assigned.Select(c => c.Gender)),
            own,
            taught,
            Sorted(inputs.Memberships.Enrolled));
        return new UserAccess(inputs.Catalog.Where(held.Contains).ToList(), scopes);
    }

    /// <summary>Is there a catalog name with this <c>resource:action</c>? An unknown action is a caller's bug.</summary>
    public static bool IsKnown(IReadOnlyList<string> catalog, string action) =>
        catalog.Any(name => ActionOf(name) == action);

    /// <summary>The scopes the user holds the action in, in catalog order.</summary>
    public static IReadOnlyList<string> HeldScopes(UserAccess state, string action) =>
        state.Permissions
            .Where(name => ActionOf(name) == action)
            .Select(name => name[(action.Length + 1)..])
            .ToList();

    /// <summary>
    /// May the user do the action on the target? <paramref name="targetClass"/> is the class named by a class
    /// target, or null when it is missing or not active (then the check fails, even for scope all).
    /// </summary>
    public static bool Check(UserAccess state, string action, AccessTarget target, ClassFacts? targetClass)
    {
        var scopes = HeldScopes(state, action);
        if (scopes.Count == 0)
        {
            return false;
        }

        if (target.IsNone)
        {
            return true;
        }

        if (target.ClassId is not null)
        {
            return targetClass is not null && scopes.Any(scope => ClassInScope(targetClass, scope, state.Scopes));
        }

        return CheckGender(state, scopes, target);
    }

    /// <summary>What a list may show: PHP's managedReach, searchReach, genderLock and assignedOnlyIds for the action.</summary>
    public static Reach ReachOf(UserAccess state, string action, int token)
    {
        var scopes = HeldScopes(state, action);
        var all = scopes.Contains("all");
        var gender = scopes.Contains("gender") ? state.Scopes.Gender : null;
        var holdsAssigned = scopes.Contains("assigned");
        var assigned = holdsAssigned ? state.Scopes.Assigned : [];
        var assignedOnly = !all && gender is null && holdsAssigned ? assigned : null;
        return new Reach(all, gender, assigned, assignedOnly, GenderLockOf(state, all, gender, holdsAssigned), SearchOf(state, scopes, all, gender, token));
    }

    // PHP genderLock: not for all; the admin's gender; else the one gender of the assigned classes; else none.
    private static int? GenderLockOf(UserAccess state, bool all, int? gender, bool holdsAssigned)
    {
        if (all)
        {
            return null;
        }

        if (gender is not null)
        {
            return gender;
        }

        return holdsAssigned && state.Scopes.AssignedGenders.Count == 1 ? state.Scopes.AssignedGenders[0] : null;
    }

    private static SearchReach SearchOf(UserAccess state, IReadOnlyList<string> scopes, bool all, int? gender, int token)
    {
        var classIds = new List<int>();
        AddIfHeld(classIds, scopes, "assigned", state.Scopes.Assigned);
        AddIfHeld(classIds, scopes, "own", state.Scopes.Own);
        AddIfHeld(classIds, scopes, "taught", state.Scopes.Taught);
        AddIfHeld(classIds, scopes, "enrolled", state.Scopes.Enrolled);
        var self = scopes.Contains("self") && token > 0 ? token : (int?)null;
        return new SearchReach(all, gender, Sorted(classIds), self);
    }

    private static void AddIfHeld(List<int> into, IReadOnlyList<string> scopes, string scope, IReadOnlyList<int> ids)
    {
        if (scopes.Contains(scope))
        {
            into.AddRange(ids);
        }
    }

    private static bool CheckGender(UserAccess state, IReadOnlyList<string> scopes, AccessTarget target)
    {
        var teacherRule = target.TeacherGender is not null;
        var wanted = target.TeacherGender ?? target.Gender;
        if (wanted is not int gender)
        {
            return false;
        }

        foreach (var scope in scopes)
        {
            var genders = ScopeGenders(scope, state.Scopes);
            if (teacherRule)
            {
                genders = TeacherGenders(genders);
            }

            if (genders.Contains(gender))
            {
                return true;
            }
        }

        return false;
    }

    private static bool ClassInScope(ClassFacts facts, string scope, AccessScopes scopes) => scope switch
    {
        "all" => true,
        "gender" => scopes.Gender is not null && facts.Gender == scopes.Gender,
        "assigned" => scopes.Assigned.Contains(facts.Id),
        "own" => scopes.Own.Contains(facts.Id),
        "taught" => scopes.Taught.Contains(facts.Id),
        "enrolled" => scopes.Enrolled.Contains(facts.Id),
        _ => false,
    };

    // The genders a scope covers, for registrations and teacher lookup. Under assigned, any gender the user has
    // an assigned class in passes (a quirk: the person's own classes are not consulted).
    private static IReadOnlyList<int> ScopeGenders(string scope, AccessScopes scopes) => scope switch
    {
        "all" => [GenderGents, GenderLadies],
        "gender" => scopes.Gender is int gender ? [gender] : [],
        "assigned" => scopes.AssignedGenders,
        _ => [],
    };

    // Gents may teach ladies, not the reverse: managing any ladies class makes both genders eligible.
    private static IReadOnlyList<int> TeacherGenders(IReadOnlyList<int> classGenders)
    {
        if (classGenders.Contains(GenderLadies))
        {
            return [GenderGents, GenderLadies];
        }

        return classGenders.Contains(GenderGents) ? [GenderGents] : [];
    }

    private static int? GenderOfRole(int roleId) => roleId switch
    {
        RoleGentsAdmin => GenderGents,
        RoleLadiesAdmin => GenderLadies,
        _ => null,
    };

    private static string ActionOf(string name)
    {
        var cut = name.LastIndexOf(ScopeSeparator);
        return cut < 0 ? name : name[..cut];
    }

    private static List<int> Sorted(IEnumerable<int> ids) => ids.Distinct().Order().ToList();
}
