using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Tsr.Access.Api;
using Tsr.Classes.Api.Domain;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api.Features.AdminDeactivatedClasses;

// Slice: GET /admin/deactivated-classes -> {deactivated, log}: the closed classes (newest closing first) with how and when each was closed, and the deactivation log (every "deactivated" audit row, newest
// first, at most 500). deactivated-classes:manage (403 "You do not have permission to do that"), no audit row. Contract: spec/api.yaml.
// PHP: routes/deactivated_classes.php route_admin_deactivated_classes (:31), ClassesModel::deactivatedClasses / deactivationLog (the shaping is domain/DeactivationView.cs, unit tested). Quirks: the latest audit row per
// class (time, then id) supplies type, date and reason; a class closed before the audit log shows its own columns, comment and deleter; reason is "text?" (empty is null); performedAt is the stored UTC time with a Z.
// Order: COALESCE(audit time, deleted_at) newest first, none last (as MariaDB), then id. Bound: 5000 closed classes.

internal static class AdminDeactivatedClassesSlice
{
    private const int MaxClasses = 5000;
    private const int LogLimit = 500;

    internal sealed record Closed(int Id, string Code, string Level, int Gender, string Teacher, string Type, string EffectiveDate, string? Reason, string PerformedBy, string? PerformedAt);

    internal sealed record Logged(long Id, string Code, string Level, int Gender, string Type, string EffectiveDate, string? Reason, string PerformedBy, string? PerformedAt);

    internal sealed record Body(IReadOnlyList<Closed> Deactivated, IReadOnlyList<Logged> Log);

    public static IEndpointRouteBuilder MapAdminDeactivatedClasses(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/admin/deactivated-classes", HandleAsync).RequireMember(createsMember: true);
        return routes;
    }

    private static async Task<IResult> HandleAsync(HttpContext context, ClassesContext db, Permissions permissions, CancellationToken ct)
    {
        var caller = context.GetCaller();
        if (caller is null)
        {
            return Problem.Unauthenticated();
        }

        var refusal = await AdminGuards.DeactivatedClassesAsync(permissions, caller, ct);
        if (refusal is not null)
        {
            return refusal;
        }

        var closed = await db.Database
            .SqlQuery<DeactivationView.ClosedClass>($"""
                select c.id as "Id", c.code as "Code", cl.name as "Level", c.gender as "Gender", t.name as "Teacher", a.details::text as "Details",
                       c.completed_on as "CompletedOn", c.shutdown_on as "ShutdownOn", c.comments::text as "Comments", c.deleted_by as "DeletedBy",
                       c.deleted_at at time zone 'UTC' as "DeletedAt", pu.name as "PerformedByName", du.name as "DeletedByName", a.performed_at at time zone 'UTC' as "PerformedAt"
                from classes.classes c
                join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members t on t.token = c.teacher
                left join membership.v_members du on du.token = c.deleted_by
                left join lateral (
                    select al.details, al.performed_by, al.performed_at
                    from classes.class_audit_log al
                    where al.class_id = c.id and al.action = 'deactivated'
                    order by al.performed_at desc, al.id desc
                    limit 1) a on true
                left join membership.v_members pu on pu.token = a.performed_by
                where c.status = 'I'
                order by coalesce(a.performed_at, c.deleted_at) desc nulls last, c.id desc
                limit {MaxClasses}
                """)
            .ToListAsync(ct);
        var log = await db.Database
            .SqlQuery<DeactivationView.LogRow>($"""
                select a.id as "Id", a.class_id as "ClassId", c.code as "Code", c.gender as "Gender", cl.name as "Level", a.details::text as "Details",
                       a.performed_by as "PerformedBy", u.name as "PerformedByName", a.performed_at at time zone 'UTC' as "PerformedAt"
                from classes.class_audit_log a
                left join classes.classes c on c.id = a.class_id
                left join classes.class_levels cl on cl.id = c.class_level_id
                left join membership.v_members u on u.token = a.performed_by
                where a.action = 'deactivated'
                order by a.performed_at desc, a.id desc
                limit {LogLimit}
                """)
            .ToListAsync(ct);

        var summaries = closed.Select(DeactivationView.Summarise).Select(s => new Closed(
            s.Id, s.Code, s.Level, s.Gender, s.Teacher, s.Type, s.EffectiveDate, PhpCast.TextOrNull(s.Reason), s.PerformedBy, s.PerformedAt)).ToList();
        var entries = log.Select(DeactivationView.LogOf).Select(e => new Logged(
            e.Id, e.Code, e.Level, e.Gender, e.Type, e.EffectiveDate, PhpCast.TextOrNull(e.Reason), e.PerformedBy, e.PerformedAt)).ToList();
        return Results.Json(new Body(summaries, entries));
    }
}
