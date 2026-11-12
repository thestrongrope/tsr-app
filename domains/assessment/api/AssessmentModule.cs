using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Tsr.Assessment.Api.Domain;
using Tsr.Assessment.Api.Features.AdminQuiz;
using Tsr.Assessment.Api.Features.AdminQuizDownload;
using Tsr.Assessment.Api.Features.AdminQuizPublish;
using Tsr.Assessment.Api.Features.AdminQuizReset;
using Tsr.Assessment.Api.Features.AdminQuizSettingsRefresh;
using Tsr.Assessment.Api.Features.AdminQuizWinnersGenerate;
using Tsr.Assessment.Api.Features.AdminQuizWinnersRegenerate;
using Tsr.Assessment.Api.Features.ChildScores;
using Tsr.Assessment.Api.Features.ClassMyScores;
using Tsr.Assessment.Api.Features.ClassQuizzes;
using Tsr.Assessment.Api.Features.CopyClasses;
using Tsr.Assessment.Api.Features.CopyQuizzes;
using Tsr.Assessment.Api.Features.CopyTopics;
using Tsr.Assessment.Api.Features.ManageCopy;
using Tsr.Assessment.Api.Features.ManageCreate;
using Tsr.Assessment.Api.Features.ManageDeactivate;
using Tsr.Assessment.Api.Features.ManageList;
using Tsr.Assessment.Api.Features.ManageOffline;
using Tsr.Assessment.Api.Features.ManageOfflineSave;
using Tsr.Assessment.Api.Features.ManageQuiz;
using Tsr.Assessment.Api.Features.ManageScores;
using Tsr.Assessment.Api.Features.ManageStandard;
using Tsr.Assessment.Api.Features.ManageStandardCopy;
using Tsr.Assessment.Api.Features.ManageTopics;
using Tsr.Assessment.Api.Features.ManageUpdate;
using Tsr.Assessment.Api.Features.OpenQuizzes;
using Tsr.Assessment.Api.Features.QuizByCode;
using Tsr.Assessment.Api.Features.QuizDetail;
using Tsr.Assessment.Api.Features.QuizMyScore;
using Tsr.Assessment.Api.Features.QuizQuestions;
using Tsr.Assessment.Api.Features.QuizSubmit;
using Tsr.Assessment.Api.Features.StandardMcqSources;
using Tsr.Assessment.Api.Features.StandardMcqUpdate;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api;

/// <summary>
/// assessment: spot quizzes, standard MCQs and quiz campaigns. Tables, the student quiz slices (batch A1), and placeholder routes (Planned.cs) so far; no public interface yet.
/// </summary>
public static class AssessmentModule
{
    /// <summary>Other domain modules this one may use (domains/CLAUDE.md rule 7). access (permissions); notifications (the quiz announcement command); classes, membership and identity are read through their v_* views.</summary>
    public static readonly IReadOnlyList<string> Dependencies = ["access", "notifications"];

    public static IServiceCollection AddAssessment(this IServiceCollection services)
    {
        services.AddDomainContext<AssessmentContext>(AssessmentContext.SchemaName);
        // Google Sheets: one client for the process (it caches the access token); the credential is an optional setting, so the API starts without it and a sheet route then answers 502 or "could not be read".
        services.AddOptions<GoogleSheetsSettings>().Configure<IConfiguration>((settings, configuration) =>
        {
            settings.ServiceAccountB64 = configuration[GoogleSheetsSettings.Key];
            settings.QuizSettingsSheetId = configuration[GoogleSheetsSettings.QuizSettingsSheetKey];
        });
        services.AddSingleton<IQuizRandom, CryptoQuizRandom>();
        services.AddSingleton<ISheets>(provider => new GoogleSheets(
            provider.GetRequiredService<IHttpClientFactory>().CreateClient("google-sheets"),
            provider.GetRequiredService<Microsoft.Extensions.Options.IOptions<GoogleSheetsSettings>>(),
            provider.GetRequiredService<TimeProvider>()));
        services.AddHttpClient("google-sheets", client =>
        {
            client.Timeout = TimeSpan.FromSeconds(30);
            client.MaxResponseContentBufferSize = 20_000_000;
        });
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
        routes.MapStandardMcqSources();
        routes.MapStandardMcqUpdate();
        routes.MapAdminQuiz();
        routes.MapAdminQuizDownload();
        routes.MapAdminQuizPublish();
        routes.MapAdminQuizReset();
        routes.MapAdminQuizSettingsRefresh();
        routes.MapAdminQuizWinnersGenerate();
        routes.MapAdminQuizWinnersRegenerate();
        routes.MapCopyClasses();
        routes.MapCopyTopics();
        routes.MapCopyQuizzes();
        routes.MapManageList();
        routes.MapManageDeactivate();
        routes.MapManageStandard();
        routes.MapManageTopics();
        routes.MapManageQuiz();
        routes.MapManageUpdate();
        routes.MapManageCreate();
        routes.MapManageStandardCopy();
        routes.MapManageCopy();
        routes.MapManageScores();
        routes.MapManageOffline();
        routes.MapManageOfflineSave();
        routes.MapPlannedRoutes();
        return routes;
    }
}
