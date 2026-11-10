using Microsoft.AspNetCore.Http;

namespace Tsr.Shared.Api;

/// <summary>
/// The verified caller of a request: who they are, never what they may do. Set once by identity's
/// middleware; authority comes from the database through access, never from this record.
/// </summary>
public sealed record Caller(int UserId, int Token, int RoleId);

public static class CallerHttpContextExtensions
{
    private const string Key = "tsr.caller";

    public static void SetCaller(this HttpContext context, Caller caller) => context.Items[Key] = caller;

    /// <summary>The caller, or null when the request carried no verified identity.</summary>
    public static Caller? GetCaller(this HttpContext context) =>
        context.Items.TryGetValue(Key, out var value) ? value as Caller : null;
}
