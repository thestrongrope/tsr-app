using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>PHP <c>TeachersModel::canView</c>: which teachers a caller holding teachers:lookup may see, by the teacher's gender.</summary>
internal static class TeacherView
{
    /// <summary>
    /// The decision after the plain teachers:lookup check passed. <paramref name="gender"/> is the teacher's (int) cast gender. A teacher with no gender of 1 or 2 is seen only by a caller who looks up every teacher; otherwise
    /// the caller needs the lookup for that gender, or (for a gents teacher) the lookup for gents teachers and the teacher actually teaching (<paramref name="teachesAsync"/>, asked only then).
    /// </summary>
    public static async Task<bool> CanViewAsync(Permissions permissions, Caller caller, int gender, Func<Task<bool>> teachesAsync, CancellationToken ct)
    {
        if (gender is not (1 or 2))
        {
            return (await permissions.ReachAsync(caller, "teachers:lookup", ct)).All;
        }

        if (await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.ForGender(gender), ct))
        {
            return true;
        }

        // Gents may teach ladies classes: whoever manages a ladies class may see a gents member, but only one who teaches.
        if (gender != 1 || !await permissions.CanAsync(caller, "teachers:lookup", AccessTarget.ForTeacherGender(1), ct))
        {
            return false;
        }

        return await teachesAsync();
    }
}
