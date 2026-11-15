using Microsoft.AspNetCore.Http;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP's <c>api_require_guide_reader()</c> (routes/guides.php), shared by the two /me/guides slices: guide links are for students and teachers.
/// </summary>
internal static class GuideReaders
{
    /// <summary>
    /// Null when the caller may read guides; else the refusal, in PHP's order: syllabus:read (every member holds it; a guest does not), then
    /// PHP's <c>isStudentOrTeacher</c>: an active enrolment in an active class, or an active class taught. No permission tells these members
    /// from the others, so this reads the resolved scopes, as PHP does.
    /// </summary>
    public static async Task<IResult?> RefusalAsync(Caller caller, Permissions permissions, CancellationToken ct)
    {
        if (!await permissions.CanAsync(caller, "syllabus:read", AccessTarget.None, ct))
        {
            return Refusals.NotPermitted();
        }

        var scopes = (await permissions.ForUserAsync(caller, ct)).Scopes;
        if (scopes.Enrolled.Count == 0 && scopes.Taught.Count == 0)
        {
            return Problem.Detail(StatusCodes.Status403Forbidden, "Guides are for students and teachers");
        }

        return null;
    }
}
