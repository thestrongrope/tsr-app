import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/router/app_router.dart';
import 'package:the_strong_rope/core/version/startup_alert.dart';
import 'package:the_strong_rope/core/version/startup_alert_host.dart';
import 'package:the_strong_rope/core/version/version_gate.dart';
import 'package:the_strong_rope/core/version/version_provider.dart';

/// Dismissals held in memory, so the test needs no Hive box.
class _MemoryStore extends StartupAlertStore {
  int? release;
  String? announcement;

  @override
  int? get dismissedReleaseBuild => release;

  @override
  String? get dismissedAnnouncementId => announcement;

  @override
  Future<void> dismissRelease(int build) async => release = build;

  @override
  Future<void> dismissAnnouncement(String id) async => announcement = id;
}

const _policy = VersionPolicy(
  minimumBuild: 1,
  recommendedBuild: 16,
  storeUrl: 'https://example.invalid/app',
  latest: ReleaseNotes(version: '1.0.7', notes: ['Hour and minute buttons']),
);

const _news = Announcement(id: 'a1', title: 'New initiative', body: 'Join us.');

Widget _app({
  required _MemoryStore store,
  required Future<VersionCheck> Function() check,
}) {
  return ProviderScope(
    overrides: [
      startupAlertStoreProvider.overrideWithValue(store),
      versionCheckProvider.overrideWith((ref) => check()),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      builder: (context, child) => StartupAlertHost(child: child!),
      home: const Scaffold(body: Text('home')),
    ),
  );
}

VersionCheck _check({
  VersionStatus status = VersionStatus.updateRecommended,
  Announcement? announcement,
}) => (status: status, policy: _policy, announcement: announcement);

/// The startup alert as a member meets it: shown once, not again once
/// dismissed, never when nothing could be read, never under the blocking
/// screen (#519).
void main() {
  testWidgets(
    'a newer release is offered with its notes, and Later dismisses it',
    (tester) async {
      final store = _MemoryStore();
      await tester.pumpWidget(_app(store: store, check: () async => _check()));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);
      expect(find.text("What's new in 1.0.7"), findsOneWidget);
      expect(find.text('•  Hour and minute buttons'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsNothing);
      expect(store.release, 16);
    },
  );

  testWidgets('a dismissed release is not shown again on the next launch', (
    tester,
  ) async {
    final store = _MemoryStore()..release = 16;
    await tester.pumpWidget(_app(store: store, check: () async => _check()));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('the release comes first, then the announcement, one at a time', (
    tester,
  ) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      _app(
        store: store,
        check: () async => _check(announcement: _news),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('New initiative'), findsNothing, reason: 'one at a time');

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('New initiative'), findsOneWidget);
    expect(find.text('Join us.'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('New initiative'), findsNothing);
    expect(store.announcement, 'a1');
  });

  testWidgets('an announcement alone is shown once and not again', (
    tester,
  ) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      _app(
        store: store,
        check: () async =>
            _check(status: VersionStatus.ok, announcement: _news),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New initiative'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _app(
        store: store,
        check: () async =>
            _check(status: VersionStatus.ok, announcement: _news),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New initiative'), findsNothing);
  });

  testWidgets('a failed fetch shows nothing and does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        store: _MemoryStore(),
        check: () async => throw Exception('offline'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a required update shows no alert', (tester) async {
    await tester.pumpWidget(
      _app(
        store: _MemoryStore(),
        check: () async =>
            _check(status: VersionStatus.updateRequired, announcement: _news),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'a release with no notes still offers the update, without a list',
    (tester) async {
      const bare = VersionPolicy(
        minimumBuild: 1,
        recommendedBuild: 16,
        storeUrl: 'https://example.invalid/app',
        latest: ReleaseNotes(version: '1.0.7', notes: []),
      );
      await tester.pumpWidget(
        _app(
          store: _MemoryStore(),
          check: () async => (
            status: VersionStatus.updateRecommended,
            policy: bare,
            announcement: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update'), findsOneWidget);
      expect(find.textContaining('•'), findsNothing);
    },
  );
}
