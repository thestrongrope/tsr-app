using NUnit.Framework;

namespace Tsr.Identity.Api;

public sealed class DeletionViewsTests
{
    private static DeletionRow Row(string status, DateTimeOffset? confirmed = null, int? token = 900001, string? note = null) =>
        new(7, status, "app", token, "Synthetic Member", "member@example.invalid", "12345", "5550100", null, null,
            new DateTimeOffset(2026, 11, 1, 10, 30, 0, TimeSpan.Zero), null, note, confirmed, null, null, null, null);

    [Test]
    public void No_request_is_the_none_shape_with_every_key()
    {
        var view = DeletionViews.MemberView(null);

        Assert.That(view["id"], Is.Null);
        Assert.That(view["status"], Is.EqualTo("none"));
        Assert.That(view["requested_at"], Is.Null);
        Assert.That(view["expected_completion_days"], Is.EqualTo(60));
        Assert.That(view["message"], Is.Null);
    }

    [Test]
    public void A_held_request_shows_the_note_or_the_prize_message()
    {
        Assert.That(DeletionViews.Message("awaiting_prize_delivery", "Your prize is on its way"), Is.EqualTo("Your prize is on its way"));
        Assert.That(DeletionViews.Message("awaiting_prize_delivery", "   "), Is.EqualTo(DeletionViews.PrizeMessage));
        Assert.That(DeletionViews.Message("awaiting_prize_delivery", null), Is.EqualTo(DeletionViews.PrizeMessage));
        Assert.That(DeletionViews.Message("pending", "ignored"), Is.EqualTo(DeletionViews.PendingMessage));
        Assert.That(DeletionViews.Message("completed", null), Is.Null);
    }

    [Test]
    public void The_admin_view_offers_the_email_only_until_it_is_recorded()
    {
        var unconfirmed = DeletionViews.AdminView(Row("pending"), []);
        var confirmed = DeletionViews.AdminView(Row("pending", DateTimeOffset.UnixEpoch), []);

        Assert.That(unconfirmed["confirmation"], Is.Not.Null);
        Assert.That(unconfirmed["can_complete"], Is.EqualTo(false));
        Assert.That(confirmed["confirmation"], Is.Null);
        Assert.That(confirmed["can_complete"], Is.EqualTo(true));
    }

    [Test]
    public void A_demo_member_or_the_guest_can_never_be_completed()
    {
        var stamp = DateTimeOffset.UnixEpoch;

        Assert.That(DeletionViews.AdminView(Row("pending", stamp), [900001])["can_complete"], Is.EqualTo(false));
        Assert.That(DeletionViews.AdminView(Row("pending", stamp, token: 0), [])["can_complete"], Is.EqualTo(false));
        Assert.That(DeletionViews.AdminView(Row("completed", stamp), [])["can_complete"], Is.EqualTo(false));
    }

    [Test]
    public void The_postal_code_and_mobile_show_only_while_held()
    {
        Assert.That(DeletionViews.AdminView(Row("pending"), [])["member_zip"], Is.Null);
        Assert.That(DeletionViews.AdminView(Row("awaiting_prize_delivery"), [])["member_zip"], Is.EqualTo("12345"));
        Assert.That(DeletionViews.AdminView(Row("awaiting_prize_delivery"), [])["member_mobile"], Is.EqualTo("5550100"));
    }

    [Test]
    public void Times_are_iso_without_a_zone()
    {
        Assert.That(DeletionViews.Stamp(new DateTimeOffset(2026, 11, 1, 10, 30, 5, TimeSpan.Zero)), Is.EqualTo("2026-11-01T10:30:05"));
        Assert.That(DeletionViews.Stamp(null), Is.Null);
    }

    [Test]
    public void The_confirmation_greets_by_name_or_there()
    {
        Assert.That(DeletionViews.ConfirmationEmail("  Sam ").Body, Does.StartWith("Dear Sam,\n\n"));
        Assert.That(DeletionViews.ConfirmationEmail("").Body, Does.StartWith("Dear there,\n\n"));
    }
}
