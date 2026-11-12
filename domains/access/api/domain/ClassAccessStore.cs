using System.Data.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Tsr.Shared.Api;

namespace Tsr.Access.Api.Domain;

internal sealed record ClassAccessMemberBody(int Token, object Name, int Gender);

internal sealed record ConditionBody(string Field, bool Negate, object? Value);

internal sealed record ClassBody(int Id, string Code, object Name, int RuleId, object Rule);

internal sealed record RuleBody(int Id, int? Gender, object Note, string CreatedAt, IReadOnlyList<ConditionBody> Conditions, int ClassCount, IReadOnlyList<ClassBody> Classes);

internal sealed record ClassAccessView(ClassAccessMemberBody Member, string Version, string? FromRole, IReadOnlyList<RuleBody> Rules);

/// <summary>The answer of a write: saved, and the refreshed view (null parts when it could not be read).</summary>
internal sealed record SavedBody(bool Saved, ClassAccessMemberBody? Member, string? Version, string? FromRole, IReadOnlyList<RuleBody> Rules);

/// <summary>A class as a preview or a refusal lists it.</summary>
internal sealed record PreviewClass(int Id, string Code, object Name);

internal sealed record LevelBody(int Id, string Code, object Name);

/// <summary>A live rule as stored: its conditions as the matcher reads them.</summary>
internal sealed record StoredRule(int Id, int? Gender, string Note, DateTimeOffset CreatedAt, IReadOnlyList<RuleCondition> Conditions);

/// <summary>
/// The reads the class access routes share (PHP ClassAccessModel): the member and their role, the live rules, the levels, and the member view that the
/// read and both writes answer with. Classes come through the port <see cref="IClassScopes"/>; levels through classes' view.
/// </summary>
internal static partial class ClassAccessStore
{
    public static async Task<int> RoleOfAsync(AccessContext db, int userId, CancellationToken ct) =>
        await db.UserRoles.AsNoTracking().Where(u => u.UserId == userId).Select(u => (int?)u.RoleId).FirstOrDefaultAsync(ct) ?? ClassAccessRules.RoleMember;

    public static async Task<IReadOnlyList<StoredRule>> LiveRulesAsync(AccessContext db, int token, CancellationToken ct)
    {
        var rules = await db.ClassAccessRules.AsNoTracking()
            .Where(r => r.Token == token && r.RevokedAt == null)
            .OrderBy(r => r.Id)
            .ToListAsync(ct);
        if (rules.Count == 0)
        {
            return [];
        }

        var ids = rules.Select(r => r.Id).ToList();
        var conditions = await db.ClassAccessRuleConditions.AsNoTracking().Where(c => ids.Contains(c.RuleId)).OrderBy(c => c.Id).ToListAsync(ct);
        return rules
            .Select(r => new StoredRule(
                r.Id,
                r.Gender,
                r.Note,
                r.CreatedAt,
                conditions.Where(c => c.RuleId == r.Id).Select(c => new RuleCondition(c.Field.ToLowerInvariant(), c.Negate, c.Value, c.LevelId)).ToList()))
            .ToList();
    }

    public static async Task<IReadOnlyList<LevelBody>> LevelsAsync(AccessContext db, CancellationToken ct)
    {
        var rows = await db.Database
            .SqlQuery<LevelRow>($"""select id as "Id", code as "Code", name as "Name" from classes.v_class_levels order by sort_order, id""")
            .ToListAsync(ct);
        return rows.Select(r => new LevelBody(r.Id, r.Code, Cast.Text(r.Name))).ToList();
    }

    /// <summary>The conditions of a new grant checked (<see cref="ClassAccessRules.CheckedConditions"/>), and every level among them an existing one (422 "Unknown level").</summary>
    public static async Task<Outcome<IReadOnlyList<RuleCondition>>> CheckedConditionsAsync(AccessContext db, IReadOnlyList<RawCondition> raw, CancellationToken ct)
    {
        var conditions = ClassAccessRules.CheckedConditions(raw);
        if (conditions.Failed)
        {
            return conditions;
        }

        var levelIds = conditions.Value!.Where(c => c.Field == "level").Select(c => c.LevelId!.Value).ToList();
        return await LevelsExistAsync(db, levelIds, ct) ? conditions : Outcome<IReadOnlyList<RuleCondition>>.Fail(422, "Unknown level");
    }

    /// <summary>The conditions with each city, country and tag given the spelling this operator is offered (422 when it is not offered).</summary>
    public static async Task<Outcome<IReadOnlyList<RuleCondition>>> OfferedConditionsAsync(
        IClassScopes classes, ClassAccessOperator op, IReadOnlyList<RuleCondition> conditions, CancellationToken ct)
    {
        var genders = await op.GendersAsync(ct);
        var active = await classes.ActiveClassesAsync(ct);
        return ClassAccessRules.OfferedValues(conditions, ClassAccessRules.Cities(active, genders), ClassAccessRules.Countries(active, genders), ClassAccessRules.Tags(active, genders));
    }

    /// <summary>True when every level id is a level.</summary>
    public static async Task<bool> LevelsExistAsync(AccessContext db, IReadOnlyList<int> levelIds, CancellationToken ct)
    {
        var wanted = levelIds.Distinct().ToArray();
        if (wanted.Length == 0)
        {
            return true;
        }

        var found = await db.Database
            .SqlQuery<int>($"""select count(*)::int as "Value" from classes.v_class_levels where id = any({wanted})""")
            .ToListAsync(ct);
        return found[0] == wanted.Length;
    }

    /// <summary>The member of a token with the stored role; null for an unknown member or a guest.</summary>
    public static async Task<(MemberRow Member, int RoleId)?> MemberAsync(AccessContext db, int token, CancellationToken ct)
    {
        var member = await AdminMembers.FindAsync(db, token, ct);
        return member is null ? null : (member, await RoleOfAsync(db, member.UserId, ct));
    }

    /// <summary>ForMember: the member's view for an operator who may manage their gender; 404 unknown member, 403 another or no recorded gender.</summary>
    public static async Task<Outcome<ClassAccessView>> MemberViewAsync(
        AccessContext db, Permissions permissions, IClassScopes classes, ClassAccessOperator op, int token, CancellationToken ct)
    {
        var found = await MemberAsync(db, token, ct);
        if (found is null)
        {
            return Outcome<ClassAccessView>.Fail(StatusCodes.Status404NotFound, "Member not found");
        }

        var gender = AdminMembers.GenderOf(found.Value.Member.Gender);
        if (gender is not int g || !await op.MayManageAsync(g, ct))
        {
            return Outcome<ClassAccessView>.Fail(StatusCodes.Status403Forbidden, ClassAccessOperator.OtherGender);
        }

        return Outcome<ClassAccessView>.Ok(await ViewAsync(db, permissions, classes, op, found.Value.Member, found.Value.RoleId, g, ct));
    }

    private static async Task<ClassAccessView> ViewAsync(
        AccessContext db, Permissions permissions, IClassScopes classes, ClassAccessOperator op, MemberRow member, int roleId, int gender, CancellationToken ct)
    {
        var rules = await LiveRulesAsync(db, member.Token, ct);
        var active = await classes.ActiveClassesAsync(ct);
        var shown = new List<RuleBody>();
        foreach (var rule in rules)
        {
            if (await op.MayManageRuleAsync(rule.Gender, ct))
            {
                shown.Add(RuleView(rule, active));
            }
        }

        return new ClassAccessView(
            new ClassAccessMemberBody(member.Token, Cast.Text(member.Name), gender),
            ClassAccessRules.VersionOf(roleId, rules.Select(r => r.Id)),
            await FromRoleAsync(permissions, member, ct),
            shown);
    }

    // A line when the member's role already reaches classes (PHP managedReach on classes:read), read live.
    private static async Task<string?> FromRoleAsync(Permissions permissions, MemberRow member, CancellationToken ct)
    {
        permissions.Forget(member.UserId);
        var reach = await permissions.ReachAsync(new Caller(member.UserId, member.Token), "classes:read", ct);
        if (reach.All)
        {
            return "Every class";
        }

        return reach.Gender is not null ? "Classes of their own gender" : null;
    }

    /// <summary>The rule with the classes it reaches (the same matcher as the engine): at most 200 listed, each naming the rule, and the total.</summary>
    private static RuleBody RuleView(StoredRule rule, IReadOnlyList<ClassFacts> active)
    {
        var reached = ClassAccessRules.Reach(rule.Gender, rule.Conditions, active);
        return new RuleBody(
            rule.Id,
            rule.Gender,
            Cast.Text(rule.Note),
            Cast.DateTime(rule.CreatedAt),
            rule.Conditions.Select(c => new ConditionBody(c.Field, c.Negate, c.Field == "level" ? c.LevelId ?? 0 : c.Value)).ToList(),
            reached.Count,
            reached.Take(ClassAccessRules.MaxClasses).Select(c => new ClassBody(c.Id, c.Code, Cast.Text(c.Name), rule.Id, Cast.Text(rule.Note))).ToList());
    }

    /// <summary>
    /// The answer of a committed write: <c>{saved: true}</c> and the refreshed member view. When the view cannot be read (a refusal now, or a failure, logged by type only) the write is still saved:
    /// the member and version are null and the app reloads (PHP api_class_access_write).
    /// </summary>
    public static async Task<IResult> SavedAsync(
        AccessContext db, Permissions permissions, IClassScopes classes, ClassAccessOperator op, int token, ILogger logger, CancellationToken ct)
    {
        try
        {
            var view = await MemberViewAsync(db, permissions, classes, op, token, ct);
            if (!view.Failed)
            {
                var v = view.Value!;
                return Results.Json(new SavedBody(true, v.Member, v.Version, v.FromRole, v.Rules));
            }
        }
        catch (Exception e) when (e is DbException or InvalidOperationException)
        {
            LogViewUnreadable(logger, e.GetType().Name);
        }

        return Results.Json(new SavedBody(true, null, null, null, []));
    }

    /// <summary>The answer when a write failed before it committed (PHP: "Nothing was changed"; the transaction rolled back).</summary>
    public static IResult NothingChanged(ILogger logger, Exception error)
    {
        LogWriteFailed(logger, error.GetType().Name);
        return Problem.Detail(StatusCodes.Status500InternalServerError, "Nothing was changed");
    }

    [LoggerMessage(Level = LogLevel.Error, Message = "class_access.saved_view_unreadable error={Type}")]
    private static partial void LogViewUnreadable(ILogger logger, string type);

    [LoggerMessage(Level = LogLevel.Error, Message = "class_access.failed error={Type}")]
    private static partial void LogWriteFailed(ILogger logger, string type);

    public static IReadOnlyList<PreviewClass> Listed(IReadOnlyList<ClassFacts> classes) =>
        classes.Take(ClassAccessRules.MaxClasses).Select(c => new PreviewClass(c.Id, c.Code, Cast.Text(c.Name))).ToList();

    private sealed record LevelRow(int Id, string Code, string? Name);
}
