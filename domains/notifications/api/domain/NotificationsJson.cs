using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tsr.Notifications.Api.Features.CalendarSettingsSync;
using Tsr.Notifications.Api.Features.ClassEventCreate;
using Tsr.Notifications.Api.Features.ClassEventDelete;
using Tsr.Notifications.Api.Features.ClassEventUpdate;
using Tsr.Notifications.Api.Features.ClassScheduledCreate;
using Tsr.Notifications.Api.Features.ClassScheduledDelete;
using Tsr.Notifications.Api.Features.DeviceRegister;
using Tsr.Notifications.Api.Features.DeviceRemove;
using Tsr.Notifications.Api.Features.NotificationsCleanup;
using Tsr.Notifications.Api.Features.WhatsappLink;
using Tsr.Notifications.Api.Features.WhatsappLinkQr;
using Tsr.Notifications.Api.Features.WhatsappReminderRun;
using Tsr.Notifications.Api.Features.WhatsappReminders;
using Tsr.Notifications.Api.Features.WhatsappReminderUpdate;
using Tsr.Notifications.Api.Features.WhatsappRun;
using Tsr.Notifications.Api.Features.WhatsappRuns;
using Tsr.Notifications.Api.Features.WhatsappTest;
using Tsr.Notifications.Api.Workers;

namespace Tsr.Notifications.Api.Domain;

/// <summary>The payload of a queued push, as PHP and the push drain read it: <c>{title, body, data}</c>. A null data value stays in the JSON.</summary>
internal sealed record QueuedPush(string Title, string Body, IReadOnlyDictionary<string, string?> Data);

/// <summary>
/// The source-generated serializer of this domain: the answers (camelCase as the reflection serializer's web defaults wrote them), the ten event payloads, the requests to the push service and
/// the notifier (their own property names), and the JSON stored with a notification or queued for the push drain, so nothing is serialized by reflection.
/// </summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(QueuedPush))]
[JsonSerializable(typeof(DeviceRegisterSlice.DeviceRegistered))]
[JsonSerializable(typeof(DeviceRemoveSlice.DeviceRemoved))]
[JsonSerializable(typeof(NotificationWriter.Sent), TypeInfoPropertyName = "SentEvent")]
[JsonSerializable(typeof(NotificationsCleanupSlice.DevicesRemoved))]
[JsonSerializable(typeof(ClassScheduledCreateSlice.ScheduleCreated))]
[JsonSerializable(typeof(ClassScheduledDeleteSlice.ScheduleDeleted))]
[JsonSerializable(typeof(ClassEventCreateSlice.ClassEventCreated))]
[JsonSerializable(typeof(ClassEventUpdateSlice.ClassEventUpdated))]
[JsonSerializable(typeof(ClassEventDeleteSlice.ClassEventDeleted))]
[JsonSerializable(typeof(CalendarSettingsSyncSlice.EventSettingsSynced))]
[JsonSerializable(typeof(FcmEnvelope))]
[JsonSerializable(typeof(FcmJwtClaims))]
[JsonSerializable(typeof(NotifierReminderUpdate))]
[JsonSerializable(typeof(NotifierRunWeekly))]
[JsonSerializable(typeof(NotifierSendTest))]
[JsonSerializable(typeof(ScheduledPush))]
[JsonSerializable(typeof(ScheduledCriteria))]
[JsonSerializable(typeof(Dictionary<string, JsonElement?>), TypeInfoPropertyName = "AudienceCriteria")]
[JsonSerializable(typeof(Dictionary<string, object?>), TypeInfoPropertyName = "Answer")]
[JsonSerializable(typeof(List<Dictionary<string, object?>>))]
[JsonSerializable(typeof(Dictionary<string, Dictionary<string, object?>>))]
[JsonSerializable(typeof(List<int>))]
[JsonSerializable(typeof(List<string>))]
[JsonSerializable(typeof(object[]))]
[JsonSerializable(typeof(JsonElement))]
[JsonSerializable(typeof(int))]
[JsonSerializable(typeof(long))]
[JsonSerializable(typeof(bool))]
[JsonSerializable(typeof(string))]
[JsonSerializable(typeof(WhatsappLinkQrSlice.Code), TypeInfoPropertyName = "Code")]
[JsonSerializable(typeof(WhatsappLinkSlice.Link))]
[JsonSerializable(typeof(NotifierLinkChange.Changed))]
[JsonSerializable(typeof(WhatsappReminderUpdateSlice.Updated))]
[JsonSerializable(typeof(WhatsappRunSlice.Detail))]
[JsonSerializable(typeof(WhatsappReminderRunSlice.Started))]
[JsonSerializable(typeof(WhatsappTestSlice.Sent), TypeInfoPropertyName = "TestSent")]
[JsonSerializable(typeof(WhatsappRemindersSlice.Listed), TypeInfoPropertyName = "RemindersListed")]
[JsonSerializable(typeof(WhatsappRunsSlice.Listed), TypeInfoPropertyName = "RunsListed")]
internal sealed partial class NotificationsJson : JsonSerializerContext
{
    /// <summary>
    /// For the answers: the host's own options (web defaults and the relaxed encoder ASP.NET Core's JSON options use, so '+' and non-ASCII text stay as written, not \uXXXX).
    /// The answers are dictionaries holding <c>object</c> values, so every runtime type behind them is listed above: a type missing throws only when that value appears.
    /// <see cref="Default"/> (the default encoder) is for the events, the stored JSON and the requests to the outside services.
    /// </summary>
    public static NotificationsJson Answers { get; } = new(new JsonSerializerOptions(JsonSerializerDefaults.Web) { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
}
