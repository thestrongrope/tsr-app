namespace Tsr.Membership.Api.Domain;

/// <summary>
/// PHP's <c>SubscribersModel::genderChangeAllowed()</c>: classes are gender-segregated, so a member in a class may not switch gender
/// (otherwise they could switch, join the other gender's class and switch back). Refused only when the stored gender is 1 or 2, the
/// new one differs, and the member holds an enrolment, which <c>classes</c> answers through <see cref="IClassEnrolments"/>.
/// </summary>
internal sealed class GenderLock(IClassEnrolments enrolments)
{
    /// <param name="token">The member's token; a guest (0 or less) is never locked.</param>
    /// <param name="storedGender">The stored text ('1', '2', 'Male', empty, null); its (int) cast is what counts.</param>
    /// <param name="wantedGender">The (int) cast of the value sent (null is 0).</param>
    public async Task<bool> RefusesAsync(int token, string? storedGender, long wantedGender, CancellationToken ct)
    {
        if (token <= 0)
        {
            return false;
        }

        var current = PhpValue.IntOfText(storedGender ?? string.Empty);
        if (current == wantedGender || current is not (1 or 2))
        {
            return false;
        }

        return await enrolments.IsEnrolledAsync(token, ct);
    }
}
