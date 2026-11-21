using System.Text.Json.Serialization;

namespace Tsr.Identity.Api.Domain;

/// <summary>The payload of <c>identity.member_email_changed</c>: <c>{"token":n}</c>.</summary>
internal sealed record MemberEmailChanged(int Token);

/// <summary>The payload of <c>identity.member_created</c>: <c>{"token":n}</c>.</summary>
internal sealed record MemberCreated(int Token);

/// <summary>The source-generated serializer of this domain's event payloads, camelCase as the reflection serializer's web defaults wrote them, so nothing is serialized by reflection.</summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(MemberEmailChanged))]
[JsonSerializable(typeof(MemberCreated))]
internal sealed partial class IdentityJson : JsonSerializerContext;
