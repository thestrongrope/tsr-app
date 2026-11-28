import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/network/api_client.dart';
import '../models/bulk_add.dart';
import '../models/class_manage.dart';
import '../repositories/class_manage_repository.dart';
import 'classes_provider.dart';
import '../../../core/utils/user_message.dart';

final classManageRepositoryProvider = Provider<ClassManageRepository>((ref) {
  return ClassManageRepository();
});

class ClassManageState {
  final bool isLoading;
  final bool isSaving;
  final ClassManagePayload? payload;

  /// What the Details and Schedule tabs are editing; starts equal to the server.
  final ClassDraft? draft;
  final String? error;

  const ClassManageState({
    this.isLoading = false,
    this.isSaving = false,
    this.payload,
    this.draft,
    this.error,
  });

  /// Unsaved edits on the Details or Schedule tab.
  bool get isDirty {
    final p = payload;
    final d = draft;
    return p != null && d != null && d != ClassDraft.from(p);
  }

  ClassManageState copyWith({
    bool? isLoading,
    bool? isSaving,
    ClassManagePayload? payload,
    ClassDraft? draft,
    String? error,
    bool clearError = false,
  }) {
    return ClassManageState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      payload: payload ?? this.payload,
      draft: draft ?? this.draft,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// State of one class's manage screen. Every method either succeeds and
/// updates the state, or throws an [ApiException] for the screen to show.
class ClassManageNotifier extends StateNotifier<ClassManageState> {
  final int classId;
  final ClassManageRepository _repository;

  /// Called after a save changed the class, so the class list (and with it the
  /// local reminders) follow the new schedule.
  final VoidCallback _onClassChanged;

  ClassManageNotifier(this.classId, this._repository, this._onClassChanged)
    : super(const ClassManageState(isLoading: true)) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final payload = await _repository.getManage(classId);
      state = ClassManageState(
        payload: payload,
        draft: ClassDraft.from(payload),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: userMessage(e));
    }
  }

  void editDraft(ClassDraft Function(ClassDraft draft) change) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: change(draft));
  }

  void discardEdits() {
    final payload = state.payload;
    if (payload == null) return;
    state = state.copyWith(draft: ClassDraft.from(payload));
  }

  Future<void> save() async {
    final draft = state.draft;
    if (draft == null || state.isSaving) return;
    state = state.copyWith(isSaving: true);
    try {
      final payload = await _repository.save(classId, draft);
      state = ClassManageState(
        payload: payload,
        draft: ClassDraft.from(payload),
      );
      _onClassChanged();
    } catch (_) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  Future<List<ManageOption>> searchTeachers(String query) =>
      _repository.searchTeachers(classId, query);

  Future<void> updateStudent(
    int token, {
    required String name,
    required String email,
    required String mobile,
    required String notes,
  }) => _applyRoster(
    _repository.updateStudent(
      classId,
      token,
      name: name,
      email: email,
      mobile: mobile,
      notes: notes,
    ),
  );

  Future<void> addStudent(int token) =>
      _applyRoster(_repository.addStudent(classId, token));

  /// Enrol a pasted list (#691); keeps the roster the server sent back.
  Future<BulkAddResult> bulkAddStudents(
    List<String> lines,
    Map<int, String> resolutions,
  ) async {
    final result = await _repository.bulkAddStudents(
      classId,
      lines,
      resolutions,
    );
    final payload = state.payload;
    final roster = result.roster;
    if (roster != null && payload != null) {
      state = state.copyWith(payload: payload.copyWith(roster: roster));
    }
    return result;
  }

  Future<void> removeStudent(int token, String reason) =>
      _applyRoster(_repository.removeStudent(classId, token, reason));

  Future<void> restoreStudent(int token) =>
      _applyRoster(_repository.restoreStudent(classId, token));

  Future<void> setClassAdmin(int token, bool status) =>
      _applyRoster(_repository.setClassAdmin(classId, token, status));

  Future<void> transferStudent(
    int token, {
    required int toClassId,
    required String type,
    required String reason,
  }) => _applyRoster(
    _repository.transferStudent(
      classId,
      token,
      toClassId: toClassId,
      type: type,
      reason: reason,
    ),
  );

  Future<LinkPreview> linkPreview(int extraToken, int memberToken) =>
      _repository.linkPreview(extraToken, memberToken);

  /// Link an extra student to a member (#1135), then reload the roster: the
  /// extra student is gone from every class it was in.
  Future<void> linkStudent(
    int extraToken,
    int memberToken,
    List<LinkResolution> resolutions,
  ) async {
    await _repository.linkStudent(extraToken, memberToken, resolutions);
    final payload = state.payload;
    if (payload == null) return;
    try {
      final fresh = await _repository.getManage(classId);
      state = state.copyWith(
        payload: payload.copyWith(roster: fresh.roster, can: fresh.can),
      );
    } catch (e) {
      // The link is done; only the reload failed. Say that, not "link failed".
      state = state.copyWith(error: userMessage(e));
    }
  }

  Future<void> _applyRoster(Future<ManageRoster> request) async {
    final roster = await request;
    final payload = state.payload;
    if (payload == null) return;
    state = state.copyWith(payload: payload.copyWith(roster: roster));
  }
}

final classManageProvider = StateNotifierProvider.autoDispose
    .family<ClassManageNotifier, ClassManageState, int>((ref, classId) {
      return ClassManageNotifier(
        classId,
        ref.watch(classManageRepositoryProvider),
        () => ref.read(classesProvider.notifier).refresh(),
      );
    });

/// A teacher's read-only roster (class-students:read), outside conduction.
final classRosterProvider = FutureProvider.autoDispose
    .family<List<ManagedStudent>, int>((ref, classId) {
      return ref.watch(classManageRepositoryProvider).getTeacherRoster(classId);
    }, retry: (_, _) => null);
