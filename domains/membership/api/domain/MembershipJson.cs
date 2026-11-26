using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using Tsr.Membership.Api.Features.MemberParentLinkCancel;
using Tsr.Membership.Api.Features.MemberParentLinkCreate;
using Tsr.Membership.Api.Features.MemberParentsAdd;
using Tsr.Membership.Api.Features.RegistrationReject;
using Tsr.Membership.Api.Features.ReportRegistrations;
using Tsr.Membership.Api.Features.StudentCard;

namespace Tsr.Membership.Api.Domain;

/// <summary>The payload of <c>membership.member_contact_changed</c>: <c>{"token":n,"nameChanged":b}</c>.</summary>
internal sealed record MemberContactChanged(int Token, bool NameChanged);

/// <summary>The payload of <c>membership.member_created</c>: <c>{"token":n}</c>.</summary>
internal sealed record MemberCreated(int Token);

/// <summary>
/// The source-generated serializer of this domain: event payloads and answers, camelCase as the reflection serializer's web defaults wrote them, so nothing is serialized by reflection.
/// </summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(MemberContactChanged))]
[JsonSerializable(typeof(MemberCreated))]
[JsonSerializable(typeof(MemberParentLinkCreateSlice.InviteCreated))]
[JsonSerializable(typeof(MemberParentLinkCancelSlice.InviteCancelled))]
[JsonSerializable(typeof(MemberParentsAddSlice.ParentLinkAdded))]
[JsonSerializable(typeof(RegistrationRejectSlice.RegistrationRejected))]
[JsonSerializable(typeof(Refusals.Coded))]
[JsonSerializable(typeof(ReportRegistrationsSlice.Answer), TypeInfoPropertyName = "ReportAnswer")]
[JsonSerializable(typeof(List<string>))]
[JsonSerializable(typeof(JsonObject))]
[JsonSerializable(typeof(JsonArray))]
[JsonSerializable(typeof(Dictionary<string, object?>), TypeInfoPropertyName = "Answer")]
[JsonSerializable(typeof(List<Dictionary<string, object?>>), TypeInfoPropertyName = "AnswerList")]
[JsonSerializable(typeof(List<StudentCardSlice.ClassItem>))]
[JsonSerializable(typeof(int))]
[JsonSerializable(typeof(long))]
[JsonSerializable(typeof(bool))]
[JsonSerializable(typeof(string))]
internal sealed partial class MembershipJson : JsonSerializerContext
{
    /// <summary>
    /// For the answers: the host's own options (web defaults and the relaxed encoder, so '+' and non-ASCII text stay as written, not \uXXXX).
    /// The answers are dictionaries holding <c>object</c> values, so every runtime type behind them is listed above: a type missing throws only when that value appears.
    /// <see cref="Default"/> (the default encoder) is for the events.
    /// </summary>
    public static MembershipJson Answers { get; } = new(new JsonSerializerOptions(JsonSerializerDefaults.Web) { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
}
