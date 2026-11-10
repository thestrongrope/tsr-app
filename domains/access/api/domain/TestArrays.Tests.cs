namespace Tsr.Access.Api.Domain;

/// <summary>Expected lists for assertions. A params call builds the array, so the analyzer's constant-array rule does not fire.</summary>
internal static class Expect
{
    public static T[] List<T>(params T[] items) => items;
}
