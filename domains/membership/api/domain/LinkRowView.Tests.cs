using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>The link row as PHP's PDO rows read: keys in the SELECT's order, dates as "Y-m-d H:i:s", nulls as null.</summary>
public sealed class LinkRowViewTests
{
    private static readonly LinkRow Active = new(
        5, 900211, 900212, "father", "active", "token_entry",
        new DateTimeOffset(2026, 1, 10, 9, 0, 0, TimeSpan.Zero), new DateTimeOffset(2026, 1, 10, 9, 0, 5, TimeSpan.Zero), null);

    [Test]
    public void A_parents_list_row_has_child_name_in_PHPs_key_order()
    {
        var row = LinkRowView.Build(Active, LinkRowView.ChildName, "Synthetic Child", "Synthetic Parent");

        Assert.That(
            row.Select(p => p.Key),
            Is.EqualTo(["id", "parent_token", "child_token", "child_name", "relationship", "status", "source", "created_at", "created_by_name", "activated_at", "revoked_at"]));
        Assert.That(row["id"]!.GetValue<int>(), Is.EqualTo(5));
        Assert.That(row["created_at"]!.GetValue<string>(), Is.EqualTo("2026-01-10 09:00:00"));
        Assert.That(row["activated_at"]!.GetValue<string>(), Is.EqualTo("2026-01-10 09:00:05"));
        Assert.That(row["revoked_at"], Is.Null);
        Assert.That(row["created_by_name"]!.GetValue<string>(), Is.EqualTo("Synthetic Parent"));
    }

    [Test]
    public void The_children_side_uses_parent_name_in_the_same_position()
    {
        var row = LinkRowView.Build(Active, LinkRowView.ParentName, "Synthetic Parent", null);

        Assert.That(row.Select(p => p.Key).ElementAt(3), Is.EqualTo("parent_name"));
        Assert.That(row["parent_name"]!.GetValue<string>(), Is.EqualTo("Synthetic Parent"));
    }

    [Test]
    public void A_missing_member_or_name_is_null_but_an_empty_name_stays_empty()
    {
        Assert.That(LinkRowView.Build(Active, LinkRowView.ChildName, null, null)["child_name"], Is.Null);
        Assert.That(LinkRowView.Build(Active, LinkRowView.ChildName, string.Empty, null)["child_name"]!.GetValue<string>(), Is.EqualTo(string.Empty));
    }

    [Test]
    public void The_creator_of_an_accepted_invite_is_shown_as_Invite_link_and_a_missing_creator_as_Unknown()
    {
        var invite = Active with { Source = "link" };

        Assert.That(LinkRowView.Build(invite, LinkRowView.ChildName, "x", "Staff Person")["created_by_name"]!.GetValue<string>(), Is.EqualTo("Invite link"));
        Assert.That(LinkRowView.Build(Active, LinkRowView.ChildName, "x", null)["created_by_name"]!.GetValue<string>(), Is.EqualTo("Unknown"));
        Assert.That(LinkRowView.Build(Active, LinkRowView.ChildName, "x", string.Empty)["created_by_name"]!.GetValue<string>(), Is.EqualTo(string.Empty));
    }

    [Test]
    public void A_revoked_row_carries_its_revoked_time_and_a_null_parent_stays_null()
    {
        var revoked = Active with { Status = "revoked", ParentToken = null, RevokedAt = new DateTimeOffset(2026, 1, 11, 9, 0, 0, TimeSpan.FromHours(2)) };

        var row = LinkRowView.Build(revoked, LinkRowView.ChildName, "x", "y");

        Assert.That(row["parent_token"], Is.Null);
        Assert.That(row["revoked_at"]!.GetValue<string>(), Is.EqualTo("2026-01-11 07:00:00"), "always UTC");
    }
}
