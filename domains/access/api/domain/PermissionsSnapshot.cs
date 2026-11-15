using System.Buffers;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Tsr.Access.Api.Domain;

/// <summary>The two facts the app's tab bar and router need: any class to show, any admin module to manage (PHP navigation()).</summary>
internal sealed record Navigation(
    [property: JsonPropertyName("classes")] bool Classes,
    [property: JsonPropertyName("manage")] bool Manage);

/// <summary>A permission with a module in the admin dashboard. <paramref name="AllOnly"/>: it counts only at scope <c>all</c>.</summary>
internal sealed record AdminModulePermission(string Action, bool AllOnly);

/// <summary>
/// The storage could not be read, so what a member may do is unknown, which is not "nothing" (PHP
/// PermissionsUnavailableException). The routes that show a member's permissions answer 503.
/// </summary>
internal sealed class PermissionsUnavailableException(string message, Exception inner) : Exception(message, inner);

/// <summary>
/// What GET /me/permissions adds to the resolved state, as pure rules: PHP PermissionsModel::navigation and ::revision.
/// The revision is PHP's value for the same answer, byte for byte: the app compares the revision it saved with the
/// <c>X-Permissions-Revision</c> header of any response, and the gateway sends some paths to PHP and some here.
/// </summary>
internal static class PermissionsSnapshot
{
    /// <summary>The shape of the answer GET /me/permissions sends (PHP PAYLOAD_VERSION); part of its revision.</summary>
    public const int PayloadVersion = 5;

    private const int RevisionLength = 16;

    /// <summary>PHP ADMIN_MODULE_PERMISSIONS. Broadcast, send and syllabus updates count only at <c>all</c>, as the app always read them.</summary>
    public static readonly IReadOnlyList<AdminModulePermission> AdminModulePermissions =
    [
        new("notifications:broadcast", true),
        new("notifications:send", true),
        new("syllabus:update", true),
        new("reports:read", false),
        new("deactivated-classes:manage", false),
        new("teachers:read", false),
        new("whatsapp:manage", false),
        new("donors:read", false),
        new("deletion-requests:manage", false),
        new("students:transfer", false),
        new("permissions:manage", false),
        new("class-access:manage", false),
        new("members:enrol-by-token", false),
        new("guides:manage", false),
        new("standard-mcqs:update", false),
        new("quiz:admin", false),
        new("mcqs:copy", false),
        new("audit-log:read", false),
    ];

    /// <summary>
    /// Classes: a class attended, taught, owned or assigned, or <c>classes:read</c> for a gender or every class
    /// (<c>classes:read</c> alone says nothing: every member holds it at scope enrolled). Manage: any admin module permission.
    /// </summary>
    public static Navigation NavigationOf(UserAccess state)
    {
        var scopes = state.Scopes;
        var reads = AccessEngine.HeldScopes(state, "classes:read");
        var classes = scopes.Enrolled.Count > 0 || scopes.Taught.Count > 0 || scopes.Own.Count > 0 || scopes.Assigned.Count > 0
            || reads.Contains("gender") || reads.Contains("all");
        return new Navigation(classes, AdminModulePermissions.Any(module => Counts(state, module)));
    }

    /// <summary>
    /// A short fingerprint of what the member may do and see: the first 16 hex characters of the sha256 of the canonical
    /// JSON of navigation, permissions, scopes and version (keys sorted, no spaces: PHP's json_encode of the same arrays).
    /// It changes when, and only when, one of those changes; <c>issued_at</c> is not part of it.
    /// </summary>
    public static string RevisionOf(int version, UserAccess state, Navigation navigation)
    {
        var canonical = new ArrayBufferWriter<byte>();
        using (var json = new Utf8JsonWriter(canonical))
        {
            json.WriteStartObject();
            json.WriteStartObject("navigation");
            json.WriteBoolean("classes", navigation.Classes);
            json.WriteBoolean("manage", navigation.Manage);
            json.WriteEndObject();
            json.WriteStartArray("permissions");
            foreach (var name in state.Permissions)
            {
                json.WriteStringValue(name);
            }

            json.WriteEndArray();
            WriteScopes(json, state.Scopes);
            json.WriteNumber("version", version);
            json.WriteEndObject();
        }

        return Convert.ToHexStringLower(SHA256.HashData(canonical.WrittenSpan))[..RevisionLength];
    }

    private static bool Counts(UserAccess state, AdminModulePermission module)
    {
        var held = AccessEngine.HeldScopes(state, module.Action);
        return module.AllOnly ? held.Contains("all") : held.Count > 0;
    }

    private static void WriteScopes(Utf8JsonWriter json, AccessScopes scopes)
    {
        json.WriteStartObject("scopes");
        WriteIds(json, "assigned", scopes.Assigned);
        WriteIds(json, "assigned_genders", scopes.AssignedGenders);
        WriteIds(json, "enrolled", scopes.Enrolled);
        if (scopes.Gender is int gender)
        {
            json.WriteNumber("gender", gender);
        }
        else
        {
            json.WriteNull("gender");
        }

        WriteIds(json, "own", scopes.Own);
        WriteIds(json, "taught", scopes.Taught);
        json.WriteEndObject();
    }

    private static void WriteIds(Utf8JsonWriter json, string name, IReadOnlyList<int> ids)
    {
        json.WriteStartArray(name);
        foreach (var id in ids)
        {
            json.WriteNumberValue(id);
        }

        json.WriteEndArray();
    }
}
