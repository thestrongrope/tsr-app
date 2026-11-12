using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Assessment.Api.Features.ChildScores;
using Tsr.Assessment.Api.Features.ClassMyScores;
using Tsr.Assessment.Api.Features.ClassQuizzes;
using Tsr.Assessment.Api.Features.OpenQuizzes;
using Tsr.Assessment.Api.Features.QuizByCode;
using Tsr.Assessment.Api.Features.QuizDetail;
using Tsr.Assessment.Api.Features.QuizMyScore;
using Tsr.Assessment.Api.Features.QuizQuestions;
using Tsr.Assessment.Api.Features.QuizSubmit;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api;

/// <summary>
/// assessment: spot quizzes, standard MCQs and quiz campaigns. Tables, the student quiz slices (batch A1), and placeholder routes (Planned.cs) so far; no public interface yet.
/// </summary>
public static class AssessmentModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). access (permissions); classes, membership and identity are read through their v_* views.</summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access"];

    public static IServiceCollection AddAssessment(this IServiceCollection services)
    {
        services.AddDomainContext<AssessmentContext>(AssessmentContext.SchemaName);
        return services;
    }

    public static IEndpointRouteBuilder MapAssessment(this IEndpointRouteBuilder routes)
    {
        routes.MapQuizDetail();
        routes.MapQuizQuestions();
        routes.MapQuizMyScore();
        routes.MapChildScores();
        routes.MapClassMyScores();
        routes.MapClassQuizzes();
        routes.MapOpenQuizzes();
        routes.MapQuizByCode();
        routes.MapQuizSubmit();
        routes.MapPlannedRoutes();
        return routes;
    }
}
