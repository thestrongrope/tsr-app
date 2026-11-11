using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Tsr.Access.Api;
using Tsr.Classes.Api.Features.ChildAttendance;
using Tsr.Classes.Api.Features.ChildClasses;
using Tsr.Classes.Api.Features.ChildPerformance;
using Tsr.Classes.Api.Features.ClassDeactivate;
using Tsr.Classes.Api.Features.ClassDetail;
using Tsr.Classes.Api.Features.ClassGuide;
using Tsr.Classes.Api.Features.ClassLevels;
using Tsr.Classes.Api.Features.ClassesList;
using Tsr.Classes.Api.Features.ClassSessions;
using Tsr.Classes.Api.Features.ClassStudentEdit;
using Tsr.Classes.Api.Features.ClassSyllabusTopics;
using Tsr.Classes.Api.Features.GuideGet;
using Tsr.Classes.Api.Features.GuideUpdate;
using Tsr.Classes.Api.Features.GuidesList;
using Tsr.Classes.Api.Features.MyAttendance;
using Tsr.Classes.Api.Features.MyPerformance;
using Tsr.Classes.Api.Features.SyllabusLevel;
using Tsr.Classes.Api.Features.SyllabusLevels;
using Tsr.Classes.Api.Features.ClassStudents;
using Tsr.Classes.Api.Features.ClassTeachers;
using Tsr.Classes.Api.Features.ClassSchedule;
using Tsr.Classes.Api.Features.ClassCreateOptions;
using Tsr.Classes.Api.Features.ClassCreateTeachers;
using Tsr.Classes.Api.Features.ClassManage;
using Tsr.Classes.Api.Features.ClassCreate;
using Tsr.Classes.Api.Features.ClassUpdate;
using Tsr.Classes.Api.Features.ClassScheduleUpdate;
using Tsr.Classes.Api.Features.ClassStudentAdmin;
using Tsr.Classes.Api.Features.ClassStudentAdd;
using Tsr.Classes.Api.Features.ClassJoin;
using Tsr.Classes.Api.Features.RegistrationClasses;
using Tsr.Classes.Api.Features.RegistrationPlace;
using Tsr.Classes.Api.Features.JoinPreview;
using Tsr.Classes.Api.Features.ClassStudentTransfer;
using Tsr.Classes.Api.Features.ClassStudentRemove;
using Tsr.Classes.Api.Features.ClassStudentRestore;
using Tsr.Classes.Api.Features.ClassStudentsPerformance;
using Tsr.Classes.Api.Features.TeacherDetail;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api;

/// <summary>
/// classes: classes, levels, enrolment, sessions, attendance, teachers, syllabus and guides. Tables, the read slices, and placeholder routes (Planned.cs) so far. It supplies access's <c>IClassScopes</c> (ClassScopes.cs) and will supply membership's <c>IClassEnrolments</c>.
/// </summary>
public static class ClassesModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). access (permissions, and the port it supplies), platform (the admin audit command), membership (the accepted-registration command), identity (membership starts only with it registered; the email command); other domains are read through their v_* views.</summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access", "platform", "membership", "identity"];

    public static IServiceCollection AddClasses(this IServiceCollection services)
    {
        services.AddDomainContext<ClassesContext>(ClassesContext.SchemaName);
        services.Replace(ServiceDescriptor.Scoped<IClassScopes, ClassScopes>());
        services.TryAddSingleton<MemberRateLimit>();
        return services;
    }

    public static IEndpointRouteBuilder MapClasses(this IEndpointRouteBuilder routes)
    {
        routes.MapClassLevels();
        routes.MapGuidesList();
        routes.MapGuideGet();
        routes.MapGuideUpdate();
        routes.MapClassGuide();
        routes.MapSyllabusLevels();
        routes.MapSyllabusLevel();
        routes.MapClassSyllabusTopics();
        routes.MapClassSessions();
        routes.MapMyAttendance();
        routes.MapMyPerformance();
        routes.MapChildClasses();
        routes.MapChildAttendance();
        routes.MapChildPerformance();
        routes.MapClassesList();
        routes.MapClassDetail();
        routes.MapClassStudents();
        routes.MapClassTeachers();
        routes.MapClassSchedule();
        routes.MapClassCreateOptions();
        routes.MapClassCreateTeachers();
        routes.MapClassManage();
        routes.MapClassCreate();
        routes.MapClassUpdate();
        routes.MapClassScheduleUpdate();
        routes.MapClassStudentAdmin();
        routes.MapClassStudentAdd();
        routes.MapClassJoin();
        routes.MapRegistrationClasses();
        routes.MapRegistrationPlace();
        routes.MapJoinPreview();
        routes.MapClassStudentTransfer();
        routes.MapClassStudentEdit();
        routes.MapClassDeactivate();
        routes.MapClassStudentRemove();
        routes.MapClassStudentRestore();
        routes.MapClassStudentsPerformance();
        routes.MapTeacherDetail();
        routes.MapPlannedRoutes();
        return routes;
    }
}
