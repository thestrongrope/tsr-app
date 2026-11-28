import 'dart:convert';

import 'package:hive_ce/hive.dart';

/// Answers a teacher has recorded for one MCQ and not yet submitted (#409).
///
/// Kept in a Hive box so they survive closing the app. A teacher's token is in
/// the key, as the web page keys its `localStorage` entry, so a second teacher
/// on the same phone sees their own list. Per student: the ids of the questions
/// they answered correctly; every other question is incorrect.
class OfflineAnswersStore {
  final Box _box;
  final int _teacherToken;

  OfflineAnswersStore(this._box, this._teacherToken);

  String _key(int quizId) => 'offline_mcq_${quizId}_$_teacherToken';

  Map<int, Set<int>> pending(int quizId) {
    final raw = _box.get(_key(quizId));
    if (raw is! String) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in decoded.entries)
        int.parse(e.key): {
          for (final id in e.value as List<dynamic>) id as int,
        },
    };
  }

  int count(int quizId) => pending(quizId).length;

  /// Records (or re-records) one student's correct questions.
  Future<void> put(int quizId, int studentToken, Set<int> correct) {
    final all = pending(quizId)..[studentToken] = correct;
    return _write(quizId, all);
  }

  /// Drops students whose answers were submitted, or refused as already there.
  Future<void> remove(int quizId, Iterable<int> studentTokens) {
    final all = pending(quizId)
      ..removeWhere((token, _) => studentTokens.contains(token));
    return _write(quizId, all);
  }

  Future<void> _write(int quizId, Map<int, Set<int>> all) {
    if (all.isEmpty) return _box.delete(_key(quizId));
    return _box.put(
      _key(quizId),
      jsonEncode({
        for (final e in all.entries) '${e.key}': (e.value.toList()..sort()),
      }),
    );
  }
}
