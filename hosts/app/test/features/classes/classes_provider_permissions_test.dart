import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';

class _CountingRepository extends ClassesRepository {
  int loads = 0;
  bool? lastAllowSaved;

  @override
  Future<List<ClassModel>> getEnrolledClasses({bool allowSaved = true}) async {
    loads++;
    lastAllowSaved = allowSaved;
    return const [];
  }
}

Map<String, dynamic> _body({required List<int> enrolled}) => {
  'version': 4,
  'issued_at': '2026-10-05T08:00:00.000000+00:00',
  'permissions': ['classes:read:enrolled'],
  'scopes': {
    'gender': null,
    'assigned': <int>[],
    'assigned_genders': <int>[],
    'own': <int>[],
    'taught': <int>[],
    'enrolled': enrolled,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('classes_provider_test');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.cacheBoxKey);
    await Hive.openBox(AppConstants.settingsBoxKey);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  ProviderContainer containerWith(
    _CountingRepository repository,
    Map<String, dynamic> permissionsBody,
  ) {
    final container = ProviderContainer(
      overrides: [
        classesRepositoryProvider.overrideWithValue(repository),
        permissionsProvider.overrideWith(
          (ref) => PermissionsNotifier(
            owner: () =>
                1, // someone is signed in; nothing is fetched for a guest
            fetch: ({ifNoneMatch}) async => permissionsBody,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'loads the classes when the permissions arrive saying enrolled',
    () async {
      final repository = _CountingRepository();
      final container = containerWith(repository, _body(enrolled: [412]));
      container.read(classesProvider); // alive, as on the home screen
      await container
          .read(permissionsProvider.notifier)
          .init(); // member default
      expect(repository.loads, 0);

      await container.read(permissionsProvider.notifier).fetchAndSave();

      await Future<void>.delayed(
        const Duration(milliseconds: 50),
      ); // the load is not awaited
      expect(repository.loads, 1);
      expect(container.read(classesProvider).classes, isNotNull);
    },
  );

  test(
    'a pull-down asks the server only; the automatic load may use the saved list',
    () async {
      final repository = _CountingRepository();
      final container = containerWith(repository, _body(enrolled: [412]));
      final notifier = container.read(classesProvider.notifier);

      await notifier.loadClasses();
      expect(repository.lastAllowSaved, isTrue);

      await notifier.refresh();
      expect(repository.lastAllowSaved, isFalse);
    },
  );

  test('does not load the classes for a user who is not enrolled', () async {
    final repository = _CountingRepository();
    final container = containerWith(repository, _body(enrolled: []));
    container.read(classesProvider);
    await container.read(permissionsProvider.notifier).init();

    await container.read(permissionsProvider.notifier).fetchAndSave();

    expect(repository.loads, 0);
  });
}
