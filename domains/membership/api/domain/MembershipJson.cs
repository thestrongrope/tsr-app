using System.Text.Json.Serialization;

namespace Tsr.Membership.Api.Domain;

/// <summary>The payload of <c>membership.member_contact_changed</c>: <c>{"token":n,"nameChanged":b}</c>.</summary>
internal sealed record MemberContactChanged(int Token, bool NameChanged);

/// <summary>The payload of <c>membership.member_created</c>: <c>{"token":n}</c>.</summary>
internal sealed record MemberCreated(int Token);

/// <summary>The source-generated serializer of this domain's event payloads, camelCase as the reflection serializer's web defaults wrote them, so nothing is serialized by reflection.</summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(MemberContactChanged))]
[JsonSerializable(typeof(MemberCreated))]
internal sealed partial class MembershipJson : JsonSerializerContext;
