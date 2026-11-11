using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Classes.Api.Features.ClassLevels;
using Tsr.Shared.Api;

namespace Tsr.Classes.Api;

/// <summary>
/// classes: classes, levels, enrolment, sessions, attendance, teachers, syllabus and guides. Tables, and placeholder routes (Planned.cs) so far; no
/// public interface yet. It will supply access's <c>IClassScopes</c> and membership's <c>IClassEnrolments</c> when its slices arrive.
/// </summary>
public static class ClassesModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). None yet: it holds ids of other domains as plain integers.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    public static IServiceCollection AddClasses(this IServiceCollection services)
    {
        services.AddDomainContext<ClassesContext>(ClassesContext.SchemaName);
        return services;
    }

    public static IEndpointRouteBuilder MapClasses(this IEndpointRouteBuilder routes)
    {
        routes.MapClassLevels();
        routes.MapPlannedRoutes();
        return routes;
    }
}
