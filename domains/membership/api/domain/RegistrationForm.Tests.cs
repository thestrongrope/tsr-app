using System.Text;
using System.Text.Json;
using NUnit.Framework;
using Tsr.Membership.Api.Domain;

namespace Tsr.Membership.Api.Tests.Domain;

/// <summary>POST /registration's reading of the body: required fields, trimming, whitelists, casts, lists. PHP: routes/registration.php.</summary>
public sealed class RegistrationFormTests
{
    private static readonly RegistrationLabels Labels = new(
        Education: ["Graduate (Bachelor's Degree)", "Doctorate"],
        FieldOfStudy: ["Law", "Science", "Research (syllabus/articles)"],
        ProfessionalCourses: ["CPA", "PMP"],
        OccupationType: ["Salaried Professional"],
        FieldOfWork: ["Education"],
        YearsExperience: ["3-5 years"],
        RoleLevel: ["Manager"]);

    private static JsonBody Body(string json) => JsonBody.Parse(Encoding.UTF8.GetBytes(json)).Value!;

    private const string Required = "\"preferredLocation\":\"Zurich\",\"birthYear\":1990,\"islamicStudyYears\":5";

    [TestCase("{}")]
    [TestCase("{\"birthYear\":1990,\"islamicStudyYears\":5}")]
    [TestCase("{\"preferredLocation\":\"  \",\"birthYear\":1990,\"islamicStudyYears\":5}")]
    [TestCase("{\"preferredLocation\":\"Z\",\"islamicStudyYears\":5}")]
    [TestCase("{\"preferredLocation\":\"Z\",\"birthYear\":\"\",\"islamicStudyYears\":5}")]
    [TestCase("{\"preferredLocation\":\"Z\",\"birthYear\":1990}")]
    [TestCase("{\"preferredLocation\":\"Z\",\"birthYear\":1990,\"islamicStudyYears\":null}")]
    [TestCase("{\"preferredLocation\":\"Z\",\"birthYear\":1990,\"islamicStudyYears\":false}")]
    public void A_missing_or_blank_required_field_is_refused(string json) =>
        Assert.That(RegistrationForm.CheckRequired(Body(json)), Is.EqualTo("preferredLocation, birthYear and islamicStudyYears are required"));

    [Test]
    public void Zero_study_years_are_accepted_and_the_body_is_not_checked_further()
    {
        Assert.That(RegistrationForm.CheckRequired(Body("{\"preferredLocation\":\"Z\",\"birthYear\":\"abc\",\"islamicStudyYears\":\"0\"}")), Is.Null);
        Assert.That(RegistrationForm.CheckRequired(Body("{\"preferredLocation\":\"Z\",\"birthYear\":1,\"islamicStudyYears\":0}")), Is.Null);
    }

    [Test]
    public void Required_fields_are_trimmed_and_cast_with_no_range_check()
    {
        var input = RegistrationForm.Build(Body("{\"preferredLocation\":\"  Zurich \",\"birthYear\":\" 1990x\",\"islamicStudyYears\":\"abc\"}"), Labels);

        Assert.That(input.PreferredLocation, Is.EqualTo("Zurich"));
        Assert.That(input.BirthYear, Is.EqualTo(1990));
        Assert.That(input.IslamicStudyYears, Is.EqualTo(0));
    }

    [Test]
    public void A_boolean_or_array_in_a_required_field_is_text_like_any_other()
    {
        var input = RegistrationForm.Build(Body("{\"preferredLocation\":[\"x\"],\"birthYear\":true,\"islamicStudyYears\":3.9}"), Labels);

        Assert.That(input.PreferredLocation, Is.EqualTo("Array"));
        Assert.That(input.BirthYear, Is.EqualTo(1));
        Assert.That(input.IslamicStudyYears, Is.EqualTo(3));
    }

    [TestCase("https://www.linkedin.com/in/some-person", "https://www.linkedin.com/in/some-person")]
    [TestCase("  HTTP://LinkedIn.com/company/Acme_1 ", "HTTP://LinkedIn.com/company/Acme_1")]
    [TestCase("https://linkedin.com/pub/x trailing junk", "https://linkedin.com/pub/x trailing junk")]
    public void A_linkedin_address_is_kept_as_typed_after_trimming(string typed, string stored) =>
        Assert.That(RegistrationForm.Build(Body("{" + Required + ",\"linkedinUrl\":\"" + typed + "\"}"), Labels).LinkedinUrl, Is.EqualTo(stored));

    [TestCase("")]
    [TestCase("https://example.com/in/x")]
    [TestCase("https://www.linkedin.com/in/")]
    [TestCase("https://www.linkedin.com/groups/x")]
    [TestCase("ftp://www.linkedin.com/in/x")]
    [TestCase("https://www.linkedin.com/in/\\u00e9\\u00e9")]
    [TestCase("https://www.linkedin.com/in/\\u212a")]
    public void Any_other_linkedin_value_becomes_null(string typed) =>
        Assert.That(RegistrationForm.Build(Body("{" + Required + ",\"linkedinUrl\":\"" + typed + "\"}"), Labels).LinkedinUrl, Is.Null);

    [Test]
    public void Free_text_is_trimmed_and_empty_becomes_null()
    {
        var input = RegistrationForm.Build(Body("{" + Required + ",\"residenceLocation\":\" Basel \",\"workLocation\":\"   \",\"otherInterests\":null,\"fieldOfStudyOther\":\"x\"}"), Labels);

        Assert.That(input.ResidenceLocation, Is.EqualTo("Basel"));
        Assert.That(input.WorkLocation, Is.Null);
        Assert.That(input.OtherInterests, Is.Null);
        Assert.That(input.FieldOfStudyOther, Is.EqualTo("x"));
        Assert.That(input.ProfessionalCoursesOther, Is.Null);
    }

    [Test]
    public void A_dropdown_keeps_a_value_equal_to_a_label_after_trim_and_nulls_anything_else()
    {
        var input = RegistrationForm.Build(
            Body("{" + Required + ",\"education\":\" Doctorate \",\"occupationType\":\"salaried professional\",\"fieldOfWork\":\"Education\",\"yearsExperience\":\"3-5 YEARS\",\"roleLevel\":7}"),
            Labels);

        Assert.That(input.Education, Is.EqualTo("Doctorate"));
        Assert.That(input.OccupationType, Is.Null, "case-sensitive");
        Assert.That(input.FieldOfWork, Is.EqualTo("Education"));
        Assert.That(input.YearsExperience, Is.Null);
        Assert.That(input.RoleLevel, Is.Null);
    }

    [Test]
    public void A_multi_select_keeps_the_labelled_values_trimmed_in_order_with_duplicates_and_stores_JSON()
    {
        var input = RegistrationForm.Build(Body("{" + Required + ",\"fieldOfStudy\":[\"Law\",\"Nope\",\" Science \",\"Law\",\"Research (syllabus/articles)\"]}"), Labels);

        Assert.That(JsonSerializer.Deserialize<string[]>(input.FieldOfStudy!), Is.EqualTo(["Law", "Science", "Law", "Research (syllabus/articles)"]));
    }

    [Test]
    public void A_multi_select_with_nothing_valid_or_not_a_list_is_null()
    {
        Assert.That(RegistrationForm.Build(Body("{" + Required + ",\"fieldOfStudy\":[\"Nope\"]}"), Labels).FieldOfStudy, Is.Null);
        Assert.That(RegistrationForm.Build(Body("{" + Required + ",\"fieldOfStudy\":[]}"), Labels).FieldOfStudy, Is.Null);
        Assert.That(RegistrationForm.Build(Body("{" + Required + ",\"professionalCourses\":\"CPA\"}"), Labels).ProfessionalCourses, Is.Null);
        Assert.That(RegistrationForm.Build(Body("{" + Required + "}"), Labels).ProfessionalCourses, Is.Null);
    }

    [Test]
    public void An_object_is_an_array_to_PHP_and_its_values_are_used()
    {
        var input = RegistrationForm.Build(Body("{" + Required + ",\"professionalCourses\":{\"a\":\"CPA\",\"b\":\"PMP\"}}"), Labels);

        Assert.That(JsonSerializer.Deserialize<string[]>(input.ProfessionalCourses!), Is.EqualTo(["CPA", "PMP"]));
    }

    [Test]
    public void An_array_inside_a_multi_select_is_a_PHP_TypeError_so_it_throws()
    {
        Assert.Throws<InvalidOperationException>(() => RegistrationForm.Build(Body("{" + Required + ",\"fieldOfStudy\":[[\"Law\"]]}"), Labels));
    }
}
