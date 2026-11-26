import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/version/release_notes.dart';
import 'package:the_strong_rope/core/version/release_notes_screen.dart';

const _installed = (version: '1.1.0', build: '16');

const _releases = [
  Release(
    version: '1.1.0',
    date: '2026-10-11',
    notes: ['Manage a class from the app', 'State and City fill in'],
  ),
  Release(version: '1.0.6', date: '2026-09-20', notes: ['Reminders']),
];

Widget _wrap(Widget child, {required Future<List<Release>> Function() load}) {
  return ProviderScope(
    overrides: [
      installedVersionProvider.overrideWith((ref) async => _installed),
      releaseNotesProvider.overrideWith((ref) => load()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('ReleaseNotesScreen', () {
    testWidgets('lists releases and marks the installed one', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReleaseNotesScreen(), load: () async => _releases),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version 1.1.0 (16)'), findsOneWidget);
      expect(find.text('Manage a class from the app'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Your version'), findsOneWidget);
      // Newest first, as the server sent them.
      expect(
        tester.getTopLeft(find.text('1.1.0')).dy,
        lessThan(tester.getTopLeft(find.text('1.0.6')).dy),
      );
    });

    testWidgets('does not mark anything when the installed version has no '
        'notes', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReleaseNotesScreen(), load: () async => [_releases.last]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your version'), findsNothing);
    });

    testWidgets('says so when there are no release notes', (tester) async {
      await tester.pumpWidget(
        _wrap(const ReleaseNotesScreen(), load: () async => const []),
      );
      await tester.pumpAndSettle();

      expect(find.text('No release notes yet.'), findsOneWidget);
      expect(find.text('Version 1.1.0 (16)'), findsOneWidget);
    });

    testWidgets('when the notes cannot be loaded, still shows the version, '
        'says so and retries', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          const ReleaseNotesScreen(),
          load: () async {
            calls++;
            if (calls == 1) throw Exception('offline');
            return _releases;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version 1.1.0 (16)'), findsOneWidget);
      expect(
        find.text('The release notes could not be loaded.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(find.text('The release notes could not be loaded.'), findsNothing);
      expect(find.text('Manage a class from the app'), findsOneWidget);
    });
  });

  group('AppVersionTile', () {
    testWidgets('shows the installed version and build', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Scaffold(body: AppVersionTile()),
          load: () async => _releases,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version 1.1.0 (16)'), findsOneWidget);
    });
  });
}
