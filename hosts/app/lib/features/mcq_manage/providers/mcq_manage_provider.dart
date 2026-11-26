import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/utils/share_bytes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

import '../models/mcq_manage.dart';
import '../models/mcq_offline.dart';
import '../repositories/mcq_manage_repository.dart';
import '../repositories/offline_answers_store.dart';

/// Single shared repository instance.
final mcqManageRepositoryProvider = Provider<McqManageRepository>(
  (ref) => McqManageRepository(),
);

/// Paginated management list for a class.
final mcqManageListProvider = FutureProvider.autoDispose
    .family<McqManageListResponse, int>((ref, classId) async {
      final repository = ref.watch(mcqManageRepositoryProvider);
      return repository.getManageQuizzes(classId);
    });

/// The copy picker's classes, topics of a class, and quizzes of a class topic.
final mcqCopyClassesProvider = FutureProvider.autoDispose<List<McqCopyClass>>(
  (ref) => ref.watch(mcqManageRepositoryProvider).getCopyClasses(),
);

final mcqCopyTopicsProvider = FutureProvider.autoDispose
    .family<List<String>, int>(
      (ref, classId) =>
          ref.watch(mcqManageRepositoryProvider).getCopyTopics(classId),
    );

final mcqCopyQuizzesProvider = FutureProvider.autoDispose
    .family<List<McqCopyQuiz>, ({int classId, String topic})>(
      (ref, key) => ref
          .watch(mcqManageRepositoryProvider)
          .getCopyQuizzes(key.classId, key.topic),
    );

/// Full quiz detail (with questions) for editing.
final mcqManageDetailProvider = FutureProvider.autoDispose
    .family<McqManageDetail, int>((ref, quizId) async {
      final repository = ref.watch(mcqManageRepositoryProvider);
      return repository.getQuizDetail(quizId);
    });

/// Per-student scores for a quiz.
final mcqScoresProvider = FutureProvider.autoDispose
    .family<McqScoresResponse, int>((ref, quizId) async {
      final repository = ref.watch(mcqManageRepositoryProvider);
      return repository.getQuizScores(quizId);
    });

/// Distinct topics already used by a class.
final mcqTopicsProvider = FutureProvider.autoDispose.family<List<String>, int>((
  ref,
  classId,
) async {
  final repository = ref.watch(mcqManageRepositoryProvider);
  return repository.getTopics(classId);
});

/// Standard MCQs available for a class, grouped by topic/subject.
final mcqStandardProvider = FutureProvider.autoDispose
    .family<McqStandardResponse, int>((ref, classId) async {
      final repository = ref.watch(mcqManageRepositoryProvider);
      return repository.getStandardQuizzes(classId);
    });

/// Questions and students for recording a quiz's offline answers (#409).
final mcqOfflineProvider = FutureProvider.autoDispose
    .family<McqOfflineData, int>((ref, quizId) {
      return ref.watch(mcqManageRepositoryProvider).getOffline(quizId);
    });

/// The on-device pending answers of the signed-in teacher.
final offlineAnswersStoreProvider = Provider<OfflineAnswersStore>((ref) {
  final token = ref.watch(currentUserProvider)?.token ?? 0;
  return OfflineAnswersStore(Hive.box(AppConstants.offlineBoxKey), token);
});

/// What a submit came to. Exactly one of the three is set.
class OfflineSubmitResult {
  final int saved;
  final List<int> conflicts;
  final String? error;

  const OfflineSubmitResult({
    this.saved = 0,
    this.conflicts = const [],
    this.error,
  });
}

/// A quiz's pending offline answers: what is on the device, and sending it.
class OfflinePendingNotifier extends StateNotifier<Map<int, Set<int>>> {
  final int quizId;
  final OfflineAnswersStore _store;
  final McqManageRepository _repository;

  OfflinePendingNotifier(this.quizId, this._store, this._repository)
    : super(_store.pending(quizId));

  /// Records every chosen student, answered or not: an unmarked question is
  /// an incorrect one.
  Future<void> record(Map<int, Set<int>> correctByToken) async {
    for (final e in correctByToken.entries) {
      await _store.put(quizId, e.key, e.value);
    }
    state = _store.pending(quizId);
  }

  /// Sends everything pending. On any failure every answer stays on the
  /// device. On a 409 only the students who had already submitted are dropped.
  Future<OfflineSubmitResult> submit() async {
    final batch = state;
    try {
      await _repository.saveOffline(quizId, batch);
      await _store.remove(quizId, batch.keys);
      state = _store.pending(quizId);
      return OfflineSubmitResult(saved: batch.length);
    } on ApiException catch (e) {
      final conflicts = e.statusCode == 409
          ? [
              for (final t in (e.body?['conflicts'] as List<dynamic>? ?? []))
                t as int,
            ]
          : <int>[];
      if (conflicts.isNotEmpty) {
        await _store.remove(quizId, conflicts);
        state = _store.pending(quizId);
        return OfflineSubmitResult(conflicts: conflicts);
      }
      return OfflineSubmitResult(error: e.message);
    } catch (_) {
      return const OfflineSubmitResult(error: 'Could not reach the server.');
    }
  }
}

final offlinePendingProvider = StateNotifierProvider.autoDispose
    .family<OfflinePendingNotifier, Map<int, Set<int>>, int>((ref, quizId) {
      return OfflinePendingNotifier(
        quizId,
        ref.watch(offlineAnswersStoreProvider),
        ref.watch(mcqManageRepositoryProvider),
      );
    });

/// Fetches the question sheet and hands it to the share sheet. A provider so a
/// test can stand in for the network and the sheet.
typedef ShareMcqSheet = Future<void> Function(int quizId, String name);

final shareMcqSheetProvider = Provider<ShareMcqSheet>(
  (ref) => (quizId, name) async {
    final bytes = await ref
        .read(mcqManageRepositoryProvider)
        .downloadSheet(quizId);
    await shareBytes(bytes, 'MCQ_$quizId.pdf', subject: name);
  },
);
