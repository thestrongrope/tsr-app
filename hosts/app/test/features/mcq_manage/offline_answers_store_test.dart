import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/features/mcq_manage/models/mcq_offline.dart';
import 'package:the_strong_rope/features/mcq_manage/repositories/offline_answers_store.dart';

void main() {
  late Directory dir;
  late Box box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('offline_store');
    Hive.init(dir.path);
    box = await Hive.openBox('offline_test');
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('offline_test');
    await dir.delete(recursive: true);
  });

  test('starts empty', () {
    final store = OfflineAnswersStore(box, 9);
    expect(store.pending(10), isEmpty);
    expect(store.count(10), 0);
  });

  test('keeps what was recorded, per student, and counts students', () async {
    final store = OfflineAnswersStore(box, 9);
    await store.put(10, 101, {7, 8});
    await store.put(10, 102, <int>{});

    expect(store.pending(10), {
      101: {7, 8},
      102: <int>{},
    });
    expect(store.count(10), 2);
  });

  test(
    'survives the app closing: a new store over the same box reads it',
    () async {
      await OfflineAnswersStore(box, 9).put(10, 101, {7});
      await box.close();
      final reopened = await Hive.openBox('offline_test');

      expect(OfflineAnswersStore(reopened, 9).pending(10), {
        101: {7},
      });
    },
  );

  test(
    're-recording a student replaces their answers, not adds a second',
    () async {
      final store = OfflineAnswersStore(box, 9);
      await store.put(10, 101, {7});
      await store.put(10, 101, {8});

      expect(store.pending(10), {
        101: {8},
      });
    },
  );

  test(
    'removing some leaves the rest; removing all leaves nothing stored',
    () async {
      final store = OfflineAnswersStore(box, 9);
      await store.put(10, 101, {7});
      await store.put(10, 102, {7});
      await store.remove(10, [101]);
      expect(store.pending(10).keys, [102]);

      await store.remove(10, [102]);
      expect(store.count(10), 0);
      expect(box.keys, isEmpty);
    },
  );

  test('another teacher or another MCQ has its own list', () async {
    await OfflineAnswersStore(box, 9).put(10, 101, {7});

    expect(OfflineAnswersStore(box, 8).count(10), 0);
    expect(OfflineAnswersStore(box, 9).count(11), 0);
  });

  test('parses the offline payload', () {
    final data = McqOfflineData.fromJson({
      'quiz': {'id': 10, 'name': 'Wudu', 'topic': null},
      'questions': [
        {
          'id': 7,
          'question': 'Which water?',
          'options': [
            {'text': 'Najis', 'isCorrect': false},
            {'text': 'Pure', 'isCorrect': true},
          ],
        },
      ],
      'students': [
        {'token': 101, 'name': 'Ali', 'isOffline': true, 'submitted': false},
      ],
    });

    expect(data.quizName, 'Wudu');
    expect(data.topic, isNull);
    expect(data.questions.single.options.last.isCorrect, isTrue);
    expect(data.students.single.isOffline, isTrue);
    expect(data.students.single.submitted, isFalse);
  });
}
