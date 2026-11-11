using Microsoft.EntityFrameworkCore;
using Tsr.Shared.Api;

namespace Tsr.Notifications.Api;

/// <summary>
/// notifications' tables, schema "notifications": push notifications and who got them, member devices, the WhatsApp reminders of the
/// notifier (its settings, runs and sent messages) and the notifications scheduled for a class. Names, keys and indexes follow PHP's, so
/// the data move is a copy. A class, a schedule slot or a member is a plain integer (another domain's row); the two foreign keys PHP
/// declares (user_notifications to notifications, notifier_sent_messages to notifier_runs) stay inside the schema.
/// Wall-clock columns, which are not instants: <c>class_scheduled_notifications.send_at</c> is a <c>timestamp without time zone</c>, and
/// <c>send_time</c> here and in <c>notifier_reminders</c> is a <c>time</c>; both are read in the row's own <c>tz</c> or <c>timezone</c>.
/// Every other <c>datetime</c> or <c>timestamp</c> is <c>timestamptz</c>, read as UTC.
/// </summary>
internal sealed class NotificationsContext(DbContextOptions<NotificationsContext> options) : TsrDbContext(options, SchemaName)
{
    public const string SchemaName = "notifications";

    private const string Now = "now()";

    public DbSet<Notification> Notifications => Set<Notification>();

    public DbSet<UserNotification> UserNotifications => Set<UserNotification>();

    public DbSet<UserDevice> UserDevices => Set<UserDevice>();

    public DbSet<NotifierReminder> NotifierReminders => Set<NotifierReminder>();

    public DbSet<NotifierRun> NotifierRuns => Set<NotifierRun>();

    public DbSet<NotifierSentMessage> NotifierSentMessages => Set<NotifierSentMessage>();

    public DbSet<ClassScheduledNotification> ClassScheduledNotifications => Set<ClassScheduledNotification>();

    public DbSet<ClassScheduledNotificationRun> ClassScheduledNotificationRuns => Set<ClassScheduledNotificationRun>();

    protected override void Configure(ModelBuilder modelBuilder)
    {
        ConfigureNotifications(modelBuilder);
        ConfigureNotifier(modelBuilder);
        ConfigureScheduled(modelBuilder);
    }

    private static void ConfigureNotifications(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Notification>(notification =>
        {
            notification.HasKey(n => n.NotificationId);
            notification.Property(n => n.Title).HasMaxLength(255);
            notification.Property(n => n.Body).HasMaxLength(65535);
            notification.Property(n => n.SentAt).HasDefaultValueSql(Now);
            notification.Property(n => n.DeviceCount).HasDefaultValue(0);
            notification.Property(n => n.SuccessCount).HasDefaultValue(0);
            notification.Property(n => n.FailureCount).HasDefaultValue(0);
            notification.Property(n => n.Priority).HasMaxLength(20).HasDefaultValue("NORMAL");
            notification.Property(n => n.ImageUrl).HasMaxLength(500);
            notification.Property(n => n.ActionLink).HasMaxLength(500);
            notification.HasIndex(n => n.CreatedBy).HasDatabaseName("idx_created_by");
            notification.HasIndex(n => n.SentAt).HasDatabaseName("idx_sent_at");
            notification.ToTable(t => t.HasCheckConstraint("ck_notifications_target_audience_criteria_json", CheckSql.IsJson("target_audience_criteria")));
        });

        modelBuilder.Entity<UserNotification>(item =>
        {
            item.Property(i => i.IsRead).HasDefaultValue((short)0);
            item.Property(i => i.CreatedAt).HasDefaultValueSql(Now);
            item.HasIndex(i => new { i.NotificationId, i.UserToken }).IsUnique().HasDatabaseName("unique_user_notification");
            item.HasIndex(i => i.UserToken).HasDatabaseName("idx_user_token");
            item.HasIndex(i => new { i.UserToken, i.IsRead }).HasDatabaseName("idx_user_unread");
            item.HasOne<Notification>().WithMany().HasForeignKey(i => i.NotificationId).OnDelete(DeleteBehavior.Cascade)
                .HasConstraintName("fk_user_notifications_notification");
        });

        modelBuilder.Entity<UserDevice>(device =>
        {
            device.Property(d => d.DeviceId).HasMaxLength(500);
            device.Property(d => d.LastAccessedAt).HasDefaultValueSql(Now);
            device.Property(d => d.RegisteredAt).HasDefaultValueSql(Now);
        });
    }

    private static void ConfigureNotifier(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<NotifierReminder>(reminder =>
        {
            reminder.Property(r => r.Name).HasMaxLength(80);
            reminder.Property(r => r.Type).HasMaxLength(40).HasDefaultValue("cform_missing");
            reminder.Property(r => r.Gender).HasMaxLength(10).HasDefaultValue("gents");
            reminder.Property(r => r.City).HasMaxLength(100);
            reminder.Property(r => r.Country).HasMaxLength(100);
            reminder.Property(r => r.Levels).HasMaxLength(255).HasDefaultValue("BILAL,AMMAR,MIQDAD,ABUZAR");
            reminder.Property(r => r.Lang).HasMaxLength(20).HasDefaultValue("english");
            reminder.Property(r => r.LeewayDays).HasDefaultValue((short)10);
            reminder.Property(r => r.Timezone).HasMaxLength(64).HasDefaultValue("Asia/Kolkata");
            reminder.Property(r => r.ScheduleOn).HasDefaultValue((short)0);
            reminder.Property(r => r.Enabled).HasDefaultValue((short)1);
            reminder.Property(r => r.UpdatedAt).HasDefaultValueSql(Now);
            reminder.HasIndex(r => r.Name).IsUnique().HasDatabaseName("uq_notifier_reminders_name");
        });

        modelBuilder.Entity<NotifierRun>(run =>
        {
            run.Property(r => r.StartedAt).HasDefaultValueSql(Now);
            run.Property(r => r.Status).HasMaxLength(20).HasDefaultValue("running");
            run.Property(r => r.SentCount).HasDefaultValue(0);
            run.Property(r => r.SkippedCount).HasDefaultValue(0);
            run.Property(r => r.FailedCount).HasDefaultValue(0);
            run.Property(r => r.DryRun).HasDefaultValue((short)0);
            run.Property(r => r.ErrorMessage).HasMaxLength(65535);
            run.HasIndex(r => r.StartedAt).HasDatabaseName("idx_started_at");
            run.HasIndex(r => r.Status).HasDatabaseName("idx_status");
            run.HasIndex(r => new { r.ReminderId, r.StartedAt }).HasDatabaseName("idx_reminder_started");
            run.ToTable(t => t.HasCheckConstraint("ck_notifier_runs_settings_snapshot_json", CheckSql.IsJson("settings_snapshot")));
        });

        modelBuilder.Entity<NotifierSentMessage>(message =>
        {
            message.Property(m => m.TeacherMobile).HasMaxLength(20);
            message.Property(m => m.TeacherName).HasMaxLength(150);
            message.Property(m => m.MessageExcerpt).HasMaxLength(500);
            message.Property(m => m.Status).HasMaxLength(20);
            message.Property(m => m.Error).HasMaxLength(65535);
            message.Property(m => m.SentAt).HasDefaultValueSql(Now);
            message.HasIndex(m => m.RunId).HasDatabaseName("idx_run_id");
            message.HasIndex(m => new { m.TeacherMobile, m.SentAt }).HasDatabaseName("idx_mobile_sent_at");
            message.HasOne<NotifierRun>().WithMany().HasForeignKey(m => m.RunId).OnDelete(DeleteBehavior.Cascade)
                .HasConstraintName("fk_notifier_sent_run");
        });
    }

    private static void ConfigureScheduled(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ClassScheduledNotification>(item =>
        {
            item.Property(i => i.Title).HasMaxLength(255);
            item.Property(i => i.Body).HasMaxLength(65535);
            item.Property(i => i.ActionLink).HasMaxLength(500);
            item.Property(i => i.Kind).HasMaxLength(8);
            item.Property(i => i.SendAt).HasColumnType("timestamp without time zone");
            item.Property(i => i.Weekdays).HasMaxLength(20);
            item.Property(i => i.Tz).HasMaxLength(64);
            item.Property(i => i.RepeatWeekly).HasDefaultValue((short)0);
            item.Property(i => i.Status).HasMaxLength(6).HasDefaultValue("active");
            item.Property(i => i.LastRunKey).HasMaxLength(100);
            item.Property(i => i.CreatedAt).HasDefaultValueSql(Now);
            item.Property(i => i.UpdatedAt).HasDefaultValueSql(Now);
            item.HasIndex(i => new { i.Status, i.Kind }).HasDatabaseName("idx_status_kind");
            item.HasIndex(i => i.ClassId).HasDatabaseName("idx_class_id");
            item.ToTable(t =>
            {
                t.HasCheckConstraint("ck_class_scheduled_notifications_kind", CheckSql.In("kind", "ONCE", "WEEKLY", "REMINDER"));
                t.HasCheckConstraint("ck_class_scheduled_notifications_status", CheckSql.In("status", "active", "done"));
            });
        });

        modelBuilder.Entity<ClassScheduledNotificationRun>(run =>
        {
            run.Property(r => r.RunAt).HasDefaultValueSql(Now);
            run.Property(r => r.StudentCount).HasDefaultValue(0);
            run.Property(r => r.DeviceCount).HasDefaultValue(0);
            run.Property(r => r.SuccessCount).HasDefaultValue(0);
            run.Property(r => r.FailureCount).HasDefaultValue(0);
            run.Property(r => r.SkippedReason).HasMaxLength(100);
            run.HasIndex(r => r.ScheduledId).HasDatabaseName("idx_scheduled_id");
            run.HasIndex(r => r.RunAt).HasDatabaseName("idx_run_at");
            run.HasIndex(r => new { r.ClassId, r.RunAt }).HasDatabaseName("idx_class_run_at");
        });
    }
}
