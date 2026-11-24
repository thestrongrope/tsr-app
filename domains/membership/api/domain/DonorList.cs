using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Membership.Api.Domain;

/// <summary>
/// The donors list as data, for the screen (GET /admin/donors) and the download (its /download): every member in an active class, ordered by name. PHP: SubscribersModel::getDonorList, api_require_donors (routes/donors.php), each column api_cast "text?"
/// (entities decoded, empty is null). Quirks copied: one row per (enrolment row, holder of the token): NO distinct, so a member in two classes appears twice; no reach limit (PHP applies none: every donors:read holder sees every member's contact details,
/// flagged). Deviation: at most 50000 rows (PHP returns all). The permission (donors:read, 403) is checked by the caller.
/// </summary>
internal static class DonorList
{
    public const int MaxRows = 50_000;

    internal sealed record Donor(string? Name, string? Email, string? Mobile, string? City, string? State, string? Country, string? Zip);

    public static async Task<List<Donor>> LoadAsync(NpgsqlDataSource source, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(source);
        var rows = await source.ListAsync(
            $"""
                select m.name as "Name", u.email as "Email", m.mobile as "Mobile", m.city as "City", m.state as "State", m.country as "Country", m.zip as "Zip"
                from membership.v_members m
                join identity.v_users u on u.id = m.user_id
                join classes.v_enrolments cs on cs.token_no = m.token
                join classes.v_classes c on c.id = cs.class_id
                where cs.removed_at is null and c.status = 'A'
                order by m.name
                limit {MaxRows}
                """,
            row => new Donor(row.TextOrNull("Name"), row.TextOrNull("Email"), row.TextOrNull("Mobile"), row.TextOrNull("City"), row.TextOrNull("State"), row.TextOrNull("Country"), row.TextOrNull("Zip")),
            ct);
        return [.. rows.Select(d => new Donor(Text(d.Name), Text(d.Email), Text(d.Mobile), Text(d.City), Text(d.State), Text(d.Country), Text(d.Zip)))];
    }

    // api_cast "text?": null or empty is null, else the HTML entities decoded.
    private static string? Text(string? value) => string.IsNullOrEmpty(value) ? null : PhpText.HtmlDecode(value);
}
