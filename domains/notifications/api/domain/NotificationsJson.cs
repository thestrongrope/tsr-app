using System.Text.Json.Serialization;

namespace Tsr.Notifications.Api.Domain;

/// <summary>The payload of a queued push, as PHP and the push drain read it: <c>{title, body, data}</c>. A null data value stays in the JSON.</summary>
internal sealed record QueuedPush(string Title, string Body, IReadOnlyDictionary<string, string?> Data);

/// <summary>The source-generated serializer of this domain's JSON, so nothing is serialized by reflection. Later notifications work adds its types here.</summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(QueuedPush))]
internal sealed partial class NotificationsJson : JsonSerializerContext;
