using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using Tsr.Shared.Api;

namespace Tsr.Assessment.Api.Domain;

/// <summary>The payload of <c>assessment.quiz_state_changed</c>: <c>{"action":"..."}</c>.</summary>
internal sealed record QuizStateChanged(string Action);

/// <summary>The wire shape of a refused submission: <c>{"detail":{"missing":[...],"extra":[...]}}</c> (question ids).</summary>
internal sealed record AnswerMismatch(AnswerMismatch.Ids Detail)
{
    internal sealed record Ids(IReadOnlyList<long> Missing, IReadOnlyList<long> Extra);
}

/// <summary>The criteria text of a quiz announcement: type CLASS and the class id as the one text of the value list.</summary>
internal sealed record AnnounceCriteria(string Type, IReadOnlyList<string> Value);

/// <summary>
/// The source-generated serializer of this domain: answers, event payloads (camelCase as the reflection serializer's web defaults wrote them) and the Google Sheets wire records, so nothing is serialized by reflection.
/// </summary>
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(QuizStateChanged))]
[JsonSerializable(typeof(AnnounceCriteria))]
[JsonSerializable(typeof(Features.ManageDeactivate.ManageDeactivateSlice.QuizDeactivated))]
[JsonSerializable(typeof(Features.ManageCreate.ManageCreateSlice.QuizCreated), TypeInfoPropertyName = "QuizCreatedNew")]
[JsonSerializable(typeof(Features.ManageStandardCopy.ManageStandardCopySlice.QuizCreated), TypeInfoPropertyName = "QuizCreatedStandard")]
[JsonSerializable(typeof(Features.ManageCopy.ManageCopySlice.QuizCreated), TypeInfoPropertyName = "QuizCreatedCopy")]
[JsonSerializable(typeof(Features.ManageUpdate.ManageUpdateSlice.QuizUpdated))]
[JsonSerializable(typeof(Features.ManagePublish.ManagePublishSlice.QuizPublished))]
[JsonSerializable(typeof(Features.ManageOfflineSave.ManageOfflineSaveSlice.OfflineRecorded))]
[JsonSerializable(typeof(Features.QuizSubmit.QuizSubmitSlice.Answered))]
[JsonSerializable(typeof(Features.StandardMcqUpdate.StandardMcqUpdateSlice.Updated))]
[JsonSerializable(typeof(Features.QuizDetail.QuizDetailSlice.Body), TypeInfoPropertyName = "QuizDetail")]
[JsonSerializable(typeof(Features.QuizQuestions.QuizQuestionsSlice.Body), TypeInfoPropertyName = "QuizQuestions")]
[JsonSerializable(typeof(Features.ClassQuizzes.ClassQuizzesSlice.Body), TypeInfoPropertyName = "ClassQuizzes")]
[JsonSerializable(typeof(Features.OpenQuizzes.OpenQuizzesSlice.Body), TypeInfoPropertyName = "OpenQuizzes")]
[JsonSerializable(typeof(Features.QuizByCode.QuizByCodeSlice.Body), TypeInfoPropertyName = "QuizByCode")]
[JsonSerializable(typeof(QuizResult.Body), TypeInfoPropertyName = "QuizResult")]
[JsonSerializable(typeof(AnswerMismatch))]
[JsonSerializable(typeof(List<Features.ClassMyScores.ClassMyScoresSlice.Item>), TypeInfoPropertyName = "ClassMyScores")]
[JsonSerializable(typeof(List<Features.ChildScores.ChildScoresSlice.Item>), TypeInfoPropertyName = "ChildScores")]
[JsonSerializable(typeof(Features.ManageList.ManageListSlice.Body), TypeInfoPropertyName = "ManageList")]
[JsonSerializable(typeof(Features.ManageDeactivate.ManageDeactivateSlice.Body), TypeInfoPropertyName = "ManageDeactivate")]
[JsonSerializable(typeof(Features.ManageStandard.ManageStandardSlice.Body), TypeInfoPropertyName = "ManageStandard")]
[JsonSerializable(typeof(IReadOnlyList<string>), TypeInfoPropertyName = "TextList")]
[JsonSerializable(typeof(Features.ManageQuiz.ManageQuizSlice.Body), TypeInfoPropertyName = "ManageQuiz")]
[JsonSerializable(typeof(Features.ManageUpdate.ManageUpdateSlice.Body), TypeInfoPropertyName = "ManageUpdate")]
[JsonSerializable(typeof(Features.ManageCreate.ManageCreateSlice.Body), TypeInfoPropertyName = "ManageCreate")]
[JsonSerializable(typeof(Features.ManageStandardCopy.ManageStandardCopySlice.Body), TypeInfoPropertyName = "ManageStandardCopy")]
[JsonSerializable(typeof(Features.ManageCopy.ManageCopySlice.Body), TypeInfoPropertyName = "ManageCopy")]
[JsonSerializable(typeof(Features.ManageOffline.ManageOfflineSlice.Body), TypeInfoPropertyName = "ManageOffline")]
[JsonSerializable(typeof(Features.ManageOfflineSave.ManageOfflineSaveSlice.Body), TypeInfoPropertyName = "ManageOfflineSave")]
[JsonSerializable(typeof(Features.ManageOfflineSave.ManageOfflineSaveSlice.Conflict))]
[JsonSerializable(typeof(Features.ManageScores.ManageScoresSlice.Body), TypeInfoPropertyName = "ManageScores")]
[JsonSerializable(typeof(Features.ManagePublish.ManagePublishSlice.Body), TypeInfoPropertyName = "ManagePublish")]
[JsonSerializable(typeof(List<Features.CopyClasses.CopyClassesSlice.Item>), TypeInfoPropertyName = "CopyClasses")]
[JsonSerializable(typeof(List<Features.CopyQuizzes.CopyQuizzesSlice.Item>), TypeInfoPropertyName = "CopyQuizzes")]
[JsonSerializable(typeof(Features.StandardMcqSources.StandardMcqSourcesSlice.Body), TypeInfoPropertyName = "StandardMcqSources")]
[JsonSerializable(typeof(Features.StandardMcqUpdate.StandardMcqUpdateSlice.Body), TypeInfoPropertyName = "StandardMcqUpdate")]
[JsonSerializable(typeof(Features.QuizQuestions.QuizQuestionsSlice.Item), TypeInfoPropertyName = "QuizQuestionsItem")]
[JsonSerializable(typeof(Features.ClassQuizzes.ClassQuizzesSlice.Item), TypeInfoPropertyName = "ClassQuizzesItem")]
[JsonSerializable(typeof(Features.OpenQuizzes.OpenQuizzesSlice.Item), TypeInfoPropertyName = "OpenQuizzesItem")]
[JsonSerializable(typeof(Features.ManageList.ManageListSlice.Item), TypeInfoPropertyName = "ManageListItem")]
[JsonSerializable(typeof(Features.ClassMyScores.ClassMyScoresSlice.Item), TypeInfoPropertyName = "ClassMyScoresItem")]
[JsonSerializable(typeof(Features.ChildScores.ChildScoresSlice.Item), TypeInfoPropertyName = "ChildScoresItem")]
[JsonSerializable(typeof(Features.CopyClasses.CopyClassesSlice.Item), TypeInfoPropertyName = "CopyClassesItem")]
[JsonSerializable(typeof(Features.CopyQuizzes.CopyQuizzesSlice.Item), TypeInfoPropertyName = "CopyQuizzesItem")]
[JsonSerializable(typeof(IReadOnlyList<Features.QuizQuestions.QuizQuestionsSlice.Item>), TypeInfoPropertyName = "QuizQuestionsItems")]
[JsonSerializable(typeof(IReadOnlyList<Features.ClassQuizzes.ClassQuizzesSlice.Item>), TypeInfoPropertyName = "ClassQuizzesItems")]
[JsonSerializable(typeof(IReadOnlyList<Features.OpenQuizzes.OpenQuizzesSlice.Item>), TypeInfoPropertyName = "OpenQuizzesItems")]
[JsonSerializable(typeof(IReadOnlyList<Features.ManageList.ManageListSlice.Item>), TypeInfoPropertyName = "ManageListItems")]
[JsonSerializable(typeof(Features.ManageOffline.ManageOfflineSlice.QuizWire), TypeInfoPropertyName = "ManageOfflineQuiz")]
[JsonSerializable(typeof(Features.ManageScores.ManageScoresSlice.QuizWire), TypeInfoPropertyName = "ManageScoresQuiz")]
[JsonSerializable(typeof(Features.ManageQuiz.ManageQuizSlice.QuestionWire), TypeInfoPropertyName = "ManageQuizQuestion")]
[JsonSerializable(typeof(IReadOnlyList<Features.ManageQuiz.ManageQuizSlice.QuestionWire>), TypeInfoPropertyName = "ManageQuizQuestions")]
[JsonSerializable(typeof(Features.ManageOffline.ManageOfflineSlice.QuestionWire), TypeInfoPropertyName = "ManageOfflineQuestion")]
[JsonSerializable(typeof(IReadOnlyList<Features.ManageOffline.ManageOfflineSlice.QuestionWire>), TypeInfoPropertyName = "ManageOfflineQuestions")]
[JsonSerializable(typeof(JsonObject))]
[JsonSerializable(typeof(PhpFloat))]
[JsonSerializable(typeof(int))]
internal sealed partial class AssessmentJson : JsonSerializerContext
{
    /// <summary>
    /// For the answers: the host's own options (web defaults and the relaxed encoder ASP.NET Core's JSON options use, so '+' and non-ASCII text stay as written, not \uXXXX).
    /// <see cref="Default"/> (the default encoder) is for the events. <see cref="QuizResult.Body"/> holds its percent as <c>object</c>, so the two runtime types behind it (<see cref="PhpFloat"/> and <c>int</c>) are listed above.
    /// </summary>
    public static AssessmentJson Answers { get; } = new(new JsonSerializerOptions(JsonSerializerDefaults.Web) { Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
}
