namespace Tsr.Identity.Api;

/// <summary>A Firebase account could not be deleted. The message is safe to show an administrator (never a credential).</summary>
internal sealed class FirebaseAccountException(string message) : Exception(message);

/// <summary>
/// Port at an external boundary: deletes a member's Firebase sign-in (PHP <c>AccountDeletionModel::firebaseDeleter</c>). Prefers the stored
/// <paramref name="uid"/>, falls back to a lookup by <paramref name="email"/>; no account is not an error; anything else throws
/// <see cref="FirebaseAccountException"/>, and completion then stops before it touches the database.
/// </summary>
internal interface IFirebaseAccounts
{
    Task DeleteAsync(string? uid, string? email, CancellationToken ct);
}

/// <summary>The Auth emulator is on (Development only): there is no real account to delete, so deleting does nothing.</summary>
internal sealed class EmulatorFirebaseAccounts : IFirebaseAccounts
{
    public Task DeleteAsync(string? uid, string? email, CancellationToken ct) => Task.CompletedTask;
}

/// <summary>
/// No service account is configured (<c>TSR_GOOGLE_SERVICE_ACCOUNT_B64</c> absent): as PHP without its credentials, every deletion is refused with
/// PHP's message, before the database is touched. The API itself starts without it.
/// </summary>
internal sealed class UnconfiguredFirebaseAccounts : IFirebaseAccounts
{
    public const string Message = "Firebase service account not configured. Set TSR_GOOGLE_SERVICE_ACCOUNT_B64 (base64 of the service account JSON).";

    public Task DeleteAsync(string? uid, string? email, CancellationToken ct) => throw new FirebaseAccountException(Message);
}
