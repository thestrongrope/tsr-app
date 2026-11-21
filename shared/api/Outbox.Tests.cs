using System.Text.Json;
using System.Text.Json.Serialization;
using NUnit.Framework;

namespace Tsr.Shared.Api.Tests;

public sealed record SamplePayload(string Name, int? Count, IReadOnlyList<string> Tags, [property: JsonPropertyName("member_token")] int MemberToken);

[JsonSourceGenerationOptions(JsonSerializerDefaults.Web)]
[JsonSerializable(typeof(SamplePayload))]
internal sealed partial class SampleJson : JsonSerializerContext;

public sealed class OutboxTests
{
    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    // Event payloads are a published contract: moving from reflection to source generation must not change one byte.
    [Test]
    public void A_source_generated_payload_matches_the_reflection_payload()
    {
        SamplePayload[] samples =
        [
            new("Salaam \"quoted\" é", null, ["a", "b"], 7),
            new("x", 3, [], 0),
        ];

        foreach (var sample in samples)
        {
            var reflection = JsonSerializer.SerializeToUtf8Bytes(sample, Web);
            var generated = JsonSerializer.SerializeToUtf8Bytes(sample, SampleJson.Default.SamplePayload);

            Assert.That(generated, Is.EqualTo(reflection));
        }
    }
}
