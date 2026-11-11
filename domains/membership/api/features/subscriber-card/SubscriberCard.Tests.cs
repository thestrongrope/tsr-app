using NUnit.Framework;
using Tsr.Membership.Api.Features.SubscriberCard;

namespace Tsr.Membership.Api.Tests.Features;

/// <summary>PHP EntityAccessModel::genderOf: 1 and 2, or the words Male and Female, else not recorded (the card differs from the children list's (int) cast).</summary>
public sealed class SubscriberCardTests
{
    [TestCase("1", 1)]
    [TestCase("Male", 1)]
    [TestCase("2", 2)]
    [TestCase("Female", 2)]
    [TestCase("male", null)]
    [TestCase("", null)]
    [TestCase(null, null)]
    [TestCase("3", null)]
    public void The_stored_gender_text_becomes_one_two_or_nothing(string? stored, int? expected) =>
        Assert.That(SubscriberCardSlice.GenderOf(stored), Is.EqualTo(expected));
}
