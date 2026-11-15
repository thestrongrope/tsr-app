using System.Text.Json;
using NUnit.Framework;

namespace Tsr.Classes.Api.Domain;

[TestFixture]
internal sealed class TeacherTrainingTests
{
    private static JsonElement Json(string text) => JsonElement.Parse(text);

    [TestCase("""{"token": 5, "level": "salman", "action": "added"}""", 5, "salman", true)]
    [TestCase("""{"token": "7", "level": "bilal", "action": "removed"}""", 7, "bilal", false)]
    [TestCase("""{"token": 7.9, "level": "ammar", "action": "added"}""", 7, "ammar", true)]
    public void A_well_formed_change_is_read(string json, int token, string level, bool added) =>
        Assert.That(TeacherTraining.ReadChange(Json(json)), Is.EqualTo(new TeacherTraining.Change(token, level, added)));

    [TestCase("5")]
    [TestCase("[1, 2, 3]")]
    [TestCase("""{"token": 5, "level": "salman"}""")]
    [TestCase("""{"token": null, "level": "salman", "action": "added"}""")]
    [TestCase("""{"token": "abc", "level": "salman", "action": "added"}""")]
    [TestCase("""{"token": true, "level": "salman", "action": "added"}""")]
    [TestCase("""{"token": 5, "level": "Salman", "action": "added"}""")]
    [TestCase("""{"token": 5, "level": 3, "action": "added"}""")]
    [TestCase("""{"token": 5, "level": "zayd", "action": "added"}""")]
    [TestCase("""{"token": 5, "level": "salman", "action": "Added"}""")]
    [TestCase("""{"token": 5, "level": "salman", "action": true}""")]
    public void A_change_of_the_wrong_shape_is_refused(string json) =>
        Assert.That(TeacherTraining.ReadChange(Json(json)), Is.Null);

    [Test]
    public void The_comment_of_an_existing_teacher_lists_only_the_levels_that_flipped_in_order()
    {
        var before = new TeacherTraining.Flags(1, 0, 0, 0, 1);
        var after = new TeacherTraining.Flags(1, 1, 0, 0, 0);
        Assert.That(TeacherTraining.Comment(existing: before, after, "B4 note", "abc"), Is.EqualTo("UPDATE: B4 note - Batch ID: abc - +AG, -BL"));
    }

    [Test]
    public void A_change_that_flips_nothing_leaves_the_list_empty_after_its_separator()
    {
        var flags = new TeacherTraining.Flags(1, 0, 0, 0, 0);
        Assert.That(TeacherTraining.Comment(flags, flags, "same", "abc"), Is.EqualTo("UPDATE: same - Batch ID: abc - "));
    }

    [Test]
    public void The_comment_of_a_new_teacher_lists_every_level_switched_on()
    {
        Assert.That(TeacherTraining.Comment(existing: null, new TeacherTraining.Flags(0, 1, 1, 0, 0), "first", "abc"), Is.EqualTo("ADD: first - Batch ID: abc - +AG, +MK"));
        Assert.That(TeacherTraining.Comment(existing: null, new TeacherTraining.Flags(0, 0, 0, 0, 0), "none", "abc"), Is.EqualTo("ADD: none - Batch ID: abc - "));
    }

    [TestCase(1, 1, 1, 1, 1, 1)]
    [TestCase(2, 0, 1, 1, 1, 1)]
    [TestCase(3, 0, 0, 1, 1, 1)]
    [TestCase(4, 0, 0, 0, 1, 1)]
    [TestCase(5, 0, 0, 0, 0, 1)]
    [TestCase(6, 0, 0, 0, 0, 0)]
    public void An_imported_teacher_is_trained_for_the_level_taught_and_those_above_it_salman_only_when_it_is_exactly_one(int level, int s, int a, int m, int y, int b) =>
        Assert.That(TeacherTraining.ImportedFlags(level), Is.EqualTo(new TeacherTraining.Flags(s, a, m, y, b)));

    [Test]
    public void A_batch_id_is_PHPs_uniqid_thirteen_hex_digits_of_the_time()
    {
        var id = TeacherTraining.BatchId(new DateTimeOffset(2025, 1, 2, 3, 4, 5, TimeSpan.Zero).AddTicks(12340));
        Assert.That(id, Does.Match("^[0-9a-f]{13}$"));
        Assert.That(id[..8], Is.EqualTo(((long)new DateTimeOffset(2025, 1, 2, 3, 4, 5, TimeSpan.Zero).ToUnixTimeSeconds()).ToString("x8", System.Globalization.CultureInfo.InvariantCulture)));
    }
}
