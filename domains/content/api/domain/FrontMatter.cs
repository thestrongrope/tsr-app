using Tsr.Shared.Api;
using YamlDotNet.Core;
using YamlDotNet.Core.Events;

namespace Tsr.Content.Api.Domain;

/// <summary>
/// One file's front matter, read from YamlDotNet's EVENT stream (<see cref="Parser"/>) into the three kinds below. The library's document tree (<c>YamlStream</c>) is never built:
/// on an alias it overflows the stack (a key that contains itself) or never ends (aliases multiplied into a key), and neither can be caught or cancelled.
/// The content uses texts, lists and maps with text keys only, so everything else is refused at the first event that shows it: an alias, an anchor, a tag,
/// a key that is a list or a map, a second document, and nesting past <see cref="MaxDepth"/>. With no alias, the structure is never larger than the text it was read from.
/// A failure is a fixed phrase, never the file's text.
/// </summary>
internal static class FrontMatter
{
    public const int MaxDepth = 16;

    public const string Unparsable = "cannot parse file";

    public const string TooDeep = "front matter too deep";

    public const string AliasRefused = "alias in front matter";

    public const string AnchorRefused = "anchor in front matter";

    public const string TagRefused = "tag in front matter";

    public const string KeyRefused = "key is not a text in front matter";

    public const string SecondDocument = "second document in front matter";

    /// <summary>The fields by name; empty for empty front matter; a failure phrase when it is refused or is not a map.</summary>
    public static Result<Dictionary<string, Value>> Read(string yaml)
    {
        try
        {
            return ReadEvents(yaml);
        }
        catch (Exception e) when (e is not OutOfMemoryException)
        {
            // Whatever the parser throws on untrusted text is a file that cannot be parsed. YamlDotNet 18.1.0 does not keep to YamlException:
            // a flow sequence never closed is InvalidOperationException from its scanner, an escape past the last code point ("\UFFFFFFFF") ArgumentOutOfRangeException.
            return Result.Fail<Dictionary<string, Value>>(Unparsable);
        }
    }

    /// <summary>One pass over the events. The parser yields at most a few events a character, so the caller's bound on the text's size bounds this loop.</summary>
    private static Result<Dictionary<string, Value>> ReadEvents(string yaml)
    {
        using var reader = new StringReader(yaml);
        var parser = new Parser(reader);
        var builder = new Builder();
        while (parser.MoveNext())
        {
            var refused = builder.Take(parser.Current!);
            if (refused is not null)
            {
                return Result.Fail<Dictionary<string, Value>>(refused);
            }
        }

        return builder.Root switch
        {
            null or Text { IsNull: true } => Result.Ok(new Dictionary<string, Value>(StringComparer.Ordinal)),
            Mapping mapping => Result.Ok(mapping.Fields),
            _ => Result.Fail<Dictionary<string, Value>>(Unparsable),
        };
    }

    internal abstract record Value;

    /// <summary>A scalar. <paramref name="Plain"/>: written without quotes and not as a block, which is what tells YAML's null and true from the same words as text.</summary>
    internal sealed record Text(string Content, bool Plain) : Value
    {
        /// <summary>YAML's null: an unquoted empty value, <c>~</c> or <c>null</c>.</summary>
        public bool IsNull => Plain && Content is "" or "~" or "null" or "Null" or "NULL";

        /// <summary>YAML's true, unquoted.</summary>
        public bool IsTrue => Plain && Content is "true" or "True" or "TRUE";
    }

    internal sealed record Sequence(List<Value> Items) : Value;

    internal sealed record Mapping(Dictionary<string, Value> Fields) : Value;

    /// <summary>The structure so far: the containers still open, innermost on top. No recursion, so the depth of the text costs no stack.</summary>
    private sealed class Builder
    {
        private readonly Stack<Open> open = new();

        private int documents;

        public Value? Root { get; private set; }

        /// <summary>Takes the next event; the failure phrase when it is one the content never uses.</summary>
        public string? Take(ParsingEvent parsed) => parsed switch
        {
            DocumentStart => ++documents > 1 ? SecondDocument : null,
            AnchorAlias => AliasRefused,
            NodeEvent { Anchor.IsEmpty: false } => AnchorRefused,
            NodeEvent { Tag.IsEmpty: false } => TagRefused,
            Scalar scalar => Add(new Text(scalar.Value, scalar.Style == ScalarStyle.Plain)),
            MappingStart => Start(new Mapping(new Dictionary<string, Value>(StringComparer.Ordinal))),
            SequenceStart => Start(new Sequence([])),
            MappingEnd or SequenceEnd => End(),
            _ => null,
        };

        private string? Start(Value container)
        {
            if (open.Count >= MaxDepth)
            {
                return TooDeep;
            }

            var refused = Add(container);
            if (refused is null)
            {
                open.Push(new Open(container));
            }

            return refused;
        }

        private string? End()
        {
            open.Pop();
            return null;
        }

        private string? Add(Value value)
        {
            if (!open.TryPeek(out var parent))
            {
                Root = value;
                return null;
            }

            if (parent.Container is Sequence sequence)
            {
                sequence.Items.Add(value);
                return null;
            }

            return parent.Key is null ? TakeKey(parent, value) : TakeField(parent, value);
        }

        private static string? TakeKey(Open parent, Value value)
        {
            if (value is not Text key)
            {
                return KeyRefused;
            }

            parent.Key = key.Content;
            return null;
        }

        /// <summary>A name written twice in one map is unparsable, as it was to the tree loader.</summary>
        private static string? TakeField(Open parent, Value value)
        {
            var added = ((Mapping)parent.Container).Fields.TryAdd(parent.Key!, value);
            parent.Key = null;
            return added ? null : Unparsable;
        }
    }

    /// <summary>A container still open; in a map, the key read whose value comes next.</summary>
    private sealed class Open(Value container)
    {
        public Value Container { get; } = container;

        public string? Key { get; set; }
    }
}
