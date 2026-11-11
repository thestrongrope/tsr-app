using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api;

/// <summary>
/// assessment: spot quizzes, standard MCQs and quiz campaigns. Tables, and placeholder routes (Planned.cs) so far; no public interface yet.
/// </summary>
public static class AssessmentModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). None yet: it holds ids of other domains as plain integers.</summary>
    public static readonly IReadOnlyList<string> Dependencies = [];

    public static IServiceCollection AddAssessment(this IServiceCollection services)
    {
        services.AddDomainContext<AssessmentContext>(AssessmentContext.SchemaName);
        return services;
    }

    public static IEndpointRouteBuilder MapAssessment(this IEndpointRouteBuilder routes)
    {
        routes.MapPlannedRoutes();
        return routes;
    }
}
