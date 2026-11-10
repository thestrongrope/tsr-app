namespace Tsr.Identity.Api;

/// <summary>
/// What a member with a live account deletion request may still reach (PHP's API_DELETION_ALLOWED).
/// Sign-in itself is never blocked: the member must be able to cancel. Keyed on route pattern and method,
/// so a path carrying an id cannot be spelled to look like an allowed one. Unknown routes are refused.
/// </summary>
internal static class DeletionGate
{
    /// <summary>A completed request blocks a create route for the same email for this long (PHP's RESURRECTION_WINDOW_SECONDS).</summary>
    public static readonly TimeSpan ResurrectionWindow = TimeSpan.FromSeconds(7200);

    private static readonly Dictionary<string, string[]> Allowed = new(StringComparer.Ordinal)
    {
        ["/health"] = ["GET"],
        ["/auth/link"] = ["POST"],
        ["/auth/debug-token"] = ["POST"],
        ["/me"] = ["GET"],
        ["/me/deletion-request"] = ["GET", "POST", "DELETE"],
        ["/devices"] = ["DELETE"],
    };

    private static readonly string[] Live = ["pending", "awaiting_prize_delivery"];

    public static bool IsLive(string status) => Live.Contains(status, StringComparer.Ordinal);

    public static bool Allows(string routePattern, string method) =>
        Allowed.TryGetValue(routePattern, out var methods)
        && methods.Contains(method, StringComparer.OrdinalIgnoreCase);
}
