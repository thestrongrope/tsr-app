using System.Text.Json;
using System.Text.Json.Serialization;
using Tsr.Classes.Api.Features.ClassCreate;
using Tsr.Classes.Api.Features.ClassDeactivate;
using Tsr.Classes.Api.Features.ClassGuide;
using Tsr.Classes.Api.Features.ClassJoin;
using Tsr.Classes.Api.Features.ClassLevels;
using Tsr.Classes.Api.Features.ClassScheduleUpdate;
using Tsr.Classes.Api.Features.ClassSessions;
using Tsr.Classes.Api.Features.ClassStudentAdmin;
using Tsr.Classes.Api.Features.ClassStudentEdit;
using Tsr.Classes.Api.Features.ClassStudentRemove;
using Tsr.Classes.Api.Features.ClassStudentRestore;
using Tsr.Classes.Api.Features.ClassUpdate;

namespace Tsr.Classes.Api;

/// <summary>The types of the class-* slices in <see cref="ClassesJson"/>: their answers, their event payloads and the value types their answer maps hold.</summary>
[JsonSerializable(typeof(ClassLevelsSlice.Level), TypeInfoPropertyName = "ClassLevelItem")]
[JsonSerializable(typeof(List<ClassLevelsSlice.Level>), TypeInfoPropertyName = "ClassLevelList")]
[JsonSerializable(typeof(ClassGuideSlice.Body), TypeInfoPropertyName = "ClassGuideBody")]
[JsonSerializable(typeof(ClassSessionsSlice.Item), TypeInfoPropertyName = "ClassSessionItem")]
[JsonSerializable(typeof(List<ClassSessionsSlice.Item>), TypeInfoPropertyName = "ClassSessionList")]
[JsonSerializable(typeof(List<object?>), TypeInfoPropertyName = "ObjectList")]
[JsonSerializable(typeof(Dictionary<string, string>), TypeInfoPropertyName = "StringMap")]
[JsonSerializable(typeof(JsonElement), TypeInfoPropertyName = "JsonElement")]
[JsonSerializable(typeof(ClassCreateSlice.ClassCreated), TypeInfoPropertyName = "ClassCreated")]
[JsonSerializable(typeof(ClassDeactivateSlice.ClassDeactivated), TypeInfoPropertyName = "ClassDeactivated")]
[JsonSerializable(typeof(ClassJoinSlice.StudentRejoined), TypeInfoPropertyName = "StudentRejoined")]
[JsonSerializable(typeof(ClassScheduleUpdateSlice.ScheduleReplaced), TypeInfoPropertyName = "ScheduleReplaced")]
[JsonSerializable(typeof(ClassStudentAdminSlice.StudentClassAdminChanged), TypeInfoPropertyName = "StudentClassAdminChanged")]
[JsonSerializable(typeof(ClassStudentEditSlice.StudentEdited), TypeInfoPropertyName = "StudentEdited")]
[JsonSerializable(typeof(ClassStudentRemoveSlice.StudentRemoved), TypeInfoPropertyName = "StudentRemoved")]
[JsonSerializable(typeof(ClassStudentRestoreSlice.StudentRestored), TypeInfoPropertyName = "StudentRestored")]
[JsonSerializable(typeof(ClassUpdateSlice.ClassUpdated), TypeInfoPropertyName = "ClassUpdated")]
internal sealed partial class ClassesJson;
