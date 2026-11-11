using System.Text.Json;
using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>The languages map, the interest ids and the stored form's read-back (PHP: SubscribersModel::saveLanguageProficiencies, saveStudentInterests, routes/registration.php).</summary>
public sealed class RegistrationPartsTests
{
    private static JsonElement Json(string json) => JsonElement.Parse(json, new JsonDocumentOptions { AllowDuplicateProperties = true });

    [TestCase("null")]
    [TestCase("[]")]
    [TestCase("{}")]
    [TestCase("\"English\"")]
    [TestCase("5")]
    public void Languages_that_are_missing_empty_or_not_an_array_leave_the_saved_ones_alone(string json) =>
        Assert.That(RegistrationParts.Languages(Json(json)), Is.Null);

    [Test]
    public void Valid_entries_are_kept_in_order_and_Dont_Know_is_dropped()
    {
        var entries = RegistrationParts.Languages(Json(
            "{\"English\":{\"Read\":\"Fluent\",\"Write\":\"Don't Know\",\"Speak\":\"Beginner\"},\"Urdu\":{\"Understand\":\"Learning\"}}"))!;

        Assert.That(
            entries.Select(e => e.Language + "/" + e.Skill + "/" + e.Proficiency),
            Is.EqualTo(["English/Read/Fluent", "English/Speak/Beginner", "Urdu/Understand/Learning"]));
    }

    [Test]
    public void A_non_empty_map_of_only_invalid_entries_still_replaces_with_nothing()
    {
        var entries = RegistrationParts.Languages(Json("{\"Klingon\":{\"Read\":\"Fluent\"},\"English\":{\"Fly\":\"Fluent\",\"Read\":\"fluent\",\"Write\":5},\"Hindi\":\"x\"}"));

        Assert.That(entries, Is.Not.Null);
        Assert.That(entries, Is.Empty);
    }

    [Test]
    public void A_non_empty_list_replaces_with_nothing_because_its_keys_are_numbers()
    {
        Assert.That(RegistrationParts.Languages(Json("[{\"Read\":\"Fluent\"}]")), Is.Empty);
    }

    [Test]
    public void A_repeated_skill_keeps_its_last_value()
    {
        var entries = RegistrationParts.Languages(Json("{\"English\":{\"Read\":\"Fluent\",\"Read\":\"Learning\"}}"))!;

        Assert.That(entries.Select(e => e.Proficiency), Is.EqualTo(["Learning"]));
    }

    private static readonly IReadOnlySet<int> Active = new HashSet<int> { 1, 9, 11, 13 };

    [TestCase("null")]
    [TestCase("\"11\"")]
    [TestCase("5")]
    public void Interest_ids_that_are_not_an_array_leave_the_saved_ones_alone(string json) =>
        Assert.That(RegistrationParts.InterestIds(Json(json), Active), Is.Null);

    [Test]
    public void An_empty_array_clears_and_an_object_counts_as_an_array()
    {
        Assert.That(RegistrationParts.InterestIds(Json("[]"), Active), Is.Empty);
        Assert.That(RegistrationParts.InterestIds(Json("{\"a\":11}"), Active), Is.EqualTo([11]));
    }

    [Test]
    public void Ids_are_int_cast_filtered_to_active_options_and_keep_order_and_duplicates()
    {
        var ids = RegistrationParts.InterestIds(Json("[13,\"11\",999,\"9x\",11,true,null,[1],\"abc\"]"), Active)!;

        Assert.That(ids, Is.EqualTo([13, 11, 9, 11, 1, 1]), "true and [1] are the integer 1; null and abc are 0 and not an option");
    }

    [Test]
    public void A_stored_list_is_read_back_as_a_list_and_anything_else_as_empty()
    {
        Assert.That(RegistrationView.DecodeList("[\"Law\", \"Science\"]").Select(n => n!.GetValue<string>()), Is.EqualTo(["Law", "Science"]));
        Assert.That(RegistrationView.DecodeList(null), Is.Empty);
        Assert.That(RegistrationView.DecodeList(string.Empty), Is.Empty);
        Assert.That(RegistrationView.DecodeList("\"x\""), Is.Empty);
        Assert.That(RegistrationView.DecodeList("not json"), Is.Empty);
        Assert.That(RegistrationView.DecodeList("{\"a\":\"Law\"}").Select(n => n!.GetValue<string>()), Is.EqualTo(["Law"]));
    }

    [Test]
    public void Languages_read_back_as_a_nested_map_in_row_order_and_empty_is_an_empty_object()
    {
        var map = RegistrationView.Languages(
        [
            new("English", "Read", "Fluent"), new("Urdu", "Read", "Learning"), new("English", "Speak", "Fluent"),
        ]);

        Assert.That(map.ToJsonString(), Is.EqualTo("{\"English\":{\"Read\":\"Fluent\",\"Speak\":\"Fluent\"},\"Urdu\":{\"Read\":\"Learning\"}}"));
        Assert.That(RegistrationView.Languages([]).ToJsonString(), Is.EqualTo("{}"));
    }

    [Test]
    public void The_payload_has_PHPs_keys_in_PHPs_order_and_raw_values()
    {
        var row = new ClassRegistration
        {
            PreferredLocation = "Zurich", BirthYear = 1990, IslamicStudyYears = 0, FieldOfStudy = "[\"Law\"]",
            Education = "Doctorate", OtherInterests = "O&#039;x", Status = "Accepted",
        };

        var payload = RegistrationView.Payload(row);

        Assert.That(
            payload.Select(p => p.Key),
            Is.EqualTo(
            [
                "preferredLocation", "birthYear", "islamicStudyYears", "linkedinUrl", "residenceLocation", "workLocation", "education", "fieldOfStudy",
                "fieldOfStudyOther", "professionalCourses", "professionalCoursesOther", "occupationType", "fieldOfWork", "yearsExperience", "roleLevel",
                "otherInterests", "status",
            ]));
        Assert.That(payload["birthYear"]!.GetValue<int>(), Is.EqualTo(1990));
        Assert.That(payload["islamicStudyYears"]!.GetValue<int>(), Is.EqualTo(0));
        Assert.That(payload["otherInterests"]!.GetValue<string>(), Is.EqualTo("O&#039;x"), "not entity-decoded");
        Assert.That(payload["linkedinUrl"], Is.Null);
        Assert.That(payload["professionalCourses"]!.AsArray(), Is.Empty);
        Assert.That(payload["status"]!.GetValue<string>(), Is.EqualTo("Accepted"));
    }

    [Test]
    public void A_missing_birth_year_is_null()
    {
        Assert.That(RegistrationView.Payload(new ClassRegistration { PreferredLocation = "x" })["birthYear"], Is.Null);
    }
}
