import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/share_bytes.dart';
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
import '../repositories/reports_repository.dart';

/// What the conduction screen asks for. A record, so equal choices share one
/// cached answer. Null means "the server's default".
typedef ConductionQuery = ({int? gender, int? year, int? week, String? level});

/// No automatic retry: Riverpod's default would keep the screen loading through
/// backed-off attempts, hiding the retry the screen offers (as for the release
/// notes).
final conductionReportProvider = FutureProvider.autoDispose
    .family<ConductionReport, ConductionQuery>(
      (ref, query) => ReportsRepository().getConduction(
        gender: query.gender,
        year: query.year,
        week: query.week,
        level: query.level,
      ),
      retry: (retryCount, error) => null,
    );

/// What the weekly screen asks for; `MM-YYYY` months, null for the server's
/// default (the current month).
typedef WeeklyQuery = ({int? gender, String? from, String? to});

final weeklyReportProvider = FutureProvider.autoDispose
    .family<WeeklyReport, WeeklyQuery>(
      (ref, query) => ReportsRepository().getWeekly(
        gender: query.gender,
        from: query.from,
        to: query.to,
      ),
      retry: (retryCount, error) => null,
    );

enum ReportFormat { xlsx, pdf }

/// Fetches the report as a file and hands it to the share sheet. A provider so
/// a test can stand in for the network and the sheet; it throws if the file
/// cannot be fetched, and the screen says so.
typedef ShareConduction =
    Future<void> Function(ConductionQuery query, ReportFormat format);

final shareConductionProvider = Provider<ShareConduction>(
  (ref) => (query, format) async {
    final bytes = await ReportsRepository().downloadConduction(
      format: format.name,
      gender: query.gender,
      year: query.year,
      week: query.week,
      level: query.level,
    );
    await shareBytes(
      bytes,
      'Conduction-week-${query.week}-${query.year}'
      '.${format.name}',
    );
  },
);

/// The all-weeks details file (CSV) for the gender and week on screen. Throws
/// an `ApiException` with 404 when there is no data, so no empty file is shared.
typedef ShareConductionAllWeeks = Future<void> Function(ConductionQuery query);

final shareConductionAllWeeksProvider = Provider<ShareConductionAllWeeks>(
  (ref) => (query) async {
    final bytes = await ReportsRepository().downloadConductionAllWeeks(
      gender: query.gender,
      year: query.year,
      week: query.week,
    );
    await shareBytes(
      bytes,
      'Conduction-all-weeks-${query.week}-${query.year}.csv',
    );
  },
);

/// As [ShareConduction], for the weekly report: the months and level on screen.
typedef ShareWeekly =
    Future<void> Function(
      WeeklyQuery query,
      String? level,
      ReportFormat format,
    );

final shareWeeklyProvider = Provider<ShareWeekly>(
  (ref) => (query, level, format) async {
    final bytes = await ReportsRepository().downloadWeekly(
      format: format.name,
      gender: query.gender,
      from: query.from,
      to: query.to,
      level: level,
    );
    await shareBytes(
      bytes,
      'Weekly-${query.from}-to-${query.to}.${format.name}',
    );
  },
);

/// What the summary screen asks for; `MM-YYYY` months, null for the server's
/// default (the last three months).
typedef SummaryQuery = ({int? gender, String? from, String? to});

final summaryReportProvider = FutureProvider.autoDispose
    .family<SummaryReport, SummaryQuery>(
      (ref, query) => ReportsRepository().getSummary(
        gender: query.gender,
        from: query.from,
        to: query.to,
      ),
      retry: (retryCount, error) => null,
    );

/// As [ShareWeekly], for the summary.
typedef ShareSummary =
    Future<void> Function(
      SummaryQuery query,
      String? level,
      ReportFormat format,
    );

final shareSummaryProvider = Provider<ShareSummary>(
  (ref) => (query, level, format) async {
    final bytes = await ReportsRepository().downloadSummary(
      format: format.name,
      gender: query.gender,
      from: query.from,
      to: query.to,
      level: level,
    );
    await shareBytes(
      bytes,
      'Summary-${query.from}-to-${query.to}.${format.name}',
    );
  },
);

/// What the student performance screen asks for; `YYYY-MM-DD` dates, null for
/// the server's default (the last 30 days).
typedef StudentsQuery = ({int? gender, String? from, String? to});

final studentsReportProvider = FutureProvider.autoDispose
    .family<StudentsReport, StudentsQuery>(
      (ref, query) => ReportsRepository().getStudents(
        gender: query.gender,
        from: query.from,
        to: query.to,
      ),
      retry: (retryCount, error) => null,
    );

/// What the TSR at a glance screen asks for; `YYYY-MM-DD` dates, null for the
/// server's default (the last 14 days).
typedef TsrQuery = ({int? gender, String? from, String? to});

final tsrReportProvider = FutureProvider.autoDispose
    .family<TsrReport, TsrQuery>(
      (ref, query) => ReportsRepository().getTsr(
        gender: query.gender,
        from: query.from,
        to: query.to,
      ),
      retry: (retryCount, error) => null,
    );

/// As [ShareSummary], for the student performance report: the dates, gender,
/// level and class on screen.
typedef ShareStudents =
    Future<void> Function(
      StudentsQuery query,
      String? level,
      String? className,
      ReportFormat format,
    );

final shareStudentsProvider = Provider<ShareStudents>(
  (ref) => (query, level, className, format) async {
    final bytes = await ReportsRepository().downloadStudents(
      format: format.name,
      gender: query.gender,
      from: query.from,
      to: query.to,
      level: level,
      className: className,
    );
    await shareBytes(
      bytes,
      'Students-${query.from}-to-${query.to}.${format.name}',
    );
  },
);

/// As [ShareSummary], for TSR at a glance.
typedef ShareTsr = Future<void> Function(TsrQuery query, ReportFormat format);

final shareTsrProvider = Provider<ShareTsr>(
  (ref) => (query, format) async {
    final bytes = await ReportsRepository().downloadTsr(
      format: format.name,
      gender: query.gender,
      from: query.from,
      to: query.to,
    );
    await shareBytes(bytes, 'TSR-${query.from}-to-${query.to}.${format.name}');
  },
);

/// What the pending screen asks for; `MM-YYYY` months, null for the server's
/// default (the previous and the current month).
typedef PendingQuery = ({int? gender, String? from, String? to});

final pendingReportProvider = FutureProvider.autoDispose
    .family<PendingReport, PendingQuery>(
      (ref, query) => ReportsRepository().getPending(
        gender: query.gender,
        from: query.from,
        to: query.to,
      ),
      retry: (retryCount, error) => null,
    );

/// As [ShareSummary], for the pending report.
typedef SharePending =
    Future<void> Function(
      PendingQuery query,
      String? level,
      ReportFormat format,
    );

final sharePendingProvider = Provider<SharePending>(
  (ref) => (query, level, format) async {
    final bytes = await ReportsRepository().downloadPending(
      format: format.name,
      gender: query.gender,
      from: query.from,
      to: query.to,
      level: level,
    );
    await shareBytes(
      bytes,
      'Pending-${query.from}-to-${query.to}.${format.name}',
    );
  },
);

/// Previews or sends a reminder to one teacher (#586). A provider so a test can
/// stand in for the network and no test can send a real push.
typedef NudgeTeacher =
    Future<PendingNudge> Function(
      PendingQuery query,
      int teacherToken, {
      required bool send,
    });

final nudgeTeacherProvider = Provider<NudgeTeacher>(
  (ref) =>
      (query, teacherToken, {required send}) =>
          ReportsRepository().nudgePending(
            teacherToken: teacherToken,
            from: query.from,
            to: query.to,
            send: send,
          ),
);

/// What the subject conduction screen asks for; `MM-YYYY` months, null for the
/// server's default (the current month).
typedef SubjectConductionQuery = ({int? gender, String? from, String? to});

final subjectConductionReportProvider = FutureProvider.autoDispose
    .family<SubjectConductionReport, SubjectConductionQuery>(
      (ref, query) => ReportsRepository().getSubjectConduction(
        gender: query.gender,
        from: query.from,
        to: query.to,
      ),
      retry: (retryCount, error) => null,
    );

/// As [ShareSummary], for the subject conduction report.
typedef ShareSubjectConduction =
    Future<void> Function(
      SubjectConductionQuery query,
      String? level,
      int? classId,
      ReportFormat format,
    );

final shareSubjectConductionProvider = Provider<ShareSubjectConduction>(
  (ref) => (query, level, classId, format) async {
    final bytes = await ReportsRepository().downloadSubjectConduction(
      format: format.name,
      gender: query.gender,
      from: query.from,
      to: query.to,
      level: level,
      classId: classId,
    );
    await shareBytes(
      bytes,
      'Subject-conduction-${query.from}-to-${query.to}'
      '.${format.name}',
    );
  },
);

/// The class sessions list for a gender; null for the server's default.
final classSessionsReportProvider = FutureProvider.autoDispose
    .family<ClassSessionsReport, int?>(
      (ref, gender) => ReportsRepository().getClassSessions(gender: gender),
      retry: (retryCount, error) => null,
    );

/// One class's sessions, newest first.
final classSessionHistoryProvider = FutureProvider.autoDispose
    .family<List<ClassSession>, int>(
      (ref, classId) => ReportsRepository().getClassSessionHistory(classId),
      retry: (retryCount, error) => null,
    );

/// Every permitted class's sessions (CSV) for a gender. Throws an
/// `ApiException` with 404 when there are none, so no empty file is shared.
typedef ShareClassSessionsAll = Future<void> Function(int gender);

final shareClassSessionsAllProvider = Provider<ShareClassSessionsAll>(
  (ref) => (gender) async {
    final bytes = await ReportsRepository().downloadClassSessionsAll(
      gender: gender,
    );
    await shareBytes(bytes, 'Class-sessions-all-$gender.csv');
  },
);

/// As [ShareSubjectConduction], for one class's history.
typedef ShareClassSessions =
    Future<void> Function(int classId, ReportFormat format);

final shareClassSessionsProvider = Provider<ShareClassSessions>(
  (ref) => (classId, format) async {
    final bytes = await ReportsRepository().downloadClassSessionHistory(
      classId: classId,
      format: format.name,
    );
    await shareBytes(bytes, 'Class-sessions-$classId.${format.name}');
  },
);

/// What the MCQ summary screen asks for; `YYYY-MM-DD` dates, null for the
/// server's default (the last 30 days).
typedef McqSummaryQuery = ({int? gender, String? from, String? to});

final mcqSummaryReportProvider = FutureProvider.autoDispose
    .family<McqSummaryReport, McqSummaryQuery>(
      (ref, query) => ReportsRepository().getMcqSummary(
        gender: query.gender,
        from: query.from,
        to: query.to,
      ),
      retry: (retryCount, error) => null,
    );

/// The classes in view, as one CSV. Throws an `ApiException` with 404 when
/// the server has nothing to send, so no empty file is shared.
typedef ShareMcqSummaryAll =
    Future<void> Function({
      required List<int> classIds,
      required int gender,
      required String from,
      required String to,
    });

final shareMcqSummaryAllProvider = Provider<ShareMcqSummaryAll>(
  (ref) =>
      ({required classIds, required gender, required from, required to}) async {
        final bytes = await ReportsRepository().downloadMcqSummaryAll(
          classIds: classIds,
          gender: gender,
          from: from,
          to: to,
        );
        await shareBytes(bytes, 'MCQ-summary-all-$gender-$from-to-$to.csv');
      },
);

/// One class's students for the period the list answered for.
typedef McqSummaryClassQuery = ({
  int classId,
  int? gender,
  String? from,
  String? to,
});

final mcqSummaryClassProvider = FutureProvider.autoDispose
    .family<McqSummaryDetail, McqSummaryClassQuery>(
      (ref, query) => ReportsRepository().getMcqSummaryClass(
        classId: query.classId,
        gender: query.gender,
        from: query.from,
        to: query.to,
      ),
      retry: (retryCount, error) => null,
    );

/// As [ShareClassSessions], for a class's MCQ summary.
typedef ShareMcqSummaryClass =
    Future<void> Function(McqSummaryClassQuery query, ReportFormat format);

final shareMcqSummaryClassProvider = Provider<ShareMcqSummaryClass>(
  (ref) => (query, format) async {
    final bytes = await ReportsRepository().downloadMcqSummaryClass(
      classId: query.classId,
      format: format.name,
      gender: query.gender,
      from: query.from,
      to: query.to,
    );
    await shareBytes(
      bytes,
      'MCQ-summary-${query.classId}-${query.from}-to-${query.to}'
      '.${format.name}',
    );
  },
);

/// The MCQ adherence list for a gender; null for the server's default.
final mcqAdherenceReportProvider = FutureProvider.autoDispose
    .family<McqAdherenceReport, int?>(
      (ref, gender) => ReportsRepository().getMcqAdherence(gender: gender),
      retry: (retryCount, error) => null,
    );

/// As [ShareMcqSummaryAll], for the MCQ adherence of the classes in view.
typedef ShareMcqAdherenceAll =
    Future<void> Function({required List<int> classIds, required int gender});

final shareMcqAdherenceAllProvider = Provider<ShareMcqAdherenceAll>(
  (ref) => ({required classIds, required gender}) async {
    final bytes = await ReportsRepository().downloadMcqAdherenceAll(
      classIds: classIds,
      gender: gender,
    );
    await shareBytes(bytes, 'MCQ-adherence-all-$gender.csv');
  },
);

/// One class's standard MCQs, for the gender the list answered for.
typedef McqAdherenceClassQuery = ({int classId, int? gender});

final mcqAdherenceClassProvider = FutureProvider.autoDispose
    .family<McqAdherenceDetail, McqAdherenceClassQuery>(
      (ref, query) => ReportsRepository().getMcqAdherenceClass(
        classId: query.classId,
        gender: query.gender,
      ),
      retry: (retryCount, error) => null,
    );

/// As [ShareMcqSummaryClass], for a class's MCQ adherence.
typedef ShareMcqAdherenceClass =
    Future<void> Function(McqAdherenceClassQuery query, ReportFormat format);

final shareMcqAdherenceClassProvider = Provider<ShareMcqAdherenceClass>(
  (ref) => (query, format) async {
    final bytes = await ReportsRepository().downloadMcqAdherenceClass(
      classId: query.classId,
      format: format.name,
      gender: query.gender,
    );
    await shareBytes(bytes, 'MCQ-adherence-${query.classId}.${format.name}');
  },
);

/// Opens a link in another app (the dialer, WhatsApp); false when nothing can.
typedef LaunchLink = Future<bool> Function(Uri uri);

/// What the This week buttons call; the default hands the link to the phone.
/// A provider so a test can see which link would have opened.
final thisWeekLaunchProvider = Provider<LaunchLink>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// The coordinator's weekly review (#615), for a gender; null for the server's
/// default.
final thisWeekProvider = FutureProvider.autoDispose.family<ThisWeek, int?>(
  (ref, gender) => ReportsRepository().getThisWeek(gender: gender),
  retry: (retryCount, error) => null,
);

/// What one class taught in each of the last eight weeks (#615).
final classAlignmentProvider = FutureProvider.autoDispose
    .family<ClassAlignment, int>(
      (ref, classId) => ReportsRepository().getClassAlignment(classId),
      retry: (retryCount, error) => null,
    );

/// The people waiting to be placed, for a gender; null for the server's default.
final registrationsProvider = FutureProvider.autoDispose
    .family<UnplacedRegistrations, int?>(
      (ref, gender) => ReportsRepository().getRegistrations(gender: gender),
      retry: (retryCount, error) => null,
    );

/// The classes a waiting registration could be placed in, by registration id.
final registrationClassesProvider = FutureProvider.autoDispose
    .family<List<PlacementClass>, int>(
      (ref, registrationId) =>
          ReportsRepository().getRegistrationClasses(registrationId),
      retry: (retryCount, error) => null,
    );

/// Places a waiting registrant in a class (registration id, class id).
typedef PlaceRegistrant =
    Future<void> Function(int registrationId, int classId);

final placeRegistrantProvider = Provider<PlaceRegistrant>(
  (ref) =>
      (registrationId, classId) =>
          ReportsRepository().placeRegistrant(registrationId, classId),
);

/// Rejects a waiting registrant with a reason (registration id, reason).
typedef RejectRegistrant =
    Future<void> Function(int registrationId, String reason);

final rejectRegistrantProvider = Provider<RejectRegistrant>(
  (ref) =>
      (registrationId, reason) =>
          ReportsRepository().rejectRegistrant(registrationId, reason),
);

/// As [ShareActiveTeachers], for the waiting registrations of a gender.
typedef ShareRegistrations =
    Future<void> Function(int? gender, ReportFormat format);

final shareRegistrationsProvider = Provider<ShareRegistrations>(
  (ref) => (gender, format) async {
    final bytes = await ReportsRepository().downloadRegistrations(
      format: format.name,
      gender: gender,
    );
    await shareBytes(bytes, 'Registrations.${format.name}');
  },
);

/// As [shareRegistrationsProvider], for the registrations already placed in a
/// class (#637).
final shareAllocatedRegistrationsProvider = Provider<ShareRegistrations>(
  (ref) => (gender, format) async {
    final bytes = await ReportsRepository().downloadAllocatedRegistrations(
      format: format.name,
      gender: gender,
    );
    await shareBytes(bytes, 'Registrations-placed.${format.name}');
  },
);

/// What the leaderboard screen asks for; `YYYY-MM-DD` dates, null for the
/// server's default (the last year), [level] a level name, null for all,
/// [minimum] the fewest recitations in the period a member needs to be listed.
typedef QuranLeaderboardQuery = ({
  int? gender,
  String? from,
  String? to,
  String? level,
  int minimum,
});

final quranLeaderboardProvider = FutureProvider.autoDispose
    .family<QuranLeaderboard, QuranLeaderboardQuery>(
      (ref, query) => ReportsRepository().getQuranLeaderboard(
        gender: query.gender,
        from: query.from,
        to: query.to,
        level: query.level,
        minimum: query.minimum,
      ),
      retry: (retryCount, error) => null,
    );

/// As [ShareActiveTeachers], for the leaderboard of a period.
typedef ShareQuranLeaderboard =
    Future<void> Function(QuranLeaderboardQuery query, ReportFormat format);

final shareQuranLeaderboardProvider = Provider<ShareQuranLeaderboard>(
  (ref) => (query, format) async {
    final bytes = await ReportsRepository().downloadQuranLeaderboard(
      format: format.name,
      gender: query.gender,
      from: query.from,
      to: query.to,
      level: query.level,
      minimum: query.minimum,
    );
    await shareBytes(bytes, 'Quran-leaderboard.${format.name}');
  },
);

/// The active teachers for a gender; null for the server's default.
final activeTeachersReportProvider = FutureProvider.autoDispose
    .family<ActiveTeachersReport, int?>(
      (ref, gender) => ReportsRepository().getActiveTeachers(gender: gender),
      retry: (retryCount, error) => null,
    );

/// As [ShareClassSessions], for the active teachers of a gender.
typedef ShareActiveTeachers =
    Future<void> Function(int gender, ReportFormat format);

final shareActiveTeachersProvider = Provider<ShareActiveTeachers>(
  (ref) => (gender, format) async {
    final bytes = await ReportsRepository().downloadActiveTeachers(
      format: format.name,
      gender: gender,
    );
    await shareBytes(bytes, 'Active-teachers-$gender.${format.name}');
  },
);
