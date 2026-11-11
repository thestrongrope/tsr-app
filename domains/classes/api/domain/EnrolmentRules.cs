using System.Globalization;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>The enrolment rules that branch, as PHP states them (models/entityaccess.php genderOf, classstudents.php addStudent and transferStudent), apart from any database.</summary>
internal static class EnrolmentRules
{
    /// <summary>PHP genderOf: <c>'1'</c> or <c>'Male'</c> is 1, <c>'2'</c> or <c>'Female'</c> is 2, anything else (empty, other text, NULL) is unknown.</summary>
    public static int? GenderOf(string? stored) => stored switch
    {
        "1" or "Male" => 1,
        "2" or "Female" => 2,
        _ => null,
    };

    /// <summary>PHP addStudent: a member of unknown gender may join any class; a known gender must equal the class's, and a class without a gender compares as 0.</summary>
    public static bool GenderAllows(string? memberGender, int? classGender)
    {
        var member = GenderOf(memberGender);
        return member is null || member == (classGender ?? 0);
    }

    /// <summary>PHP: <c>ucfirst($type) . ' to class #' . $to . ($reason ? ': ' . $reason : '')</c>; PHP treats "" and "0" as false.</summary>
    public static string TransferReason(string type, string reason, int toClassId)
    {
        var head = PhpText.UcFirst(type) + " to class #" + toClassId.ToString(CultureInfo.InvariantCulture);
        return reason is "" or "0" ? head : head + ": " + reason;
    }
}
