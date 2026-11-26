using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tsr.Identity.Api.Features.AdminDeletionComplete;
using Tsr.Identity.Api.Features.AdminDeletionHold;
using Tsr.Identity.Api.Features.DeletionRequestCancel;

namespace Tsr.Identity.Api.Domain;

/// <summary>The payload of <c>identity.member_email_changed</c>: <c>{"token":n}</c>.</summary>
internal sealed record MemberEmailChanged(int Token);

/// <summary>The payload of <c>identity.member_created</c>: <c>{"token":n}</c>.</summary>
internal sealed record MemberCreated(int Token);

/// <summary>The source-generated serializer of this domain: answers, event payloads (camelCase as the reflection serializer's web defaults wrote them) and the account-service wire records (their own property names), so nothing is serialized by reflection.</summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(MemberEmailChanged))]
[JsonSerializable(typeof(MemberCreated))]
[JsonSerializable(typeof(AccountLookup))]
[JsonSerializable(typeof(AccountDelete))]
[JsonSerializable(typeof(JwtHeader))]
[JsonSerializable(typeof(JwtClaims))]
[JsonSerializable(typeof(DeletionRequests.Requested))]
[JsonSerializable(typeof(DeletionRequestCancelSlice.Cancelled))]
[JsonSerializable(typeof(AdminDeletionHoldSlice.Held))]
[JsonSerializable(typeof(AdminDeletionCompleteSlice.MemberErased))]
[JsonSerializable(typeof(AdminDeletionCompleteSlice.DeletionCompleted))]
[JsonSerializable(typeof(Dictionary<string, object?>), TypeInfoPropertyName = "Answer")]
[JsonSerializable(typeof(List<Dictionary<string, object?>>), TypeInfoPropertyName = "AnswerList")]
[JsonSerializable(typeof(Dictionary<string, int>), TypeInfoPropertyName = "Counts")]
[JsonSerializable(typeof(int))]
[JsonSerializable(typeof(bool))]
[JsonSerializable(typeof(string))]
internal sealed partial class IdentityJson : JsonSerializerContext
{
    /// <summary>
    /// For the answers: the host's own options (web defaults and the relaxed encoder ASP.NET Core's JSON options use, so '+' and non-ASCII text stay as written, not \uXXXX).
    /// The answers are dictionaries holding <c>object</c> values, so every runtime type behind them is listed above: a type missing throws only when that value appears; <c>IdentityJson.Tests.cs</c> writes each with reflection off.
    /// <see cref="Default"/> (the default encoder) is for the events and the account-service requests.
    /// </summary>
    public static IdentityJson Answers { get; } = new(new JsonSerializerOptions(JsonSerializerDefaults.Web) { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
}
