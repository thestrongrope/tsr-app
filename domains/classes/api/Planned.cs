using Microsoft.AspNetCore.Routing;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api;

/// <summary>
/// classes's operations whose slice is not built yet: placeholders that sign the caller in and answer 501 (shared/api/PlannedRoutes.cs).
/// Building a slice: delete its line here, set its state to built in docs/specs/initial-build/operations.csv.
/// </summary>
internal static class Planned
{
    public static IEndpointRouteBuilder MapPlannedRoutes(this IEndpointRouteBuilder routes)
    {
        routes.MapPlanned(
            ("GET", "/me/guides"),
            ("GET", "/me/guides/{slug}"),
            ("GET", "/classes/{class_id}/conduction"),
            ("GET", "/classes/{class_id}/conduction/new"),
            ("GET", "/classes/{class_id}/conduction/check"),
            ("POST", "/classes/{class_id}/conduction"),
            ("GET", "/classes/{class_id}/conduction/{session_id}"),
            ("PUT", "/classes/{class_id}/conduction/{session_id}"),
            ("POST", "/classes/{class_id}/students/bulk"),
            ("PUT", "/classes/{class_id}/students/{token}"),
            ("GET", "/reports/conduction"),
            ("GET", "/reports/conduction/download"),
            ("GET", "/reports/conduction/download-all"),
            ("GET", "/reports/weekly"),
            ("GET", "/reports/weekly/download"),
            ("GET", "/reports/summary"),
            ("GET", "/reports/summary/download"),
            ("GET", "/reports/students"),
            ("GET", "/reports/students/download"),
            ("GET", "/reports/tsr"),
            ("GET", "/reports/tsr/download"),
            ("GET", "/reports/pending"),
            ("GET", "/reports/pending/download"),
            ("GET", "/reports/subject-conduction"),
            ("GET", "/reports/subject-conduction/download"),
            ("GET", "/reports/class-sessions"),
            ("GET", "/reports/class-sessions/download-all"),
            ("GET", "/reports/class-sessions/{class_id}"),
            ("GET", "/reports/class-sessions/{class_id}/download"),
            ("GET", "/reports/active-teachers"),
            ("GET", "/reports/active-teachers/download"),
            ("GET", "/reports/this-week"),
            ("GET", "/reports/this-week/class/{class_id}"),
            ("GET", "/admin/syllabus"),
            ("POST", "/admin/syllabus"),
            ("GET", "/admin/transfers/classes"),
            ("GET", "/admin/transfers/classes/{class_id}/students"),
            ("GET", "/admin/transfers/history"),
            ("POST", "/admin/transfers"),
            ("GET", "/admin/members/{token}"),
            ("POST", "/admin/members/{token}/enrolments"),
            ("GET", "/admin/deactivated-classes"),
            ("GET", "/admin/deactivated-classes/candidates"),
            ("POST", "/classes/{class_id}/deactivate"),
            ("GET", "/admin/teachers"),
            ("POST", "/admin/teachers/training"),
            ("POST", "/admin/teachers/import"),
            ("PUT", "/admin/syllabus/{syllabus_id}"),
            ("DELETE", "/admin/syllabus/{syllabus_id}"));
        return routes;
    }
}
