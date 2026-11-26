import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/services/saved_copy.dart';

const _key = 'permissions_json_v4';

/// The member the tests are signed in as.
int? _member = 7;
int? _owner() => _member;

/// Saves the body the way the app does, owned by member 7.
Future<void> _saveOwned(Box box, Map<String, dynamic> body) => SavedCopies(
  box,
  owner: () => 7,
  maxAge: null,
).save(_key, json.encode(body));

Map<String, dynamic> _teacherBody() => {
  'version': 4,
  'issued_at': '2026-10-05T08:00:00.000000+00:00',
  'permissions': ['sessions:create:own', 'classes:read:enrolled'],
  'scopes': {
    'gender': null,
    'assigned': <int>[],
    'assigned_genders': <int>[],
    'own': [391],
    'taught': [391],
    'enrolled': [412],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late Box box;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('permissions_test');
    Hive.init(dir.path);
    box = await Hive.openBox(AppConstants.cacheBoxKey);
    _member = 7;
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('init loads the cached v4 payload', () async {
    await _saveOwned(box, _teacherBody());
    final notifier = PermissionsNotifier(owner: _owner);

    await notifier.init();

    expect(notifier.state.payload!.scopes.own, [391]);
    expect(notifier.state.can('sessions:create', classId: 391), isTrue);
  });

  test('init ignores permissions saved for another member (#761)', () async {
    await _saveOwned(box, _teacherBody());
    _member = 8;
    final notifier = PermissionsNotifier(owner: _owner);

    await notifier.init();

    expect(notifier.state.payload, isNull);
    expect(notifier.state.unconfirmed, isTrue);
  });

  test('init ignores permissions saved with no owner (#761)', () async {
    await box.put(_key, json.encode(_teacherBody()));
    final notifier = PermissionsNotifier(owner: _owner);

    await notifier.init();

    expect(notifier.state.payload, isNull);
    expect(notifier.state.unconfirmed, isTrue);
  });

  test(
    'a failed fetch does not fall back to another member\'s permissions',
    () async {
      await _saveOwned(box, _teacherBody());
      _member = 8;
      final notifier = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async => throw Exception('offline'),
      );

      await notifier.fetchAndSave();

      expect(notifier.state.can('sessions:create', classId: 391), isFalse);
    },
  );

  test('init ignores the cache of older builds', () async {
    await box.put(
      'permissions_json_v2',
      json.encode({'role_name': 'SUPER_ADMIN'}),
    );
    final notifier = PermissionsNotifier(owner: _owner);

    await notifier.init();

    expect(notifier.state.payload, isNull);
    expect(notifier.state.unconfirmed, isTrue);
  });

  test('init without a copy is unconfirmed, not the empty member', () async {
    final notifier = PermissionsNotifier(owner: _owner);

    await notifier.init();

    expect(notifier.state.payload, isNull);
    expect(notifier.state.unconfirmed, isTrue);
    expect(notifier.state.can('classes:read', classId: 1), isFalse);
  });

  test(
    'init with nobody signed in is the member base, not unconfirmed',
    () async {
      final notifier = PermissionsNotifier(owner: () => null);

      await notifier.init();

      expect(notifier.state.payload, isNotNull);
      expect(notifier.state.unconfirmed, isFalse);
      expect(notifier.state.can('classes:read', classId: 1), isFalse);
    },
  );

  test('a guest is never asked about: a refresh fetches nothing', () async {
    var asked = 0;
    final notifier = PermissionsNotifier(
      owner: () => null,
      fetch: ({ifNoneMatch}) async {
        asked++;
        throw Exception('401');
      },
    );
    notifier.useGuestBase();

    await notifier.fetchAndSave();

    expect(asked, 0);
    expect(notifier.state.payload, isNotNull);
    expect(notifier.state.stale, isFalse);
    expect(notifier.state.error, isNull);
  });

  test(
    'signing in from guest does not keep the guest base as the answer',
    () async {
      int? signedIn;
      final notifier = PermissionsNotifier(
        owner: () => signedIn,
        fetch: ({ifNoneMatch}) async => throw Exception('offline'),
      );
      notifier.useGuestBase();

      signedIn = _member;
      await notifier.fetchAndSave();

      expect(notifier.state.payload, isNull);
      expect(notifier.state.unconfirmed, isTrue);
      expect(notifier.state.stale, isFalse);
    },
  );

  test('a first fetch that fails stays unconfirmed with the error', () async {
    final notifier = PermissionsNotifier(
      owner: _owner,
      fetch: ({ifNoneMatch}) async => throw Exception('503'),
    );
    await notifier.init();

    await notifier.fetchAndSave();

    expect(notifier.state.payload, isNull);
    expect(notifier.state.unconfirmed, isTrue);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.error, contains('503'));
  });

  test('a first fetch that works confirms the state', () async {
    final notifier = PermissionsNotifier(
      owner: _owner,
      fetch: ({ifNoneMatch}) async => _teacherBody(),
    );
    await notifier.init();

    await notifier.fetchAndSave();

    expect(notifier.state.unconfirmed, isFalse);
    expect(notifier.state.payload, isNotNull);
  });

  test('fetch stores the payload and updates state', () async {
    final notifier = PermissionsNotifier(
      owner: _owner,
      fetch: ({ifNoneMatch}) async => _teacherBody(),
    );

    await notifier.fetchAndSave();

    expect(notifier.state.can('sessions:create', classId: 391), isTrue);
    expect(notifier.state.error, isNull);
    final saved = box.get(_key) as Map;
    final stored = json.decode(saved['data'] as String) as Map<String, dynamic>;
    expect((stored['scopes'] as Map)['own'], [391]);
  });

  test(
    'fetch failure keeps the payload, marks it stale and says why',
    () async {
      await _saveOwned(box, _teacherBody());
      final notifier = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async => throw Exception('offline'),
      );
      await notifier.init();

      await notifier.fetchAndSave();

      expect(notifier.state.can('sessions:create', classId: 391), isTrue);
      expect(notifier.state.stale, isTrue);
      expect(notifier.state.error, contains('offline'));
    },
  );

  test('a failed fetch leaves the saved copy as it was', () async {
    await _saveOwned(box, _teacherBody());
    final before = box.get(_key);
    final notifier = PermissionsNotifier(
      owner: _owner,
      fetch: ({ifNoneMatch}) async => throw Exception('server said 503'),
    );
    await notifier.init();

    await notifier.fetchAndSave();

    expect(box.get(_key), before);
  });

  test('fetch failure without a copy installs and saves nothing', () async {
    final notifier = PermissionsNotifier(
      owner: _owner,
      fetch: ({ifNoneMatch}) async => throw Exception('offline'),
    );

    await notifier.fetchAndSave();

    expect(notifier.state.payload, isNull);
    expect(notifier.state.stale, isFalse);
    expect(notifier.state.error, contains('offline'));
    expect(box.get(_key), isNull);
  });

  test('a good fetch after a failure clears stale and the error', () async {
    await _saveOwned(box, _teacherBody());
    var fail = true;
    final notifier = PermissionsNotifier(
      owner: _owner,
      fetch: ({ifNoneMatch}) async {
        if (fail) throw Exception('offline');
        return _teacherBody();
      },
    );
    await notifier.init();
    await notifier.fetchAndSave();
    fail = false;

    await notifier.fetchAndSave();

    expect(notifier.state.stale, isFalse);
    expect(notifier.state.error, isNull);
  });

  test('fetch saves the revision with the copy', () async {
    final notifier = PermissionsNotifier(
      owner: _owner,
      fetch: ({ifNoneMatch}) async => {
        ..._teacherBody(),
        'revision': '0123456789abcdef',
      },
    );

    await notifier.fetchAndSave();
    final other = PermissionsNotifier(owner: _owner);
    await other.init();

    expect(other.state.payload!.revision, '0123456789abcdef');
  });

  group('conditional fetch', () {
    Map<String, dynamic> withRevision(String revision) => {
      ..._teacherBody(),
      'version': 5,
      'revision': revision,
    };

    test('sends the saved revision once and a 304 keeps the copy', () async {
      await _saveOwned(box, withRevision('aaaaaaaaaaaaaaaa'));
      final sent = <String?>[];
      final notifier = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async {
          sent.add(ifNoneMatch);
          return null;
        },
      );
      await notifier.init();
      final before = box.get(_key);

      await notifier.fetchAndSave();

      expect(sent, ['aaaaaaaaaaaaaaaa']);
      expect(notifier.state.payload!.revision, 'aaaaaaaaaaaaaaaa');
      expect(notifier.state.stale, isFalse);
      expect(notifier.state.error, isNull);
      expect(box.get(_key), before);
    });

    test('a 304 clears a stale mark: the copy is confirmed', () async {
      await _saveOwned(box, withRevision('aaaaaaaaaaaaaaaa'));
      var offline = true;
      final notifier = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async {
          if (offline) throw Exception('offline');
          return null;
        },
      );
      await notifier.init();
      await notifier.fetchAndSave();
      expect(notifier.state.stale, isTrue);
      offline = false;

      await notifier.fetchAndSave();

      expect(notifier.state.stale, isFalse);
      expect(notifier.state.payload, isNotNull);
    });

    test('a copy with no revision is fetched in full', () async {
      await _saveOwned(box, _teacherBody());
      final sent = <String?>[];
      final notifier = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async {
          sent.add(ifNoneMatch);
          return withRevision('bbbbbbbbbbbbbbbb');
        },
      );
      await notifier.init();

      await notifier.fetchAndSave();

      expect(sent, [null]);
      expect(notifier.state.payload!.revision, 'bbbbbbbbbbbbbbbb');
    });

    test('a 304 with nothing saved is a failed fetch', () async {
      final notifier = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async => null,
      );
      await notifier.init();

      await notifier.fetchAndSave();

      expect(notifier.state.payload, isNull);
      expect(notifier.state.unconfirmed, isTrue);
      expect(notifier.state.error, isNotNull);
    });

    test('callers that arrive during a fetch share it', () async {
      await _saveOwned(box, withRevision('aaaaaaaaaaaaaaaa'));
      final release = Completer<void>();
      var calls = 0;
      final notifier = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async {
          calls++;
          await release.future;
          return null;
        },
      );
      await notifier.init();

      final first = notifier.fetchAndSave();
      final second = notifier.fetchAndSave();
      release.complete();
      await Future.wait([first, second]);

      expect(calls, 1);
    });
  });

  group('server revision announced on a response', () {
    late DateTime clock;
    late List<Completer<void>> pending;
    late int fetches;
    late PermissionsNotifier notifier;

    setUp(() async {
      await _saveOwned(box, {
        ..._teacherBody(),
        'version': 5,
        'revision': 'aaaaaaaaaaaaaaaa',
      });
      clock = DateTime(2026, 11, 2, 9);
      pending = [];
      fetches = 0;
      notifier = PermissionsNotifier(
        owner: _owner,
        now: () => clock,
        fetch: ({ifNoneMatch}) async {
          fetches++;
          final gate = Completer<void>();
          pending.add(gate);
          await gate.future;
          return {
            ..._teacherBody(),
            'version': 5,
            'revision': 'bbbbbbbbbbbbbbbb',
          };
        },
      );
      await notifier.init();
    });

    test('the held revision again: no fetch', () {
      notifier.onServerRevision('aaaaaaaaaaaaaaaa');
      expect(fetches, 0);
    });

    test('two responses with the same new revision: one fetch', () async {
      notifier.onServerRevision('bbbbbbbbbbbbbbbb');
      notifier.onServerRevision('bbbbbbbbbbbbbbbb');
      pending.single.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      notifier.onServerRevision('bbbbbbbbbbbbbbbb');

      expect(fetches, 1);
      expect(notifier.state.payload!.revision, 'bbbbbbbbbbbbbbbb');
    });

    test('a failing server is not asked again for the same revision', () async {
      var fail = true;
      final failing = PermissionsNotifier(
        owner: _owner,
        now: () => clock,
        fetch: ({ifNoneMatch}) async {
          fetches++;
          if (fail) throw Exception('503');
          return null;
        },
      );
      await failing.init();

      failing.onServerRevision('cccccccccccccccc');
      await Future<void>.delayed(Duration.zero);
      failing.onServerRevision('cccccccccccccccc');
      await Future<void>.delayed(Duration.zero);
      expect(fetches, 1);

      clock = clock.add(const Duration(minutes: 2));
      failing.onServerRevision('cccccccccccccccc');
      await Future<void>.delayed(Duration.zero);
      expect(fetches, 2);
      fail = false;
    });

    test('signed out or unconfirmed: nothing to compare, no fetch', () {
      final nobody = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async {
          fetches++;
          return null;
        },
      );
      nobody.onServerRevision('bbbbbbbbbbbbbbbb');
      expect(fetches, 0);
    });
  });

  test('clear removes the cache (and older keys) and the payload', () async {
    await _saveOwned(box, _teacherBody());
    await box.put('permissions_json_v2', 'old');
    final notifier = PermissionsNotifier(
      owner: _owner,
      fetch: ({ifNoneMatch}) async => _teacherBody(),
    );
    await notifier.fetchAndSave();

    await notifier.clear();

    expect(notifier.state.payload, isNull);
    expect(box.get(_key), isNull);
    expect(box.get('permissions_json_v2'), isNull);
  });

  group('refetch rules', () {
    late DateTime clock;
    late int fetches;
    late PermissionsNotifier notifier;

    setUp(() async {
      clock = DateTime(2026, 10, 5, 9);
      fetches = 0;
      notifier = PermissionsNotifier(
        owner: _owner,
        fetch: ({ifNoneMatch}) async {
          fetches++;
          return _teacherBody();
        },
        now: () => clock,
      );
      await notifier.fetchAndSave();
      fetches = 0;
    });

    test('resume within 15 minutes does not refetch', () async {
      clock = clock.add(const Duration(minutes: 14));
      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(fetches, 0);
    });

    test('resume after 15 minutes refetches', () async {
      clock = clock.add(const Duration(minutes: 16));
      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(fetches, 1);
    });

    test('only a resume triggers it', () async {
      clock = clock.add(const Duration(hours: 1));
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(fetches, 0);
    });

    test('a 403 refetches, but not twice within a minute', () async {
      clock = clock.add(const Duration(minutes: 2));
      await notifier.refreshIfOlderThan(PermissionsNotifier.forbiddenGap);
      expect(fetches, 1);
      await notifier.refreshIfOlderThan(PermissionsNotifier.forbiddenGap);
      expect(fetches, 1);
    });

    test('signed out (no payload): no refetch', () async {
      await notifier.clear();
      clock = clock.add(const Duration(hours: 1));
      await notifier.refreshIfOlderThan(PermissionsNotifier.resumeGap);
      expect(fetches, 0);
    });
  });
}
