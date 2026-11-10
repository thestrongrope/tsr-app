using System.Globalization;

namespace Tsr.Access.Api.Domain;

/// <summary>One entry of <c>applicable_roles</c>. <c>RoleId</c> is a number for a database role and a string for the two derived ones.</summary>
internal sealed record ApplicableRole(object RoleId, string RoleName, string Source, int Priority);

/// <summary>
/// The answer of <c>GET /user/permissions</c>: PHP's older, role-id based page list (pages.json), which the app's
/// router still reads. Copied as it is, including the lookup that never matches the two derived roles
/// (they are listed but grant nothing: granting them would be a privilege change, not a port).
/// </summary>
internal sealed record LegacyPermissions(
    int Version,
    IReadOnlyList<string> Permissions,
    int RoleId,
    string RoleName,
    IReadOnlyList<ApplicableRole> ApplicableRoles,
    bool Enrolled,
    int ClassCount,
    int TeacherCount,
    bool McqAdmin,
    bool IsTeacher)
{
    private const int CatalogVersion = 3;

    private static readonly Dictionary<int, string> RoleNames = new()
    {
        [1] = "SUPER_ADMIN",
        [3] = "GENTS_ADMIN",
        [4] = "LADIES_ADMIN",
        [5] = "CLASS_ADMIN",
        [6] = "CLASS_TEACHER",
        [7] = "FINANCE",
    };

    // pages.json, "roles": the pages each role id opens. Role 0 and any unlisted id open none.
    private static readonly Dictionary<int, string[]> Pages = new()
    {
        [1] = ["admin_dashboard", "user_management", "class_management", "finance_portal", "system_settings", "reports_center", "page.admin.notifications", "page.admin.syllabus"],
        [3] = ["gents_dashboard", "gents_classes", "gents_students", "gents_teachers", "gents_reports"],
        [4] = ["ladies_dashboard", "ladies_classes", "ladies_students", "ladies_teachers", "ladies_reports"],
        [5] = ["class_management", "mcq_management", "student_management", "class_reports"],
        [6] = ["teacher_dashboard", "my_classes", "lesson_management", "grade_management", "class_management", "mcq_management", "student_management", "class_reports"],
        [7] = ["finance_dashboard", "donor_management", "financial_reports"],
    };

    public static LegacyPermissions Build(int roleId, int enrolledCount, bool mcqAdmin, int teacherCount)
    {
        var isTeacher = teacherCount > 0;
        var roles = new List<ApplicableRole>();
        if (roleId != 0)
        {
            roles.Add(new ApplicableRole(roleId, NameOf(roleId), "database_role", 1));
        }

        if (mcqAdmin)
        {
            roles.Add(new ApplicableRole("class_admin", "CLASS_ADMIN", "class_students.mcq_admin", 2));
        }

        if (isTeacher)
        {
            roles.Add(new ApplicableRole("class_teacher", "CLASS_TEACHER", "classes.teacher", 3));
        }

        // Only a database role (a number) finds its pages; the derived roles' string ids never match the catalog.
        var pages = roles
            .Where(r => r.RoleId is int id && Pages.ContainsKey(id))
            .SelectMany(r => Pages[(int)r.RoleId])
            .Distinct()
            .Order(StringComparer.Ordinal)
            .ToList();

        var primary = roles.OrderBy(r => r.Priority).FirstOrDefault();
        return new LegacyPermissions(
            CatalogVersion,
            pages,
            primary?.RoleId is int primaryId ? primaryId : 0,
            primary?.RoleName ?? "USER",
            roles,
            enrolledCount > 0,
            enrolledCount,
            teacherCount,
            mcqAdmin,
            isTeacher);
    }

    /// <summary>PHP's <c>api_utc_iso8601()</c>: microseconds and a +00:00 offset; the app reads it as a plain string.</summary>
    public static string IssuedAt(DateTimeOffset now) =>
        now.UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.ffffff'+00:00'", CultureInfo.InvariantCulture);

    private static string NameOf(int roleId) => RoleNames.GetValueOrDefault(roleId, "USER");
}
