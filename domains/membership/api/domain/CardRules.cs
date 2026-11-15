namespace Tsr.Membership.Api.Domain;

/// <summary>PHP EntityAccessModel rules the student card and the subscriber card share.</summary>
internal static class CardRules
{
    /// <summary>PHP EntityAccessModel::genderOf: "1" or "Male" is 1, "2" or "Female" is 2, anything else is not recorded.</summary>
    public static int? GenderOf(string? stored) =>
        stored switch
        {
            "1" or "Male" => 1,
            "2" or "Female" => 2,
            _ => null,
        };

    /// <summary>PHP Permissions::reaches: does a classes:read reach cover this class (every class, the class's gender, or an assigned class id)?</summary>
    public static bool Reaches(bool all, int? genderLimit, IReadOnlyCollection<int> assignedIds, int classId, int? classGender) =>
        all || (genderLimit is not null && classGender == genderLimit) || assignedIds.Contains(classId);
}
