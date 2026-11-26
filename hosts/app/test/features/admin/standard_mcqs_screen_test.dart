import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/admin/models/standard_mcqs.dart';
import 'package:the_strong_rope/features/admin/providers/standard_mcqs_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/standard_mcqs_repository.dart';
import 'package:the_strong_rope/features/admin/screens/standard_mcqs_screen.dart';

/// Answers from fixtures and records what the screen asked for; never the
/// network, never the sheet.
class _FakeRepository implements StandardMcqsRepository {
  final calls = <String>[];
  Completer<List<StandardMcqResult>>? pending;
  Object? failUpdate;

  @override
  Future<StandardMcqSources> getSources() async => StandardMcqSources.fromJson({
    'languages': [
      {'id': 1, 'name': 'English'},
      {'id': 2, 'name': 'Urdu'},
    ],
    'levels': [
      {'id': 1, 'name': 'Abuzar'},
      {'id': 2, 'name': 'Miqdad'},
    ],
  });

  @override
  Future<List<StandardMcqResult>> update({
    required List<int> languages,
    required List<int> levels,
  }) {
    calls.add('update:$languages:$levels');
    if (failUpdate != null) return Future.error(failUpdate!);
    return pending?.future ??
        Future.value([
          const StandardMcqResult(
            language: 'English',
            level: 'Abuzar',
            updated: true,
            quizzes: 12,
          ),
          const StandardMcqResult(
            language: 'Urdu',
            level: 'Abuzar',
            updated: false,
            reason: 'Not updated: another sheet could not be read',
          ),
        ]);
  }
}

Future<_FakeRepository> _open(WidgetTester tester) async {
  final repo = _FakeRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [standardMcqsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: StandardMcqsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

bool _updateEnabled(WidgetTester tester) => tester
    .widget<FilledButton>(find.byKey(const Key('update-standard-mcqs')))
    .enabled;

Future<void> _chooseOneOfEach(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('language-1')));
  await tester.tap(find.byKey(const Key('level-1')));
  await tester.pump();
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('update-standard-mcqs')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Update').last);
  await tester.pump();
}

void main() {
  testWidgets('lists the languages and levels, Update disabled until both '
      'have a choice', (tester) async {
    await _open(tester);

    expect(find.text('English'), findsOneWidget);
    expect(find.text('Urdu'), findsOneWidget);
    expect(find.text('Abuzar'), findsOneWidget);
    expect(find.text('Miqdad'), findsOneWidget);
    expect(_updateEnabled(tester), isFalse);

    await tester.tap(find.byKey(const Key('language-1')));
    await tester.pump();
    expect(_updateEnabled(tester), isFalse);

    await tester.tap(find.byKey(const Key('level-1')));
    await tester.pump();
    expect(_updateEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('level-1')));
    await tester.pump();
    expect(_updateEnabled(tester), isFalse);
  });

  testWidgets('cancelling the confirm sends nothing', (tester) async {
    final repo = await _open(tester);
    await _chooseOneOfEach(tester);

    await tester.tap(find.byKey(const Key('update-standard-mcqs')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
  });

  testWidgets('shows a running state, then each pair\'s result', (
    tester,
  ) async {
    final repo = await _open(tester);
    repo.pending = Completer<List<StandardMcqResult>>();
    await _chooseOneOfEach(tester);
    await _confirm(tester);

    expect(repo.calls, ['update:[1]:[1]']);
    expect(find.textContaining('Updating'), findsOneWidget);
    expect(_updateEnabled(tester), isFalse);

    repo.pending!.complete([
      const StandardMcqResult(
        language: 'English',
        level: 'Abuzar',
        updated: true,
        quizzes: 12,
      ),
      const StandardMcqResult(
        language: 'Urdu',
        level: 'Abuzar',
        updated: false,
        reason: 'Not updated: another sheet could not be read',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Updated, 12 quizzes'), findsOneWidget);
    expect(
      find.text('Failed: Not updated: another sheet could not be read'),
      findsOneWidget,
    );
    expect(_updateEnabled(tester), isTrue);
  });

  testWidgets('a 409 is shown as the server said it', (tester) async {
    final repo = await _open(tester);
    repo.failUpdate = const ApiException(
      'An update is already running. Try again in a minute.',
      409,
    );
    await _chooseOneOfEach(tester);
    await _confirm(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('An update is already running. Try again in a minute.'),
      findsOneWidget,
    );
    expect(_updateEnabled(tester), isTrue);
  });
}
