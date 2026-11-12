using System.Text;
using NUnit.Framework;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

[TestFixture]
internal sealed class OfflineBatchTests
{
    private static readonly HashSet<long> Questions = [10, 11];
    private static readonly HashSet<long> Enrolled = [5, 6];

    private static (IReadOnlyList<OfflineBatch.Entry>? Entries, OfflineBatch.Refusal? Refusal) Read(string json) =>
        OfflineBatch.Read(JsonBody.Parse(Encoding.UTF8.GetBytes(json)).Value!);

    [TestCase("{}")]
    [TestCase("""{"students":[]}""")]
    [TestCase("""{"students":"x"}""")]
    public void Students_must_be_a_non_empty_list(string json)
    {
        var (_, refusal) = Read(json);
        Assert.That(refusal, Is.EqualTo(new OfflineBatch.Refusal(422, "students is required")));
    }

    [TestCase("""{"students":[5]}""")]
    [TestCase("""{"students":[{"token":5}]}""")]
    [TestCase("""{"students":[{"token":5,"correct":"10"}]}""")]
    [TestCase("""{"students":[[1,2]]}""")]
    public void Each_student_needs_a_correct_list(string json)
    {
        var (_, refusal) = Read(json);
        Assert.That(refusal, Is.EqualTo(new OfflineBatch.Refusal(422, "each student needs a token and a correct list")));
    }

    [Test]
    public void A_batch_over_the_cap_is_refused_before_any_student_is_read()
    {
        var students = string.Join(',', Enumerable.Repeat("""{"token":5,"correct":[]}""", OfflineBatch.MaxStudents + 1));
        var (_, refusal) = Read($$"""{"students":[{{students}}]}""");
        Assert.That(refusal?.Status, Is.EqualTo(422));
    }

    [Test]
    public void A_repeated_token_keeps_its_first_place_and_its_last_list()
    {
        var (entries, refusal) = Read("""{"students":[{"token":5,"correct":[10]},{"token":6,"correct":[]},{"token":"5","correct":[11]}]}""");
        Assert.That(refusal, Is.Null);
        Assert.That(entries!.Select(e => e.Token), Is.EqualTo(new List<long> { 5, 6 }));
        Assert.That(entries![0].Correct.Single().GetInt32(), Is.EqualTo(11));
    }

    [Test]
    public void A_missing_token_is_malformed()
    {
        var (entries, _) = Read("""{"students":[{"correct":[]}]}""");
        var (_, refusal) = OfflineBatch.Plan(entries!, Questions, Enrolled);
        Assert.That(refusal, Is.EqualTo(new OfflineBatch.Refusal(400, "Malformed response payload.")));
    }

    [Test]
    public void A_student_not_in_the_class_is_403_and_the_first_refusal_wins()
    {
        var (entries, _) = Read("""{"students":[{"token":5,"correct":[99]},{"token":7,"correct":[]}]}""");
        var (_, refusal) = OfflineBatch.Plan(entries!, Questions, Enrolled);
        Assert.That(refusal, Is.EqualTo(new OfflineBatch.Refusal(400, "Question 99 does not belong to this quiz.")));
        (entries, _) = Read("""{"students":[{"token":7,"correct":[99]}]}""");
        Assert.That(OfflineBatch.Plan(entries!, Questions, Enrolled).Refusal, Is.EqualTo(new OfflineBatch.Refusal(403, "Student 7 is not enrolled in this class.")));
    }

    [Test]
    public void Question_ids_are_read_as_integers_and_repeats_count_once()
    {
        var (entries, _) = Read("""{"students":[{"token":5,"correct":["10",10.9,11]}]}""");
        var (students, refusal) = OfflineBatch.Plan(entries!, Questions, Enrolled);
        Assert.That(refusal, Is.Null);
        Assert.That(students!.Single().Correct, Is.EquivalentTo(new List<long> { 10, 11 }));
    }
}
