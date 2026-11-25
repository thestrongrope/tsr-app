using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>The one select of a member's profile row and the reader of it, for every slice that shows or changes a profile. The query runs on a data source or on a <see cref="DbTx"/>.</summary>
internal static class ProfileRows
{
    public static Sql ByUserId(int userId) =>
        $"""
        select user_id, name, first_name, last_name, picture, gender, age_range, mobile, country, state, city, zip, language, sendupdates, unsubscribe
        from membership.member_profiles where user_id = {userId}
        """;

    public static MemberProfile Read(DbRow row) => new()
    {
        UserId = row.Int("user_id"),
        Name = row.TextOrNull("name"),
        FirstName = row.TextOrNull("first_name"),
        LastName = row.TextOrNull("last_name"),
        Picture = row.TextOrNull("picture"),
        Gender = row.TextOrNull("gender"),
        AgeRange = row.TextOrNull("age_range"),
        Mobile = row.Text("mobile"),
        Country = row.TextOrNull("country"),
        State = row.TextOrNull("state"),
        City = row.TextOrNull("city"),
        Zip = row.TextOrNull("zip"),
        Language = row.IntOrNull("language"),
        SendUpdates = row.Text("sendupdates"),
        Unsubscribe = row.Text("unsubscribe"),
    };
}
