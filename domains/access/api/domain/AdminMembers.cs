using System.Globalization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

/// <summary>A member as the two admin screens see them: who, and the stored gender text ('1', '2', 'Male', 'Female' or empty).</summary>
internal sealed record MemberRow(int UserId, int Token, string Name, string? Gender);

/// <summary>
/// Finding a member for the grant and class access screens (PHP PermissionGrantsModel and ClassAccessModel member() and
/// searchMembers()). Reads identity's and membership's published views only. A token two members share finds the lower user id
/// (PHP's select takes whichever row the database returns first).
/// </summary>
internal static partial class AdminMembers
{
    public const int MaxResults = 20;
    public const int MaxQueryLength = 100;

    [GeneratedRegex("^[0-9]+$", RegexOptions.CultureInvariant, matchTimeoutMilliseconds: 200)]
    private static partial Regex Digits();

    /// <summary>PHP's <c>$_GET['q']</c>: the LAST q of the query string (ASP.NET would join two with a comma); empty when there is none.</summary>
    public static string LastQuery(IQueryCollection query) => query.TryGetValue("q", out var values) && values.Count > 0 ? values[^1] ?? string.Empty : string.Empty;

    /// <summary>True when q was sent as a list (<c>q[]=x</c> or <c>q[a]=x</c>), which PHP reads as an array, not text.</summary>
    public static bool QueryIsList(IQueryCollection query) => query.Keys.Any(key => key.StartsWith("q[", StringComparison.Ordinal));

    /// <summary>PHP's <c>(int)$token</c> of a path segment: 0 when it is not a number or does not fit a token, which is never found.</summary>
    public static int TokenOf(string raw)
    {
        var number = PhpValue.IntOfText(raw);
        return number is > 0 and <= int.MaxValue ? (int)number : 0;
    }

    /// <summary>PHP's <c>(int)$id</c> of a path segment: 0 when it is not a number or does not fit, which is never found.</summary>
    public static int IdOf(string raw) => TokenOf(raw);

    /// <summary>EntityAccessModel::genderOf: 1 for 1 or 'Male', 2 for 2 or 'Female', otherwise unknown.</summary>
    public static int? GenderOf(string? stored) => stored switch
    {
        "1" or "Male" => 1,
        "2" or "Female" => 2,
        _ => null,
    };

    /// <summary>The stored texts that mean this gender (users.gender holds both forms).</summary>
    public static string[] GenderTexts(IEnumerable<int> genders) =>
        genders.SelectMany(g => g == 1 ? GentsTexts : LadiesTexts).ToArray();

    private static readonly string[] GentsTexts = ["1", "Male"];
    private static readonly string[] LadiesTexts = ["2", "Female"];

    private static MemberRow ReadMember(DbRow row) => new(row.Int("UserId"), row.Int("Token"), row.Text("Name"), row.TextOrNull("Gender"));

    public static async Task<MemberRow?> FindAsync(DbTx tx, int token, CancellationToken ct)
    {
        if (token <= 0)
        {
            return null;
        }

        var rows = await tx.ListAsync(
            $"""
                select m.user_id as "UserId", m.token as "Token", coalesce(m.name, '') as "Name", m.gender::text as "Gender"
                from membership.v_members m
                where m.token = {token}
                order by m.user_id
                limit 1
                """,
            ReadMember,
            ct);
        return rows.Count == 0 ? null : rows[0];
    }

    /// <summary>LIKE pattern of a typed term: lower case, with ! as the escape so a typed % or _ matches itself.</summary>
    private static string LikePattern(string term) =>
        "%" + term.ToLowerInvariant().Replace("!", "!!", StringComparison.Ordinal).Replace("%", "!%", StringComparison.Ordinal).Replace("_", "!_", StringComparison.Ordinal) + "%";

    private static long TokenOfTerm(string term) =>
        Digits().IsMatch(term) && long.TryParse(term, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : -1;

    /// <summary>The grant screen's search: name, token, email or mobile; fewer than two characters finds nobody. Name and token only come back.</summary>
    public static async Task<IReadOnlyList<MemberRow>> SearchForGrantsAsync(NpgsqlDataSource source, string term, CancellationToken ct)
    {
        var q = PhpText.Trim(term);
        if (PhpText.CodePointCount(q) < 2)
        {
            return [];
        }

        var like = LikePattern(q);
        var token = TokenOfTerm(q);
        return await source.ListAsync(
            $"""
                select m.user_id as "UserId", m.token as "Token", coalesce(m.name, '') as "Name", m.gender::text as "Gender"
                from membership.v_members m
                join identity.v_users u on u.id = m.user_id
                where m.token > 0
                  and (lower(m.name) like {like} escape '!'
                       or lower(u.email) like {like} escape '!'
                       or m.mobile::text like {like} escape '!'
                       or m.token = {token})
                order by m.name, m.token
                limit {MaxResults}
                """,
            ReadMember,
            ct);
    }

    /// <summary>The class access screen's search: name or token, among members of the given genders (a member with no recorded gender is found by nobody).</summary>
    public static async Task<IReadOnlyList<MemberRow>> SearchOfGendersAsync(NpgsqlDataSource source, string term, IReadOnlyCollection<int> genders, CancellationToken ct)
    {
        var q = PhpText.Trim(term);
        if (PhpText.CodePointCount(q) < 2 || genders.Count == 0)
        {
            return [];
        }

        var like = LikePattern(q);
        var token = TokenOfTerm(q);
        var texts = GenderTexts(genders);
        return await source.ListAsync(
            $"""
                select m.user_id as "UserId", m.token as "Token", coalesce(m.name, '') as "Name", m.gender::text as "Gender"
                from membership.v_members m
                where m.token > 0 and m.gender::text = any({texts})
                  and (lower(m.name) like {like} escape '!' or m.token = {token})
                order by m.name, m.token
                limit {MaxResults}
                """,
            ReadMember,
            ct);
    }
}
