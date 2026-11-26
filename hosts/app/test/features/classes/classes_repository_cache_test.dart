import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/services/saved_copy.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';

/// A repository whose server is whatever the test says it is.
class _ScriptedRepository extends ClassesRepository {
  _ScriptedRepository({super.clock, super.owner});

  Object? next;
  Object? nextPerformance;
  Object? nextFormData;

  @override
  Future<Map<String, dynamic>> fetchConductionFormJson(int classId) async {
    final result = nextFormData;
    if (result is ApiException) throw result;
    return result as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> fetchPerformanceJson(
    int classId,
    Map<String, dynamic> queryParams,
  ) async {
    final result = nextPerformance;
    if (result is ApiException) throw result;
    return result as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClassJson() async {
    final result = next;
    if (result is ApiException) throw result;
    return result as List<Map<String, dynamic>>;
  }
}

List<Map<String, dynamic>> _classes(String teacher) => [
  {
    'id': 10,
    'code': 'ML18',
    'name': 'Class 10',
    'level': 1,
    'gender': 2,
    'status': 'A',
    'role': 'attending',
    'teacherName': teacher,
  },
];

void main() {
  late Directory dir;
  late _ScriptedRepository repository;
  var now = DateTime.utc(2026, 10, 1, 12);
  var member = 7;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('classes_repository_cache');
    Hive.init(dir.path);
    now = DateTime.utc(2026, 10, 1, 12);
    member = 7;
    repository = _ScriptedRepository(clock: () => now, owner: () => member);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('a teacher changed on the web shows on the next load', () async {
    repository.next = _classes('Abbas');
    expect((await repository.getEnrolledClasses()).single.teacherName, 'Abbas');

    repository.next = _classes('Shabana');
    expect(
      (await repository.getEnrolledClasses()).single.teacherName,
      'Shabana',
    );
  });

  for (final unreachable in {
    'no connection': const ApiException('offline', 0),
    'a timeout': const ApiException('slow', 408),
    'a server error': const ApiException('down', 503),
  }.entries) {
    test('${unreachable.key}: the last saved list is shown', () async {
      repository.next = _classes('Abbas');
      await repository.getEnrolledClasses();

      repository.next = unreachable.value;
      expect(
        (await repository.getEnrolledClasses()).single.teacherName,
        'Abbas',
      );
    });
  }

  for (final refusal in {
    'unauthorised': const ApiException('no', 401),
    'forbidden': const ApiException('no', 403),
    'not found': const ApiException('no', 404),
  }.entries) {
    test('${refusal.key}: an old list is not shown in its place', () async {
      repository.next = _classes('Abbas');
      await repository.getEnrolledClasses();

      repository.next = refusal.value;
      expect(repository.getEnrolledClasses(), throwsA(isA<ApiException>()));
    });
  }

  test(
    'a refresh that cannot reach the server is an error, not the saved list',
    () async {
      repository.next = _classes('Abbas');
      await repository.getEnrolledClasses();

      repository.next = const ApiException('offline', 0);
      expect(
        repository.getEnrolledClasses(allowSaved: false),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'unreachable with nothing saved is an error, not an empty list',
    () async {
      repository.next = const ApiException('offline', 0);
      expect(repository.getEnrolledClasses(), throwsA(isA<ApiException>()));
    },
  );

  test(
    'the saved list can still be read after the app is closed and reopened',
    () async {
      // Hive hands nested maps back as Map<dynamic, dynamic> once the box is
      // reopened from disk, which a cast to Map<String, dynamic> rejects. A class
      // with a schedule is the case that has a nested map.
      repository.next = [
        {
          ..._classes('Abbas').single,
          'schedules': [
            {'day': 4, 'hour': 21, 'minute': 0, 'timezone': 'Asia/Kolkata'},
          ],
        },
      ];
      await repository.getEnrolledClasses();

      await Hive.close();
      Hive.init(dir.path);

      repository.next = const ApiException('offline', 0);
      final classes = await repository.getEnrolledClasses();

      expect(classes.single.teacherName, 'Abbas');
      expect(classes.single.schedules.single.hour, 21);
      expect(classes.single.schedules.single.timezone, 'Asia/Kolkata');
    },
  );

  group('the saved class list expires', () {
    test('just under 7 days old, it is shown', () async {
      repository.next = _classes('Abbas');
      await repository.getEnrolledClasses();

      now = now.add(savedCopyMaxAge - const Duration(minutes: 1));
      repository.next = const ApiException('offline', 0);
      expect(
        (await repository.getEnrolledClasses()).single.teacherName,
        'Abbas',
      );
    });

    test('just over 7 days old, it is an error with nothing shown', () async {
      repository.next = _classes('Abbas');
      await repository.getEnrolledClasses();

      now = now.add(savedCopyMaxAge + const Duration(minutes: 1));
      repository.next = const ApiException('offline', 0);
      expect(repository.getEnrolledClasses(), throwsA(isA<ApiException>()));
    });
  });

  group('class performance', () {
    const figures = {
      'totalSessions': 10,
      'attendedSessions': 8,
      'attendancePercent': 80.0,
      'totalRecitation': 3,
      'averageRecitation': 1.5,
      'quizzesAttempted': 2,
      'quizAverageScore': 70.0,
    };

    test('fresh figures are shown while the server answers', () async {
      repository.nextPerformance = figures;
      await repository.getClassPerformance(10);

      repository.nextPerformance = {...figures, 'attendedSessions': 9};
      expect((await repository.getClassPerformance(10)).attendedSessions, 9);
    });

    test(
      'unreachable: the saved figures are shown while under 7 days',
      () async {
        repository.nextPerformance = figures;
        await repository.getClassPerformance(10);

        now = now.add(savedCopyMaxAge - const Duration(minutes: 1));
        repository.nextPerformance = const ApiException('down', 503);
        expect((await repository.getClassPerformance(10)).attendedSessions, 8);
      },
    );

    test('unreachable: figures over 7 days old are not shown', () async {
      repository.nextPerformance = figures;
      await repository.getClassPerformance(10);

      now = now.add(savedCopyMaxAge + const Duration(minutes: 1));
      repository.nextPerformance = const ApiException('down', 503);
      expect(repository.getClassPerformance(10), throwsA(isA<ApiException>()));
    });

    test('a refusal does not show the saved figures', () async {
      repository.nextPerformance = figures;
      await repository.getClassPerformance(10);

      repository.nextPerformance = const ApiException('no', 403);
      expect(repository.getClassPerformance(10), throwsA(isA<ApiException>()));
    });
  });

  group('conduction form data', () {
    final formData = {
      'class': {'id': 10, 'code': 'ML18', 'name': 'Class 10'},
      'latestTopics': {'ahkamTopic': 'Taqleed :: Lesson 4'},
      'holyQuran': [
        {'id': 1, 'surah': 'Al-Fatiha', 'arabic': 'x', 'verses': 7},
      ],
    };

    test('unreachable: the form opens from the last saved copy', () async {
      repository.nextFormData = formData;
      await repository.getConductionFormData(10);

      repository.nextFormData = const ApiException('offline', 0);
      final data = await repository.getConductionFormData(10);

      expect(data.classInfo?.code, 'ML18');
      expect(data.latestTopics['ahkam'], 'Taqleed :: Lesson 4');
      expect(data.holyQuran.single.surah, 'Al-Fatiha');
    });

    test('unreachable with no saved copy: the error is shown', () async {
      repository.nextFormData = const ApiException('offline', 0);
      expect(
        repository.getConductionFormData(10),
        throwsA(isA<ApiException>()),
      );
    });

    test('a refusal does not open the saved copy', () async {
      repository.nextFormData = formData;
      await repository.getConductionFormData(10);

      repository.nextFormData = const ApiException('no', 403);
      expect(
        repository.getConductionFormData(10),
        throwsA(isA<ApiException>()),
      );
    });

    test('a copy is kept per class', () async {
      repository.nextFormData = formData;
      await repository.getConductionFormData(10);

      repository.nextFormData = const ApiException('offline', 0);
      expect(
        repository.getConductionFormData(11),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('saved copies belong to the signed-in member (#761)', () {
    Future<void> saveAsFirstMember() async {
      repository.next = _classes('Abbas');
      repository.nextPerformance = {
        'totalSessions': 10,
        'attendedSessions': 8,
        'attendancePercent': 80.0,
        'totalRecitation': 3,
        'averageRecitation': 1.5,
        'quizzesAttempted': 2,
        'quizAverageScore': 70.0,
      };
      repository.nextFormData = {
        'class': {'id': 10},
      };
      await repository.getEnrolledClasses();
      await repository.getClassPerformance(10);
      await repository.getConductionFormData(10);
    }

    test(
      'another member offline sees no class list, performance or form',
      () async {
        await saveAsFirstMember();

        member = 8;
        repository.next = const ApiException('offline', 0);
        repository.nextPerformance = const ApiException('offline', 0);
        repository.nextFormData = const ApiException('offline', 0);
        await expectLater(
          repository.getEnrolledClasses(),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          repository.getClassPerformance(10),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          repository.getConductionFormData(10),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test('the same member offline still sees their copy', () async {
      await saveAsFirstMember();

      repository.next = const ApiException('offline', 0);
      expect(
        (await repository.getEnrolledClasses()).single.teacherName,
        'Abbas',
      );
    });

    test('a copy with no owner is not shown', () async {
      final box = await Hive.openBox('classes_cache');
      await box.put('user_classes', {
        'savedAt': now.toIso8601String(),
        'data': '[]',
      });

      repository.next = const ApiException('offline', 0);
      await expectLater(
        repository.getEnrolledClasses(),
        throwsA(isA<ApiException>()),
      );
    });

    test('nobody signed in: nothing is shown', () async {
      await saveAsFirstMember();

      final guest = _ScriptedRepository(clock: () => now, owner: () => null)
        ..next = const ApiException('offline', 0);
      await expectLater(
        guest.getEnrolledClasses(),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
