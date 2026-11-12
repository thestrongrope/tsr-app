namespace Tsr.Assessment.Api.Domain;

/// <summary>PHP McqModel's constants (models/mcq.php:37): the source sheet and the languages and levels that can be updated. An id is the position in its list plus one.</summary>
internal static class StandardMcqCatalog
{
    public const string SheetId = "1bKkN_R55g1UEkb3n4rpI7poL8xyZ6EZAqSBkuI_6NYM";

    public static readonly IReadOnlyList<string> Languages = ["English", "Urdu", "Gujarati"];

    public static readonly IReadOnlyList<string> Levels = ["Abuzar", "Miqdad", "Ammar"];

    /// <summary>The name for an id (1-based); null when there is none.</summary>
    public static string? NameOf(IReadOnlyList<string> names, long id) => id >= 1 && id <= names.Count ? names[(int)id - 1] : null;
}
