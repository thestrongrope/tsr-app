using Microsoft.AspNetCore.Http;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>The guard chains the /admin routes repeat, each PHP's own (a refusal is returned, null means go on).</summary>
internal static class AdminGuards
{
    /// <summary>PHP api_require_super_admin (syllabus.php): syllabus:update, then platform's audit row for a privileged caller.</summary>
    public static async Task<IResult?> SyllabusAdminAsync(HttpContext context, ClassesContext db, Permissions permissions, Caller caller, CancellationToken ct)
    {
        if (!await permissions.CanAsync(caller, "syllabus:update", AccessTarget.None, ct))
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "Only super admins can access this resource");
        }

        await ClassGuards.LogAdminAccessAsync(db, context, permissions, caller, ct);
        return null;
    }

    /// <summary>PHP api_require_transfers (student_transfers.php): students:transfer, no audit row.</summary>
    public static async Task<IResult?> TransfersAsync(Permissions permissions, Caller caller, CancellationToken ct) =>
        await permissions.CanAsync(caller, "students:transfer", AccessTarget.None, ct)
            ? null
            : Problem.Detail(StatusCodes.Status403Forbidden, "Only administrators can transfer students");

    /// <summary>The deactivated-classes screens: deactivated-classes:manage with PHP's default refusal.</summary>
    public static async Task<IResult?> DeactivatedClassesAsync(Permissions permissions, Caller caller, CancellationToken ct) =>
        await permissions.CanAsync(caller, "deactivated-classes:manage", AccessTarget.None, ct) ? null : Refusals.NotPermitted();
}
