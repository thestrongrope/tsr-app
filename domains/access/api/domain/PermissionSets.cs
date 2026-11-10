namespace Tsr.Access.Api.Domain;

/// <summary>
/// The three permission sets PHP keeps in code, not in the tables (PermissionsModel::MEMBER, OWN, TAUGHT).
/// Each is intersected with the catalog, so a name the catalog lacks is dropped.
/// </summary>
internal static class PermissionSets
{
    /// <summary>Held by every registered member (token above 0).</summary>
    public static readonly IReadOnlyList<string> Member =
    [
        "profile:read:self", "profile:update:self", "account:delete:self",
        "devices:manage:self", "notifications:read:self", "class-requests:create:self",
        "classes:join:self", "classes:read:enrolled", "sessions:read:enrolled",
        "attendance:read:self", "performance:read:self", "quiz-scores:read:self",
        "quizzes:take:enrolled", "quiz-competition:take:all", "syllabus:read:all",
        "content:read:all", "children:read:self", "children:link:self",
        "children-performance:read:self", "parents:manage:self", "feedback:create:self",
    ];

    /// <summary>Held while the user teaches an active class or holds an MCQ flag on one.</summary>
    public static readonly IReadOnlyList<string> Own =
    [
        "classes:read:own", "sessions:create:own", "sessions:update:own",
        "notifications:send:own", "mcqs:manage:own", "class-students:read:own",
        "classes:schedule:own", "parents:add:own",
    ];

    /// <summary>Held while the user teaches an active class.</summary>
    public static readonly IReadOnlyList<string> Taught = ["class-students:update:taught", "parents:add-direct:taught"];
}
