using NUnit.Framework;

namespace Tsr.Membership.Api.Domain;

[TestFixture]
internal sealed class WaitingRegistrationsTests
{
    private static WaitingRegistrations.Row Row() => new(
        7, 901, null, "Pending", "2025-03-04", null, "a@b.invalid", "", "Res &amp; Co", "", null, "", "", null, null, null, null, null, null, null);

    [Test]
    public void Missing_or_empty_optional_texts_are_null_and_a_missing_name_is_empty()
    {
        var item = WaitingRegistrations.ToItem(Row());
        Assert.That(item.Name, Is.EqualTo(string.Empty));
        Assert.That(item.Mobile, Is.Null);
        Assert.That(item.Email, Is.EqualTo("a@b.invalid"));
        Assert.That(item.RequestedClass, Is.Null);
        Assert.That(item.RegisteredOn, Is.EqualTo("2025-03-04"));
    }

    [Test]
    public void The_free_texts_are_entity_decoded_but_the_short_codes_are_not_and_the_years_become_text()
    {
        var item = WaitingRegistrations.ToItem(Row() with { Residence = "Res &amp; Co", City = "A &amp; B", IslamicYears = 5, BirthYear = 1990 });
        Assert.That(item.ResidenceLocation, Is.EqualTo("Res & Co"));
        Assert.That(item.City, Is.EqualTo("A &amp; B"));
        Assert.That(item.IslamicStudyYears, Is.EqualTo("5"));
        Assert.That(item.BirthYear, Is.EqualTo(1990));
    }
}
