namespace Tsr.Membership.Api;

/// <summary>
/// The one port membership declares toward <c>classes</c>. Membership needs "is this member in a class" (a member enrolled in
/// a class may not change their gender) but the enrolment tables belong to <c>classes</c>, which will itself depend on
/// membership for names and genders: the port breaks the cycle, as access's <c>IClassScopes</c> does. <c>classes</c> supplies
/// it; until it exists <see cref="NoEnrolments"/> answers "not enrolled", which is true of the new API today.
/// </summary>
public interface IClassEnrolments
{
    /// <summary>
    /// True when the member holds an enrolment that is not removed and has status A, whatever the class's own status
    /// (PHP: <c>class_students.removed_at is null and status = 'A'</c>).
    /// </summary>
    Task<bool> IsEnrolledAsync(int token, CancellationToken ct);
}

/// <summary>The default port: no classes exist yet. <c>classes</c> replaces it.</summary>
internal sealed class NoEnrolments : IClassEnrolments
{
    public Task<bool> IsEnrolledAsync(int token, CancellationToken ct) => Task.FromResult(false);
}
