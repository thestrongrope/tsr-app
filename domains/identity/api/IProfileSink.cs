
namespace Tsr.Identity.Api;

/// <summary>
/// The one port identity declares: sign-in hands the token's name and picture on, in the same request, as PHP writes them
/// into <c>users</c> (<c>subscribers.php</c> getOrCreateFromFirebase). Those are profile columns, owned by
/// <c>membership</c>, which supplies the real sink; identity depends on no domain. Until one is registered
/// <see cref="NoProfileSink"/> drops them.
/// </summary>
public interface IProfileSink
{
    /// <summary>
    /// A create route made a new member (<paramref name="isNewMember"/>: PHP stores an absent name or picture as empty text)
    /// or a verified email claimed an existing one (an absent value keeps what is stored).
    /// </summary>
    Task RecordSignInAsync(int userId, string? name, string? picture, bool isNewMember, CancellationToken ct);
}

/// <summary>The default sink: nowhere to keep a profile.</summary>
internal sealed class NoProfileSink : IProfileSink
{
    public Task RecordSignInAsync(int userId, string? name, string? picture, bool isNewMember, CancellationToken ct) =>
        Task.CompletedTask;
}
