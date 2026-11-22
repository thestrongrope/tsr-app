using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tsr.Access.Api.Features.AdminPermissionGrant;
using Tsr.Access.Api.Features.AdminPermissionMembers;
using Tsr.Access.Api.Features.AdminPermissionRevoke;
using Tsr.Access.Api.Features.ClassAccessGrant;
using Tsr.Access.Api.Features.ClassAccessMembers;
using Tsr.Access.Api.Features.ClassAccessOptions;
using Tsr.Access.Api.Features.ClassAccessPreview;
using Tsr.Access.Api.Features.ClassAccessRevoke;
using Tsr.Access.Api.Features.MePermission;
using Tsr.Access.Api.Features.MePermissions;
using Tsr.Access.Api.Features.UserPermissions;

namespace Tsr.Access.Api.Domain;

/// <summary>
/// Every answer, refusal and event of access, written without reflection (web defaults, as the host's <c>Results.Json</c> and the outbox use).
/// The refusal dictionary holds <c>object</c> values, so every runtime type behind them is listed: <c>int</c>, <c>string</c>, <c>List&lt;PreviewClass&gt;</c>.
/// A type missing here throws only when that value appears; <c>AccessJson.Tests.cs</c> writes each with reflection off.
/// </summary>
[JsonSourceGenerationOptions(JsonSerializerDefaults.Web)]
[JsonSerializable(typeof(MePermissionsResponse))]
[JsonSerializable(typeof(MePermissionResponse))]
[JsonSerializable(typeof(UserPermissionsResponse))]
[JsonSerializable(typeof(GrantMemberView))]
[JsonSerializable(typeof(ClassAccessView))]
[JsonSerializable(typeof(SavedBody))]
[JsonSerializable(typeof(AdminPermissionMembersSlice.GrantMembersAnswer))]
[JsonSerializable(typeof(AdminPermissionMembersSlice.Found), TypeInfoPropertyName = "GrantFound")]
[JsonSerializable(typeof(IReadOnlyList<AdminPermissionMembersSlice.Found>), TypeInfoPropertyName = "GrantFoundList")]
[JsonSerializable(typeof(ClassAccessMembersSlice.ClassAccessMembersAnswer))]
[JsonSerializable(typeof(ClassAccessMembersSlice.Found), TypeInfoPropertyName = "ClassAccessFound")]
[JsonSerializable(typeof(IReadOnlyList<ClassAccessMembersSlice.Found>), TypeInfoPropertyName = "ClassAccessFoundList")]
[JsonSerializable(typeof(ClassAccessOptionsSlice.ClassAccessOptionsAnswer))]
[JsonSerializable(typeof(ClassAccessPreviewSlice.PreviewAnswer))]
[JsonSerializable(typeof(Dictionary<string, object?>))]
[JsonSerializable(typeof(int))]
[JsonSerializable(typeof(string))]
[JsonSerializable(typeof(List<PreviewClass>))]
[JsonSerializable(typeof(AdminPermissionGrantSlice.PermissionGranted))]
[JsonSerializable(typeof(AdminPermissionRevokeSlice.PermissionRevoked))]
[JsonSerializable(typeof(ClassAccessGrantSlice.RuleCreated))]
[JsonSerializable(typeof(ClassAccessRevokeSlice.RuleRevoked))]
internal sealed partial class AccessJson : JsonSerializerContext
{
    /// <summary>
    /// For the answers: the host's own options (web defaults and the relaxed encoder ASP.NET Core's JSON options use, so '+' and non-ASCII text stay as written, not \uXXXX).
    /// <see cref="Default"/> (the default encoder) is for the events, which the outbox always wrote with web defaults alone.
    /// </summary>
    public static AccessJson Answers { get; } = new(new JsonSerializerOptions(JsonSerializerDefaults.Web) { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
}
