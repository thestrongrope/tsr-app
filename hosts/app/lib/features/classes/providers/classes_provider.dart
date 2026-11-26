import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers/notification_settings_provider.dart';
import '../../../core/models/permissions_payload.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/providers/permissions_provider.dart';
import '../../../core/services/reminder_telemetry.dart';
import '../../../core/services/scheduled_notification_service.dart';
import '../models/models.dart';
import '../repositories/classes_repository.dart';
import '../utils/topic_codec.dart';
import '../../../core/utils/user_message.dart';

// ============ Repository Provider ============

final classesRepositoryProvider = Provider<ClassesRepository>((ref) {
  return ClassesRepository();
});

// ============ Filter Models ============

class ClassPerformanceFilter {
  final int classId;
  final DateTime? startDate;
  final DateTime? endDate;

  const ClassPerformanceFilter({
    required this.classId,
    this.startDate,
    this.endDate,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClassPerformanceFilter &&
        other.classId == classId &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(classId, startDate, endDate);
}

// ============ Classes List Provider ============

class ClassesState {
  final bool isLoading;
  final List<ClassModel>? classes;
  final String? error;

  const ClassesState({this.isLoading = false, this.classes, this.error});

  ClassesState copyWith({
    bool? isLoading,
    List<ClassModel>? classes,
    String? error,
  }) {
    return ClassesState(
      isLoading: isLoading ?? this.isLoading,
      classes: classes ?? this.classes,
      error: error,
    );
  }

  bool get hasClasses => classes != null && classes!.isNotEmpty;
  int get classCount => classes?.length ?? 0;
}

/// Does the user get the weekly conduction reminder for [cls]?
/// No permissions yet means no reminder.
bool remindsConductionFor(Capabilities capabilities, ClassModel cls) =>
    capabilities.remindsConduction(classId: cls.id);

class ClassesNotifier extends StateNotifier<ClassesState> {
  final ClassesRepository _repository;
  final Ref _ref;

  ClassesNotifier(this._repository, this._ref) : super(const ClassesState()) {
    // The permissions can arrive after the screen that needs the list: the
    // first launch after an upgrade starts with the member default, and the
    // real payload follows. Load the list once it says the user is enrolled,
    // and re-arm the reminders, which depend on both.
    _ref.listen(permissionsProvider, (previous, next) {
      if (previous?.payload == next.payload) return;
      final classes = state.classes;
      if (classes != null) {
        rescheduleNotifications(classes);
      } else if (_capabilities(next.payload).isEnrolled) {
        loadClasses();
      }
    });
  }

  /// Built here, not read from [capabilitiesProvider], which depends on this
  /// provider: reading it from inside would be a circular dependency.
  Capabilities _capabilities(PermissionsPayload? payload) =>
      Capabilities.of(payload: payload, classes: state.classes);

  /// [allowSaved] false (a pull-down) asks the server only: on failure the
  /// list on screen stays as it was and [ClassesState.error] says why.
  Future<void> loadClasses({bool allowSaved = true}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final classes = await _repository.getEnrolledClasses(
        allowSaved: allowSaved,
      );
      state = state.copyWith(isLoading: false, classes: classes);

      // Reschedule local class reminders with the latest schedule data.
      rescheduleNotifications(classes);
    } catch (e) {
      debugPrint('Error loading classes: $e');
      state = state.copyWith(isLoading: false, error: userMessage(e));
    }
  }

  Future<void> refresh() => loadClasses(allowSaved: false);

  void clear() {
    state = const ClassesState();
    // Cancel all scheduled reminders on clear (e.g. logout).
    ScheduledNotificationService.instance.cancelAll();
  }

  /// Schedule or cancel local class/conduction reminders based on user
  /// settings and the latest class list.
  /// Errors are reported to Crashlytics as non-fatals, not just printed (#395).
  Future<void> rescheduleNotifications(List<ClassModel> classes) async {
    try {
      final settings = _ref.read(notificationSettingsProvider);
      final capabilities = _capabilities(
        _ref.read(permissionsProvider).payload,
      );
      final scheduled = await ScheduledNotificationService.instance
          .rescheduleAll(
            classes: classes,
            classReminderEnabled: settings.classReminderEnabled,
            conductionReminderEnabled: settings.conductionReminderEnabled,
            remindsConduction: (cls) => remindsConductionFor(capabilities, cls),
            classReminderLeadMinutes: settings.classReminderLeadMinutes,
            conductionReminderDelayMinutes:
                settings.conductionReminderDelayMinutes,
          );
      await ReminderTelemetry.logScheduled(
        classCount: scheduled.classReminders,
        conductionCount: scheduled.conductionReminders,
      );
    } catch (e, stack) {
      debugPrint('⚠️ Failed to reschedule notifications: $e');
      ReminderTelemetry.recordRescheduleFailure(e, stack);
    }
  }
}

final classesProvider = StateNotifierProvider<ClassesNotifier, ClassesState>((
  ref,
) {
  final repository = ref.watch(classesRepositoryProvider);
  return ClassesNotifier(repository, ref);
});

// ============ Single Class Detail Provider ============

class ClassDetailState {
  final bool isLoading;
  final ClassModel? classModel;
  final String? error;

  const ClassDetailState({this.isLoading = false, this.classModel, this.error});
}

/// Disposed when its screens close, so reopening a class after a failed load
/// fetches again instead of showing the old error.
final classDetailProvider = FutureProvider.autoDispose.family<ClassModel, int>((
  ref,
  classId,
) async {
  final repository = ref.watch(classesRepositoryProvider);
  return repository.getClassDetail(classId);
}, retry: (_, _) => null);

// ============ Class Performance Provider ============

final classPerformanceProvider = FutureProvider.autoDispose
    .family<ClassPerformance, ClassPerformanceFilter>((ref, filter) async {
      final repository = ref.watch(classesRepositoryProvider);
      return repository.getClassPerformance(
        filter.classId,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
    }, retry: (_, _) => null);

// ============ Class Sessions Provider ============

final classSessionsProvider = FutureProvider.family<List<ClassSession>, int>((
  ref,
  classId,
) async {
  final repository = ref.watch(classesRepositoryProvider);
  return repository.getClassSessions(classId);
});

// ============ Class Attendance Provider ============

final classAttendanceProvider = FutureProvider.autoDispose
    .family<List<StudentAttendance>, ClassPerformanceFilter>((
      ref,
      filter,
    ) async {
      final repository = ref.watch(classesRepositoryProvider);
      return repository.getMyAttendance(
        filter.classId,
        startDate: filter.startDate,
        endDate: filter.endDate,
      );
    }, retry: (_, _) => null);

// ============ Selected Class Provider ============

/// Holds the currently selected class ID for the dashboard
final selectedClassIdProvider = StateProvider<int?>((ref) => null);

/// Gets the currently selected class from the classes list
final selectedClassProvider = Provider<ClassModel?>((ref) {
  final selectedId = ref.watch(selectedClassIdProvider);
  final classesState = ref.watch(classesProvider);

  if (selectedId == null || classesState.classes == null) return null;

  try {
    return classesState.classes!.firstWhere((c) => c.id == selectedId);
  } catch (_) {
    return null;
  }
});

// ============ Class Conduction (teacher/admin) ============

/// Paginated conduction records for a class. Disposed when its screens close,
/// so reopening after a failed load fetches again instead of showing the old
/// error; a failed load shows at once with Retry, not after silent retries.
final conductionSessionsProvider = FutureProvider.autoDispose
    .family<ConductionListResponse, int>((ref, classId) async {
      final repository = ref.watch(classesRepositoryProvider);
      return repository.getConductionSessions(classId);
    }, retry: (_, _) => null);

/// Form data (class, students, holy Quran, next dates) for adding a record.
final conductionFormDataProvider = FutureProvider.autoDispose
    .family<ConductionFormData, int>((ref, classId) async {
      final repository = ref.watch(classesRepositoryProvider);
      return repository.getConductionFormData(classId);
    }, retry: (_, _) => null);

/// The syllabus topics offered for a class's level, for the topic dropdowns.
///
/// Empty for a level with no syllabus, and empty when the request fails — the
/// repository does not throw, because either way the form shows the free-text
/// topic field instead of a dropdown.
final syllabusTopicsProvider = FutureProvider.family<SyllabusTopics, int>((
  ref,
  classId,
) async {
  final repository = ref.watch(classesRepositoryProvider);
  return repository.getSyllabusTopics(classId);
});

/// A single conduction record with attendance, for editing.
final conductionSessionProvider = FutureProvider.autoDispose
    .family<ConductionEditData, ({int classId, int sessionId})>((
      ref,
      args,
    ) async {
      final repository = ref.watch(classesRepositoryProvider);
      return repository.getConductionSession(args.classId, args.sessionId);
    }, retry: (_, _) => null);

/// Holy Quran surah list, backing the conduction form's dropdown.
///
/// The add form gets the list inside its form data; the edit form falls back
/// to this when its session payload carries none.
final holyQuranProvider = FutureProvider<List<HolyQuranSurah>>((ref) async {
  final repository = ref.watch(classesRepositoryProvider);
  return repository.getHolyQuran();
});
