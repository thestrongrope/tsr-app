import 'package:flutter/foundation.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/network/api_client.dart';
import '../models/class_manage.dart';
import '../repositories/class_manage_repository.dart';
import 'class_manage_provider.dart';
import 'classes_provider.dart';
import '../../../core/utils/user_message.dart';

class ClassScheduleState {
  final bool isLoading;
  final bool isSaving;

  /// What the server has.
  final List<ManageSchedule> saved;

  /// What the screen is editing; starts equal to [saved].
  final List<ManageSchedule> draft;
  final List<ManageTimezone> timezones;
  final String? error;

  const ClassScheduleState({
    this.isLoading = false,
    this.isSaving = false,
    this.saved = const [],
    this.draft = const [],
    this.timezones = const [],
    this.error,
  });

  bool get isDirty => !listEquals(saved, draft);

  ClassScheduleState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<ManageSchedule>? draft,
  }) {
    return ClassScheduleState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      saved: saved,
      draft: draft ?? this.draft,
      timezones: timezones,
      error: error,
    );
  }
}

/// State of one class's schedule screen (#629): the teacher's and MCQ admin's
/// way to correct the day and time their reminders are built from.
class ClassScheduleNotifier extends StateNotifier<ClassScheduleState> {
  final int classId;
  final ClassManageRepository _repository;

  /// Called after a save, so the class list (and with it the local reminders)
  /// follow the new schedule.
  final VoidCallback _onSaved;

  ClassScheduleNotifier(this.classId, this._repository, this._onSaved)
    : super(const ClassScheduleState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = const ClassScheduleState(isLoading: true);
    try {
      _apply(await _repository.getSchedule(classId));
    } on ApiException catch (e) {
      state = ClassScheduleState(error: e.message);
    } catch (e) {
      state = ClassScheduleState(error: 'Could not load: ${userMessage(e)}');
    }
  }

  void edit(List<ManageSchedule> draft) {
    state = state.copyWith(draft: draft);
  }

  Future<void> save() async {
    if (state.isSaving) return;
    state = state.copyWith(isSaving: true);
    try {
      _apply(await _repository.saveSchedule(classId, state.draft));
      _onSaved();
    } catch (_) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  void _apply(ClassScheduleData data) {
    state = ClassScheduleState(
      saved: data.schedules,
      draft: data.schedules,
      timezones: data.timezones,
    );
  }
}

final classScheduleProvider = StateNotifierProvider.autoDispose
    .family<ClassScheduleNotifier, ClassScheduleState, int>((ref, classId) {
      return ClassScheduleNotifier(
        classId,
        ref.watch(classManageRepositoryProvider),
        () => ref.read(classesProvider.notifier).refresh(),
      );
    });
