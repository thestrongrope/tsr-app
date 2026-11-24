using System.Globalization;
using Microsoft.AspNetCore.Http;
using Npgsql;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// PHP's <c>ClassesModel::searchTeachers</c>, shared by the two teacher searches: members whose name contains the text (or whose token it is) and who are an
/// enrolled student of any class (or PHP's hard-coded token 1001); a gents class takes gents only. At most 20, by name. Wire: <c>{teachers:[{token, name}]}</c>.
/// </summary>
internal static class TeacherSearch
{
    private const int Limit = 20;
    private const int AlwaysCandidate = 1001;

    internal sealed record Row(int Token, string? Name);

    /// <summary>PHP's <c>addcslashes($q, '%_\\')</c> into a contains pattern.</summary>
    private static string Pattern(string q) => "%" + q.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_") + "%";

    public static async Task<IResult> RunAsync(NpgsqlDataSource source, string? rawQuery, bool gentsClass, CancellationToken ct)
    {
        var q = PhpText.Trim(rawQuery ?? string.Empty);
        var matchesNobody = q.Length == 0 || q.Contains('\0');
        var teachers = matchesNobody ? [] : await FindAsync(source, q, gentsClass, ct);
        var wire = teachers.Select(t => new Dictionary<string, object?> { ["token"] = t.Token, ["name"] = PhpText.HtmlDecode(t.Name ?? string.Empty) }).ToList();
        return Results.Json(new Dictionary<string, object?> { ["teachers"] = wire }, ClassesJson.Answers.Answer);
    }

    public static Task<bool> IsCandidateAsync(NpgsqlDataSource source, int token, bool gentsClass, CancellationToken ct) =>
        source.AnyAsync(
            $"""
            select 1 as "Value" from membership.v_members m
            where m.token = {token}
              and (m.token = {AlwaysCandidate} or m.token in (select cs.token_no from classes.class_students cs where cs.removed_at is null and cs.status = 'A'))
              and (not {gentsClass} or m.token = {AlwaysCandidate} or lower(m.gender) in ('1', 'male'))
            limit 1
            """,
            ct);

    private static Task<List<Row>> FindAsync(NpgsqlDataSource source, string q, bool gentsClass, CancellationToken ct)
    {
        var pattern = Pattern(q);
        var digits = q.All(char.IsAsciiDigit) && long.TryParse(q, NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : 0;
        return source.ListAsync(
            $"""
            select m.token as "Token", m.name as "Name"
            from membership.v_members m
            where (m.name ilike {pattern} or m.token = {digits})
              and (m.token = {AlwaysCandidate}
                   or m.token in (select cs.token_no from classes.class_students cs where cs.removed_at is null and cs.status = 'A'))
              and (not {gentsClass} or m.token = {AlwaysCandidate} or lower(m.gender) in ('1', 'male'))
            order by m.name, m.token
            limit {Limit}
            """,
            row => new Row(row.Int("Token"), row.TextOrNull("Name")),
            ct);
    }
}
