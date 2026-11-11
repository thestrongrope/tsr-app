namespace Tsr.Classes.Api.Domain;

/// <summary>PHP's <c>GuidesModel::SLUGS</c>: the class levels that have a public guide page, by level id. Level 1 (Salman) has none.</summary>
internal static class GuideSlugs
{
    public static string? ForLevel(long? levelId) => levelId switch
    {
        2 => "abuzar",
        3 => "miqdad",
        4 => "ammar",
        5 => "bilal",
        _ => null,
    };
}
