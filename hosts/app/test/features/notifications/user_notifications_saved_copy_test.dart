import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/models/user.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/services/saved_copy.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';

/// Serves what the test says the server says, and a clock the test moves.
class _ScriptedNotifier extends UserNotificationsNotifier {
  _ScriptedNotifier(this.server, DateTime Function() now) {
    clock = now;
  }

  final List<Object> server;
  final List<int> asked = [];

  @override
  Future<void> fetchUnreadCount() async {}

  @override
  Future<Map<String, dynamic>> fetchPage(int offset) async {
    asked.add(offset);
    final result = server.removeAt(0);
    if (result is ApiException) throw result;
    return result as Map<String, dynamic>;
  }
}

Map<String, dynamic> _page(List<String> titles, {int total = 0}) => {
  'notifications': [
    for (var i = 0; i < titles.length; i++)
      {
        'id': i + 1,
        'title': titles[i],
        'body': 'Invented body',
        'sentAt': '2026-10-20T10:00:00',
        'isRead': false,
      },
  ],
  'total': total == 0 ? titles.length : total,
  'unread_count': titles.length,
};

User _member(int token) => User(
  id: token,
  token: token,
  email: 'a@example.test',
  name: 'A',
  roleId: 1,
);

void main() {
  late Directory dir;
  var now = DateTime.utc(2026, 10, 1, 12);
  const offline = ApiException('offline', 0);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('inbox_saved_copy');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.cacheBoxKey);
    now = DateTime.utc(2026, 10, 1, 12);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  /// A container signed in as [token], served by [server].
  ({ProviderContainer container, _ScriptedNotifier notifier}) open(
    int token,
    List<Object> server,
  ) {
    final notifier = _ScriptedNotifier(server, () => now);
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(_member(token)),
        userNotificationsProvider.overrideWith(() => notifier),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, notifier: notifier);
  }

  UserNotificationsState stateOf(ProviderContainer c) =>
      c.read(userNotificationsProvider);

  Future<void> load(ProviderContainer c, {bool refresh = false}) => c
      .read(userNotificationsProvider.notifier)
      .fetchNotifications(refresh: refresh);

  test('a working network shows fresh data, not a saved copy', () async {
    final s = open(7, [
      _page(['one']),
      _page(['two']),
    ]);
    await load(s.container);
    await load(s.container, refresh: true);

    expect(stateOf(s.container).notifications.single.title, 'two');
    expect(stateOf(s.container).isSavedCopy, isFalse);
  });

  test('offline: a copy under 7 days old is shown and marked saved', () async {
    final s = open(7, [
      _page(['one']),
      offline,
    ]);
    await load(s.container);

    now = now.add(savedCopyMaxAge - const Duration(minutes: 1));
    await load(s.container, refresh: true);

    expect(stateOf(s.container).notifications.single.title, 'one');
    expect(stateOf(s.container).isSavedCopy, isTrue);
    expect(stateOf(s.container).error, isNull);
    expect(stateOf(s.container).hasMore, isFalse);
  });

  test('offline: a copy over 7 days old is not shown', () async {
    final s = open(7, [
      _page(['one']),
      offline,
    ]);
    await load(s.container);

    now = now.add(savedCopyMaxAge + const Duration(minutes: 1));
    await load(s.container, refresh: true);

    expect(stateOf(s.container).notifications, isEmpty);
    expect(stateOf(s.container).isSavedCopy, isFalse);
    expect(stateOf(s.container).error, isNotNull);
  });

  test('a server error shows the copy; a refusal does not', () async {
    final s = open(7, [
      _page(['one']),
      const ApiException('down', 503),
      const ApiException('no', 403),
    ]);
    await load(s.container);

    await load(s.container, refresh: true);
    expect(stateOf(s.container).isSavedCopy, isTrue);

    await load(s.container, refresh: true);
    expect(stateOf(s.container).isSavedCopy, isFalse);
    expect(stateOf(s.container).notifications, isEmpty);
    expect(stateOf(s.container).error, isNotNull);
  });

  test('coming back online replaces the saved copy', () async {
    final s = open(7, [
      _page(['one']),
      offline,
      _page(['two']),
    ]);
    await load(s.container);
    await load(s.container, refresh: true);
    expect(stateOf(s.container).isSavedCopy, isTrue);

    await load(s.container, refresh: true);
    expect(stateOf(s.container).notifications.single.title, 'two');
    expect(stateOf(s.container).isSavedCopy, isFalse);
  });

  test('a different member does not see the first member\'s copy', () async {
    final first = open(7, [
      _page(['seven\'s']),
    ]);
    await load(first.container);

    final second = open(8, [offline]);
    await load(second.container);

    expect(stateOf(second.container).notifications, isEmpty);
    expect(stateOf(second.container).isSavedCopy, isFalse);
  });

  test('a guest (token 0) has nothing saved', () async {
    final guest = open(0, [
      _page(['one']),
      offline,
    ]);
    await load(guest.container);
    await load(guest.container, refresh: true);

    expect(stateOf(guest.container).isSavedCopy, isFalse);
    final box = Hive.box(AppConstants.cacheBoxKey);
    expect(
      box.keys.where((k) => '$k'.startsWith('notifications_inbox_')),
      isEmpty,
    );
  });

  test('only the first page is saved', () async {
    final s = open(7, [
      _page(['one'], total: 2),
      _page(['two'], total: 2),
      offline,
    ]);
    await load(s.container);
    await load(s.container);
    expect(s.notifier.asked, [0, 1]);

    await load(s.container, refresh: true);
    expect(stateOf(s.container).notifications.map((n) => n.title), ['one']);
  });
}
