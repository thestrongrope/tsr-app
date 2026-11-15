namespace Tsr.Notifications.Api;

// One class per PHP table of this domain, columns in PHP's order. A member ("token"), class or schedule slot is a plain integer.

/// <summary>A push notification that was sent (PHP <c>notifications</c>). <c>TargetAudienceCriteria</c> is JSON kept as text; <c>CreatedBy</c> a member token.</summary>
internal sealed class Notification
{
    public int NotificationId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public string TargetAudienceCriteria { get; set; } = string.Empty;

    public DateTimeOffset SentAt { get; set; }

    public int CreatedBy { get; set; }

    public int? DeviceCount { get; set; }

    public int? SuccessCount { get; set; }

    public int? FailureCount { get; set; }

    public string? Priority { get; set; }

    public string? ImageUrl { get; set; }

    public string? ActionLink { get; set; }
}

/// <summary>A member's copy of a notification (PHP <c>user_notifications</c>). <c>IsRead</c> is PHP's tinyint flag.</summary>
internal sealed class UserNotification
{
    public int Id { get; set; }

    public int NotificationId { get; set; }

    public int UserToken { get; set; }

    public short IsRead { get; set; }

    public DateTimeOffset? ReadAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>A device a member signed in on (PHP <c>user_devices</c>), the push address. PHP bumps <c>LastAccessedAt</c> on every update.</summary>
internal sealed class UserDevice
{
    public int Id { get; set; }

    public int Token { get; set; }

    public string DeviceId { get; set; } = string.Empty;

    public DateTimeOffset LastAccessedAt { get; set; }

    public DateTimeOffset RegisteredAt { get; set; }
}

/// <summary>A WhatsApp reminder the notifier sends (PHP <c>notifier_reminders</c>). <c>Levels</c> is a comma separated list. <c>SendTime</c> is a wall-clock time in <c>Timezone</c>.</summary>
internal sealed class NotifierReminder
{
    public int Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Type { get; set; } = "cform_missing";

    public string Gender { get; set; } = "gents";

    public string? City { get; set; }

    public string? Country { get; set; }

    public string Levels { get; set; } = "BILAL,AMMAR,MIQDAD,ABUZAR";

    public string Lang { get; set; } = "english";

    public short LeewayDays { get; set; } = 10;

    public string Timezone { get; set; } = "Asia/Kolkata";

    public short? Weekday { get; set; }

    public TimeOnly? SendTime { get; set; }

    public short ScheduleOn { get; set; }

    public short Enabled { get; set; } = 1;

    public int? UpdatedBy { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>One run of the notifier (PHP <c>notifier_runs</c>). <c>SettingsSnapshot</c> is JSON kept as text; <c>ReminderId</c> has no foreign key, as in PHP.</summary>
internal sealed class NotifierRun
{
    public long Id { get; set; }

    public int? ReminderId { get; set; }

    public DateTimeOffset StartedAt { get; set; }

    public DateTimeOffset? FinishedAt { get; set; }

    public DateOnly? FromDate { get; set; }

    public DateOnly? ToDate { get; set; }

    public string Status { get; set; } = "running";

    public int SentCount { get; set; }

    public int SkippedCount { get; set; }

    public int FailedCount { get; set; }

    public short DryRun { get; set; }

    public int? TriggeredBy { get; set; }

    public string? SettingsSnapshot { get; set; }

    public string? ErrorMessage { get; set; }
}

/// <summary>A message a run sent, skipped or failed to send (PHP <c>notifier_sent_messages</c>).</summary>
internal sealed class NotifierSentMessage
{
    public long Id { get; set; }

    public long RunId { get; set; }

    public int? TeacherToken { get; set; }

    public string TeacherMobile { get; set; } = string.Empty;

    public string? TeacherName { get; set; }

    public int? TotalMissing { get; set; }

    public string? MessageExcerpt { get; set; }

    public string Status { get; set; } = string.Empty;

    public string? Error { get; set; }

    public DateTimeOffset SentAt { get; set; }
}

/// <summary>
/// A notification scheduled for a class (PHP <c>class_scheduled_notifications</c>): once (<c>SendAt</c>), weekly (<c>Weekdays</c> at
/// <c>SendTime</c>) or as a reminder relative to a schedule slot. <c>SendAt</c> and <c>SendTime</c> are wall-clock values in <c>Tz</c>, not UTC.
/// <c>CreatedBy</c> is a member token, <c>CreatedByUserId</c> identity's user id.
/// </summary>
internal sealed class ClassScheduledNotification
{
    public int Id { get; set; }

    public int ClassId { get; set; }

    public int CreatedBy { get; set; }

    public int CreatedByUserId { get; set; }

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public string? ActionLink { get; set; }

    public string Kind { get; set; } = string.Empty;

    public DateTime? SendAt { get; set; }

    public string? Weekdays { get; set; }

    public TimeOnly? SendTime { get; set; }

    public string Tz { get; set; } = string.Empty;

    public int? ClassScheduleId { get; set; }

    public int? OffsetMinutes { get; set; }

    public short RepeatWeekly { get; set; }

    public string Status { get; set; } = "active";

    public DateTimeOffset? LastRunAt { get; set; }

    public string? LastRunKey { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>One firing of a scheduled notification, skipped ones included (PHP <c>class_scheduled_notification_runs</c>). <c>ClassId</c> is kept so a deleted item still counts toward the class limits.</summary>
internal sealed class ClassScheduledNotificationRun
{
    public int Id { get; set; }

    public int ScheduledId { get; set; }

    public int ClassId { get; set; }

    public DateTimeOffset RunAt { get; set; }

    public int? NotificationId { get; set; }

    public int StudentCount { get; set; }

    public int DeviceCount { get; set; }

    public int SuccessCount { get; set; }

    public int FailureCount { get; set; }

    public string? SkippedReason { get; set; }
}

/// <summary>
/// A weekly event a class's sender put on its students' calendars (PHP <c>class_scheduled_events</c>): <c>Weekdays</c> ("1,3,5", 1 = Monday) at <c>SendTime</c>, a wall-clock time in <c>Tz</c>
/// (the creator's zone, kept across edits). Soft-deleted: <c>Status</c> "deleted" with <c>DeletedAt</c>. <c>CreatedBy</c> is a member token, <c>CreatedByUserId</c> identity's user id.
/// </summary>
internal sealed class ClassScheduledEvent
{
    public int Id { get; set; }

    public int ClassId { get; set; }

    public int CreatedBy { get; set; }

    public int CreatedByUserId { get; set; }

    public string Message { get; set; } = string.Empty;

    public string? Description { get; set; }

    public string? ActionLink { get; set; }

    public string Weekdays { get; set; } = string.Empty;

    public TimeOnly SendTime { get; set; }

    public string Tz { get; set; } = string.Empty;

    public string Status { get; set; } = "active";

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }
}

/// <summary>
/// A member's own alert setting for one calendar item (PHP <c>member_event_settings</c>), synced between their phones: <c>EventKey</c> is <c>event:&lt;id&gt;</c> or <c>slot:&lt;id&gt;</c>,
/// <c>DeletedForMe</c> is a tombstone that never clears, <c>ClientUpdatedAt</c> (the phone's time, whole milliseconds) and <c>DeviceKey</c> decide the last writer. <c>UserId</c> is identity's user id.
/// </summary>
internal sealed class MemberEventSetting
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public int ClassId { get; set; }

    public string EventKey { get; set; } = string.Empty;

    public int? OffsetMinutes { get; set; }

    public short Muted { get; set; }

    public short DeletedForMe { get; set; }

    public DateTimeOffset ClientUpdatedAt { get; set; }

    public DateTimeOffset ServerUpdatedAt { get; set; }

    public string DeviceKey { get; set; } = string.Empty;
}
