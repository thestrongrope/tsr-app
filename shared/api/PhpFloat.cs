using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Tsr.Shared.Api;

/// <summary>
/// A number PHP sends as a float: <c>json_encode(100.0)</c> is <c>100.0</c>, where System.Text.Json writes <c>100</c>. The app's float fields read it as a
/// double, so the ".0" is kept. <see cref="Round"/> is PHP's round(): half away from zero.
/// </summary>
[JsonConverter(typeof(PhpFloatConverter))]
public readonly record struct PhpFloat(double Value)
{
    public static PhpFloat Round(decimal value, int places) => new((double)Math.Round(value, places, MidpointRounding.AwayFromZero));
}

public sealed class PhpFloatConverter : JsonConverter<PhpFloat>
{
    public override PhpFloat Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) => new(reader.GetDouble());

    public override void Write(Utf8JsonWriter writer, PhpFloat value, JsonSerializerOptions options)
    {
        var text = value.Value.ToString("R", CultureInfo.InvariantCulture);
        writer.WriteRawValue(text.AsSpan().IndexOfAny('.', 'E') < 0 ? text + ".0" : text);
    }
}
