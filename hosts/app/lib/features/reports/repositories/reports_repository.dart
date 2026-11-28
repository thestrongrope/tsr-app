import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/active_teachers_report.dart';
import '../models/class_sessions_report.dart';
import '../models/conduction_report.dart';
import '../models/pending_report.dart';
import '../models/mcq_adherence_report.dart';
import '../models/mcq_summary_report.dart';
import '../models/quran_leaderboard.dart';
import '../models/student_performance.dart';
import '../models/subject_conduction_report.dart';
import '../models/tsr_report.dart';
import '../models/summary_report.dart';
import '../models/this_week.dart';
import '../models/unplaced_registrations.dart';
import '../models/weekly_report.dart';

/// API calls behind the class coordination reports (#568). The server checks
/// `reports:read` and narrows the classes to what the caller reaches; hiding
/// the entry in the app is only a courtesy.
class ReportsRepository {
  final ApiClient _apiClient;

  ReportsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// A null [year] and [week] ask for the last completed week; a null [gender]
  /// leaves it to the server (the caller's own gender, else gents).
  Future<ConductionReport> getConduction({
    int? gender,
    int? year,
    int? week,
    String? level,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsConductionEndpoint,
      queryParameters: {
        'gender': ?gender,
        'year': ?year,
        'week': ?week,
        if (level != null && level.isNotEmpty) 'level': level,
      },
    );
    return ConductionReport.fromJson(body);
  }

  /// The report as a file, with the same choices as [getConduction]; the server
  /// builds it from the same figures, under the same guard and scope.
  Future<List<int>> downloadConduction({
    required String format,
    int? gender,
    int? year,
    int? week,
    String? level,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsConductionDownloadEndpoint,
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'year': ?year,
        'week': ?week,
        if (level != null && level.isNotEmpty) 'level': level,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// Every week's detail rows as CSV, for the gender and week on screen (the
  /// week sets the window). The level is not sent: the file covers every level.
  /// Throws an `ApiException` with 404 when there is no data.
  Future<List<int>> downloadConductionAllWeeks({
    int? gender,
    int? year,
    int? week,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsConductionDownloadAllEndpoint,
      queryParameters: {'gender': ?gender, 'year': ?year, 'week': ?week},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// [from] and [to] are `MM-YYYY`; null asks for the current month.
  Future<WeeklyReport> getWeekly({
    int? gender,
    String? from,
    String? to,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsWeeklyEndpoint,
      queryParameters: {'gender': ?gender, 'from': ?from, 'to': ?to},
    );
    return WeeklyReport.fromJson(body);
  }

  /// The weekly report as a file, with the same choices as [getWeekly] and the
  /// level on screen; built by the server from the same figures.
  Future<List<int>> downloadWeekly({
    required String format,
    int? gender,
    String? from,
    String? to,
    String? level,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsWeeklyDownloadEndpoint,
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
        if (level != null && level.isNotEmpty) 'level': level,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// [from] and [to] are `MM-YYYY`; null asks for the server's default (the
  /// last three months, to now).
  Future<SummaryReport> getSummary({
    int? gender,
    String? from,
    String? to,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsSummaryEndpoint,
      queryParameters: {'gender': ?gender, 'from': ?from, 'to': ?to},
    );
    return SummaryReport.fromJson(body);
  }

  /// The summary as a file, with the same choices as [getSummary] and the
  /// level on screen; built by the server from the same figures.
  Future<List<int>> downloadSummary({
    required String format,
    int? gender,
    String? from,
    String? to,
    String? level,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsSummaryDownloadEndpoint,
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
        if (level != null && level.isNotEmpty) 'level': level,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// [from] and [to] are `YYYY-MM-DD`; null asks for the last 30 days.
  Future<StudentsReport> getStudents({
    int? gender,
    String? from,
    String? to,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsStudentsEndpoint,
      queryParameters: {'gender': ?gender, 'from': ?from, 'to': ?to},
    );
    return StudentsReport.fromJson(body);
  }

  /// [from] and [to] are `YYYY-MM-DD`; null asks for the last 14 days.
  Future<TsrReport> getTsr({int? gender, String? from, String? to}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsTsrEndpoint,
      queryParameters: {'gender': ?gender, 'from': ?from, 'to': ?to},
    );
    return TsrReport.fromJson(body);
  }

  /// The students as a file, with the same choices as [getStudents] plus the
  /// level and class on screen; built by the server from the same figures.
  Future<List<int>> downloadStudents({
    required String format,
    int? gender,
    String? from,
    String? to,
    String? level,
    String? className,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsStudentsDownloadEndpoint,
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
        if (level != null && level.isNotEmpty) 'level': level,
        if (className != null && className.isNotEmpty) 'class': className,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// TSR at a glance as a file, with the same choices as [getTsr].
  Future<List<int>> downloadTsr({
    required String format,
    int? gender,
    String? from,
    String? to,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsTsrDownloadEndpoint,
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// [from] and [to] are `MM-YYYY`; null asks for the previous and current month.
  Future<PendingReport> getPending({
    int? gender,
    String? from,
    String? to,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsPendingEndpoint,
      queryParameters: {'gender': ?gender, 'from': ?from, 'to': ?to},
    );
    return PendingReport.fromJson(body);
  }

  /// The pending report as a file, with the same choices as [getPending] and
  /// the level and class on screen; built by the server from the same figures.
  Future<List<int>> downloadPending({
    required String format,
    int? gender,
    String? from,
    String? to,
    String? level,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsPendingDownloadEndpoint,
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
        if (level != null && level.isNotEmpty) 'level': level,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// Previews, or with [send] sends, a reminder to one teacher about their
  /// pending forms and MCQs. Only [send] true pushes anything; the server
  /// recomputes what is pending from the caller's own reach and uses a fixed
  /// message, so nothing here decides the text.
  Future<PendingNudge> nudgePending({
    required int teacherToken,
    String? from,
    String? to,
    bool send = false,
  }) async {
    final body = await _apiClient.post<dynamic>(
      AppConstants.reportsPendingNudgeEndpoint,
      data: {'teacher': teacherToken, 'from': ?from, 'to': ?to, 'send': send},
    );
    return PendingNudge.fromJson(body);
  }

  /// [from] and [to] are `MM-YYYY`; null asks for the current month.
  Future<SubjectConductionReport> getSubjectConduction({
    int? gender,
    String? from,
    String? to,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsSubjectConductionEndpoint,
      queryParameters: {'gender': ?gender, 'from': ?from, 'to': ?to},
    );
    return SubjectConductionReport.fromJson(body);
  }

  /// The report as a file, with the same choices as [getSubjectConduction] and
  /// the level on screen; built by the server from the same rows.
  Future<List<int>> downloadSubjectConduction({
    required String format,
    int? gender,
    String? from,
    String? to,
    String? level,
    int? classId,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsSubjectConductionDownloadEndpoint,
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
        if (level != null && level.isNotEmpty) 'level': level,
        'classId': ?classId,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// A null [gender] leaves it to the server (the caller's own, else gents).
  Future<ClassSessionsReport> getClassSessions({int? gender}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsClassSessionsEndpoint,
      queryParameters: {'gender': ?gender},
    );
    return ClassSessionsReport.fromJson(body);
  }

  /// Every session of one class, newest first. A class outside the caller's
  /// reach comes back empty, as one with no sessions does.
  Future<List<ClassSession>> getClassSessionHistory(int classId) async {
    final body = await _apiClient.get<dynamic>(
      '${AppConstants.reportsClassSessionsEndpoint}/$classId',
    );
    return ClassSession.listFromJson(body);
  }

  /// The class's history as a file; built by the server from the same rows.
  Future<List<int>> downloadClassSessionHistory({
    required int classId,
    required String format,
  }) {
    return _apiClient.get<List<int>>(
      '${AppConstants.reportsClassSessionsEndpoint}/$classId/download',
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// Every permitted class's sessions for the gender on screen, as CSV. Throws
  /// an `ApiException` with 404 when there are no sessions.
  Future<List<int>> downloadClassSessionsAll({int? gender}) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsClassSessionsDownloadAllEndpoint,
      queryParameters: {'gender': ?gender},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// [from] and [to] are `YYYY-MM-DD`; null asks for the last 30 days.
  Future<McqSummaryReport> getMcqSummary({
    int? gender,
    String? from,
    String? to,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsMcqSummaryEndpoint,
      queryParameters: {'gender': ?gender, 'from': ?from, 'to': ?to},
    );
    return McqSummaryReport.fromJson(body);
  }

  /// The classes in view with their students, as CSV. [classIds] are the
  /// classes on screen. Throws an `ApiException` with 404 when there are none.
  Future<List<int>> downloadMcqSummaryAll({
    required List<int> classIds,
    int? gender,
    String? from,
    String? to,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsMcqSummaryDownloadAllEndpoint,
      queryParameters: {
        'classIds': classIds.join(','),
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// One class's students over the period.
  Future<McqSummaryDetail> getMcqSummaryClass({
    required int classId,
    int? gender,
    String? from,
    String? to,
  }) async {
    final body = await _apiClient.get<dynamic>(
      '${AppConstants.reportsMcqSummaryEndpoint}/$classId',
      queryParameters: {'gender': ?gender, 'from': ?from, 'to': ?to},
    );
    return McqSummaryDetail.fromJson(body);
  }

  /// The class's students as a file; built by the server from the same figures.
  Future<List<int>> downloadMcqSummaryClass({
    required int classId,
    required String format,
    int? gender,
    String? from,
    String? to,
  }) {
    return _apiClient.get<List<int>>(
      '${AppConstants.reportsMcqSummaryEndpoint}/$classId/download',
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// A null [gender] leaves it to the server (the caller's own, else gents).
  Future<McqAdherenceReport> getMcqAdherence({int? gender}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsMcqAdherenceEndpoint,
      queryParameters: {'gender': ?gender},
    );
    return McqAdherenceReport.fromJson(body);
  }

  /// The classes in view with their standard MCQs, as CSV. Throws an
  /// `ApiException` with 404 when there are none.
  Future<List<int>> downloadMcqAdherenceAll({
    required List<int> classIds,
    int? gender,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsMcqAdherenceDownloadAllEndpoint,
      queryParameters: {'classIds': classIds.join(','), 'gender': ?gender},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// One class's standard MCQs and where it stands on each.
  Future<McqAdherenceDetail> getMcqAdherenceClass({
    required int classId,
    int? gender,
  }) async {
    final body = await _apiClient.get<dynamic>(
      '${AppConstants.reportsMcqAdherenceEndpoint}/$classId',
      queryParameters: {'gender': ?gender},
    );
    return McqAdherenceDetail.fromJson(body);
  }

  /// The class's MCQs as a file; built by the server from the same figures.
  Future<List<int>> downloadMcqAdherenceClass({
    required int classId,
    required String format,
    int? gender,
  }) {
    return _apiClient.get<List<int>>(
      '${AppConstants.reportsMcqAdherenceEndpoint}/$classId/download',
      queryParameters: {'format': format, 'gender': ?gender},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// A null [gender] leaves it to the server (the caller's own, else gents).
  Future<UnplacedRegistrations> getRegistrations({int? gender}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsRegistrationsEndpoint,
      queryParameters: {'gender': ?gender},
    );
    return UnplacedRegistrations.fromJson(body);
  }

  /// The weekly review for a gender (#615); null leaves it to the server.
  Future<ThisWeek> getThisWeek({int? gender}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsThisWeekEndpoint,
      queryParameters: {'gender': ?gender},
    );
    return ThisWeek.fromJson(body);
  }

  /// What [classId] taught in each of the last eight weeks (#615).
  Future<ClassAlignment> getClassAlignment(int classId) async {
    final body = await _apiClient.get<dynamic>(
      '${AppConstants.reportsThisWeekEndpoint}/class/$classId',
    );
    return ClassAlignment.fromJson(body);
  }

  /// The classes [registrationId] could be placed in: active, of their gender,
  /// and ones the caller may enrol into. The server decides which.
  Future<List<PlacementClass>> getRegistrationClasses(
    int registrationId,
  ) async {
    final body = await _apiClient.get<dynamic>(
      '${AppConstants.registrationsEndpoint}/$registrationId/classes',
    );
    return PlacementClass.listFromJson(body);
  }

  /// Puts the waiting registrant in [classId]. Throws an `ApiException`: 409
  /// when someone has already placed or rejected them, 422 for a class of the
  /// other gender, 403 without permission for that class.
  Future<void> placeRegistrant(int registrationId, int classId) async {
    await _apiClient.post<dynamic>(
      '${AppConstants.registrationsEndpoint}/$registrationId/place',
      data: {'classId': classId},
    );
  }

  /// Turns the waiting registrant down; [reason] is required by the server.
  Future<void> rejectRegistrant(int registrationId, String reason) async {
    await _apiClient.post<dynamic>(
      '${AppConstants.registrationsEndpoint}/$registrationId/reject',
      data: {'reason': reason},
    );
  }

  /// The waiting registrations as a file, under the same guard as the list.
  Future<List<int>> downloadRegistrations({
    required String format,
    int? gender,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsRegistrationsDownloadEndpoint,
      queryParameters: {'format': format, 'gender': ?gender},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// Everyone placed in a class, with where they were placed (#637), under
  /// the same guard as the waiting list.
  Future<List<int>> downloadAllocatedRegistrations({
    required String format,
    int? gender,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsAllocatedRegistrationsDownloadEndpoint,
      queryParameters: {'format': format, 'gender': ?gender},
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// [from] and [to] are `YYYY-MM-DD`, null for the last year; [level] is a
  /// level name, null for all. A null [gender] leaves it to the server. Only
  /// members with at least [minimum] recitations in the period are listed.
  Future<QuranLeaderboard> getQuranLeaderboard({
    int? gender,
    String? from,
    String? to,
    String? level,
    int minimum = 1,
  }) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsQuranLeaderboardEndpoint,
      queryParameters: {
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
        if (level != null && level.isNotEmpty) 'level': level,
        'minimum': minimum,
      },
    );
    return QuranLeaderboard.fromJson(body);
  }

  /// Every ranked student as a file; built by the server from the same
  /// ranking, under the same guard.
  Future<List<int>> downloadQuranLeaderboard({
    required String format,
    int? gender,
    String? from,
    String? to,
    String? level,
    int minimum = 1,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsQuranLeaderboardDownloadEndpoint,
      queryParameters: {
        'format': format,
        'gender': ?gender,
        'from': ?from,
        'to': ?to,
        if (level != null && level.isNotEmpty) 'level': level,
        'minimum': minimum,
      },
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// A null [gender] leaves it to the server (the caller's own, else gents).
  Future<ActiveTeachersReport> getActiveTeachers({int? gender}) async {
    final body = await _apiClient.get<dynamic>(
      AppConstants.reportsActiveTeachersEndpoint,
      queryParameters: {'gender': ?gender},
    );
    return ActiveTeachersReport.fromJson(body);
  }

  /// The report as a file, with the same choice as [getActiveTeachers]; built
  /// by the server from the same figures.
  Future<List<int>> downloadActiveTeachers({
    required String format,
    int? gender,
  }) {
    return _apiClient.get<List<int>>(
      AppConstants.reportsActiveTeachersDownloadEndpoint,
      queryParameters: {'format': format, 'gender': ?gender},
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
