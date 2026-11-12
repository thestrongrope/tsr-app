using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using NUnit.Framework;

namespace Tsr.Notifications.Api.Tests;

/// <summary>The tables of schema "notifications", read from the model alone (no database). The migrated database is checked in db/tests.</summary>
public sealed class NotificationsContextTests
{
    private static readonly string[] Expected =
    [
        "class_scheduled_events",
        "class_scheduled_notification_runs",
        "class_scheduled_notifications",
        "member_event_settings",
        "notifications",
        "notifier_reminders",
        "notifier_runs",
        "notifier_sent_messages",
        "user_devices",
        "user_notifications",
    ];

    [Test]
    public void The_context_owns_exactly_the_ported_tables_in_its_schema()
    {
        var options = new DbContextOptionsBuilder<NotificationsContext>().UseNpgsql("Host=unused").Options;
        using var context = new NotificationsContext(options);

        var model = context.GetService<IDesignTimeModel>().Model;
        var tables = model.GetEntityTypes().Select(e => e.GetTableName()).Order().ToList();

        Assert.That(model.GetDefaultSchema(), Is.EqualTo("notifications"));
        Assert.That(tables, Is.EqualTo(Expected.Order().ToList()));
    }
}
