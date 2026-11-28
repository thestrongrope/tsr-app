import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/services/local_data_cleaner.dart';

/// Sign-out must leave nothing of member A on the device for member B.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_cleaner_test');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.cacheBoxKey);
    await Hive.openBox('classes_cache');
    await Hive.openBox(AppConstants.offlineBoxKey);
    await Hive.openBox(AppConstants.bookmarksBoxKey);
    await Hive.openBox(AppConstants.settingsBoxKey);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('clears every per-user store and keeps non-user data', () async {
    final cache = Hive.box(AppConstants.cacheBoxKey);
    await cache.put('grand_quiz_info_u_123', {'a': 1});
    await cache.put('grand_quiz_info_auth', {'a': 1});
    await cache.put('grand_quiz_info_guest', {'a': 1});
    await cache.put('tsr_categories', 'public content');
    await cache.put('permissions_json_v4', 'remembered');
    await cache.put('notifications_inbox_123', 'saved copy');
    await cache.put('notifications_inbox_456', 'saved copy');
    await Hive.box('classes_cache').put('user_classes', 'saved copy');
    await Hive.box(AppConstants.offlineBoxKey).put('k', 'v');
    await Hive.box(AppConstants.bookmarksBoxKey).add('bookmark');
    await Hive.box(AppConstants.settingsBoxKey).put('theme', 'dark');
    await Hive.box(AppConstants.settingsBoxKey).put('recent_actions:7', ['x']);

    await clearPerUserLocalData();

    expect(
      cache.keys.where((k) => '$k'.startsWith('grand_quiz_info')),
      isEmpty,
    );
    expect(
      cache.keys.where((k) => '$k'.startsWith('notifications_inbox_')),
      isEmpty,
    );
    expect(cache.get('permissions_json_v4'), isNull);
    expect(Hive.box('classes_cache').isEmpty, isTrue);
    expect(Hive.box(AppConstants.offlineBoxKey).isEmpty, isTrue);
    expect(Hive.box(AppConstants.bookmarksBoxKey).isEmpty, isTrue);
    expect(cache.get('tsr_categories'), 'public content');
    expect(Hive.box(AppConstants.settingsBoxKey).get('theme'), 'dark');
    expect(
      Hive.box(AppConstants.settingsBoxKey).get('recent_actions:7'),
      isNull,
    );
  });

  test('does not throw when a box is not open', () async {
    await Hive.box(AppConstants.offlineBoxKey).close();
    await clearPerUserLocalData();
  });

  test('reports the steps that failed and still runs the rest', () async {
    await Hive.box(AppConstants.offlineBoxKey).close();
    await Hive.box(AppConstants.bookmarksBoxKey).add('bookmark');
    await Hive.box(AppConstants.settingsBoxKey).put('recent_actions:7', ['x']);

    final failed = await clearPerUserLocalData();

    expect(failed, ['offline box']);
    expect(Hive.box(AppConstants.bookmarksBoxKey).isEmpty, isTrue);
    expect(
      Hive.box(AppConstants.settingsBoxKey).get('recent_actions:7'),
      isNull,
    );
  });

  test('reports nothing when every step succeeds', () async {
    expect(await clearPerUserLocalData(), isEmpty);
  });
}
