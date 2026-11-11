using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Domain;

/// <summary>
/// What one report may show (PHP <c>api_reports_gender</c> and <c>MisModel::reachFilter</c>): the gender asked for, and the caller's <c>reports:read</c> reach (every class, a gender's classes, the assigned
/// classes, or nothing). Every report reads the same list of class ids (<see cref="ClassIdsAsync"/>), so the rule lives once; the report's own query then says <c>c.id = any(ids)</c>.
/// </summary>
internal sealed record ReportScope(int Gender, bool All, bool HasGenderLimit, int GenderLimit, int[] ClassIds)
{
    /// <summary>PHP <c>api_reports_gender</c>: the locked gender wins, else ladies only for the exact text "2", else gents.</summary>
    public static int GenderOf(int? locked, string? asked) => locked ?? (asked == "2" ? 2 : 1);

    public static ReportScope Of(Reach reach, int gender)
    {
        ArgumentNullException.ThrowIfNull(reach);
        return new ReportScope(gender, reach.All, reach.Gender is not null, reach.Gender ?? 0, [.. reach.ClassIds]);
    }

    /// <summary>
    /// PHP's first two steps of every report: the gender (locked or asked for), then <c>api_require('reports:read', gender)</c>, 403 "You do not have permission to do that" without it.
    /// </summary>
    public static async Task<(ReportScope? Scope, IResult? Refusal)> OpenAsync(HttpContext context, Permissions permissions, Caller caller, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(permissions);
        ArgumentNullException.ThrowIfNull(caller);
        var reach = await permissions.ReachAsync(caller, "reports:read", ct);
        var asked = context.Request.Query["gender"];
        var gender = GenderOf(reach.GenderLock, asked.Count == 0 ? null : asked[^1]);
        if (!await permissions.CanAsync(caller, "reports:read", AccessTarget.ForGender(gender), ct))
        {
            return (null, Refusals.NotPermitted());
        }

        return (Of(reach, gender), null);
    }

    /// <summary>PHP <c>trim((string) ($_GET['level'] ?? ''))</c>: the level a report is narrowed to, "" for none.</summary>
    public static string LevelOf(HttpContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var level = context.Request.Query["level"];
        return level.Count == 0 ? string.Empty : PhpText.Trim(level[^1] ?? string.Empty);
    }

    /// <summary>
    /// PHP <c>MisModel::reportClasses</c> (via <c>ClassesModel::getAll</c>): the class ids of <see cref="ClassIdsAsync"/>, and for a caller whose classes:read is assigned-only, only the assigned classes.
    /// </summary>
    public static async Task<int[]> KeepAssignedAsync(int[] ids, Permissions permissions, Caller caller, CancellationToken ct)
    {
        ArgumentNullException.ThrowIfNull(ids);
        ArgumentNullException.ThrowIfNull(permissions);
        ArgumentNullException.ThrowIfNull(caller);
        var assigned = (await permissions.ReachAsync(caller, "classes:read", ct)).AssignedOnlyIds;
        return assigned is null ? ids : [.. ids.Intersect(assigned)];
    }

    /// <summary>
    /// The active classes of <see cref="Gender"/> the scope reaches, the demo class (code AYD1, PHP <c>DEMO_CLASS_CODE</c>) never among them; with <paramref name="onlyClass"/> above 0, that class or none. A gender of 0 (a class with no gender, PHP's <c>(int) null</c>) narrows by no gender.
    /// PHP: reachFilter, status 'A' and <c>demo_class_exclusion_sql</c>. Bound: the classes of one gender. <paramref name="anyStatus"/> lifts the status (the few PHP queries that never ask for it, e.g. the recitation list of TSR at a glance).
    /// </summary>
    public async Task<int[]> ClassIdsAsync(ClassesContext db, long onlyClass, CancellationToken ct, bool anyStatus = false)
    {
        ArgumentNullException.ThrowIfNull(db);
        var all = All;
        var hasGender = HasGenderLimit;
        var genderLimit = GenderLimit;
        var assigned = ClassIds;
        var gender = Gender;
        var rows = await db.Database
            .SqlQuery<int>($"""
                select c.id as "Value" from classes.classes c
                where (c.status = 'A' or {anyStatus}) and c.code <> 'AYD1'
                  and ({all} or ({hasGender} and c.gender = {genderLimit}) or c.id = any({assigned}))
                  and ({gender} = 0 or c.gender = {gender})
                  and ({onlyClass} = 0 or c.id = {onlyClass})
                order by c.id
                limit 20000
                """)
            .ToListAsync(ct);
        return [.. rows];
    }
}
