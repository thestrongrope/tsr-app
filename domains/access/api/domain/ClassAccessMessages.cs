namespace Tsr.Access.Api.Domain;

/// <summary>The class access refusals that carry a code (and a class list) the app acts on, in PHP's words.</summary>
internal static class ClassAccessMessages
{
    private const string Changed = "This member was just changed by someone else. Open them again to see the current access.";

    /// <summary>409 member_changed: the version the client echoed is not the current one (another operator changed the member).</summary>
    public static Refusal MemberChanged() => Refusal.Coded(409, Changed, "member_changed");

    /// <summary>409 preview_changed: the classes the rule reaches now are not the ones the client was shown; they are listed (at most 200) with the count and the new hash.</summary>
    public static Refusal PreviewChanged(IReadOnlyList<ClassFacts> reached, string previewHash) =>
        new(
            409,
            "The classes changed since the preview",
            [
                new KeyValuePair<string, object?>("code", "preview_changed"),
                new KeyValuePair<string, object?>("classes", ClassAccessStore.Listed(reached)),
                new KeyValuePair<string, object?>("classCount", reached.Count),
                new KeyValuePair<string, object?>("previewHash", previewHash),
            ]);
}
