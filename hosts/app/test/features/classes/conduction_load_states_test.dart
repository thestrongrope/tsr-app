import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/widgets/app_error_view.dart';
import 'package:the_strong_rope/core/widgets/skeleton_box.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/providers/conduction_queue_provider.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_list_screen.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_form_screen.dart';
import 'package:the_strong_rope/features/classes/widgets/class_loading_skeleton.dart';
import 'package:the_strong_rope/features/classes/services/conduction_queue_store.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';

import '../../support/content_width.dart';

const _classId = 42;

class _MemoryStore extends ConductionQueueStore {
  @override
  List<QueuedConduction> read(int token) => const [];

  @override
  Future<void> write(int token, List<QueuedConduction> items) async {}
}

Future<void> _pump(
  WidgetTester tester,
  Future<ConductionListResponse> Function() load,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recentActionsMemberProvider.overrideWithValue(100),
        conductionQueueStoreProvider.overrideWithValue(_MemoryStore()),
        conductionSessionsProvider(_classId).overrideWith((ref) => load()),
      ],
      child: const MaterialApp(home: ConductionListScreen(classId: _classId)),
    ),
  );
}

void main() {
  _formTests();
  for (final size in [tabletLandscape, tabletPortrait]) {
    testWidgets('on a $size tablet the list is capped and centred', (
      tester,
    ) async {
      setWindow(tester, size);
      await _pump(tester, () async => throw const ApiException('offline', 0));
      await tester.pumpAndSettle();

      expectContentCapped(tester);
    });
  }

  testWidgets('while the records load, a skeleton is shown', (tester) async {
    final pending = Completer<ConductionListResponse>();
    await _pump(tester, () => pending.future);

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed load says so and Retry loads the same class again', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, () async {
      calls++;
      throw const ApiException('offline', 0);
    });
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('Class Conduction'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Class Conduction'), findsOneWidget);
  });
}

void _formTests() {
  for (final size in [tabletLandscape, tabletPortrait, const Size(600, 800)]) {
    for (final isEdit in [false, true]) {
      testWidgets(
        '${isEdit ? 'edit' : 'add'} form loading and error stay capped at $size',
        (tester) async {
          setWindow(tester, size);
          final pending = Completer<ConductionFormData>();
          final pendingEdit = Completer<ConductionEditData>();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                syllabusTopicsProvider(
                  _classId,
                ).overrideWith((ref) async => const {}),
                conductionFormDataProvider(
                  _classId,
                ).overrideWith((ref) => pending.future),
                conductionSessionProvider((
                  classId: _classId,
                  sessionId: 7,
                )).overrideWith((ref) => pendingEdit.future),
                holyQuranProvider.overrideWith((ref) async => []),
              ],
              child: MaterialApp(
                home: ConductionFormScreen(
                  classId: _classId,
                  sessionId: isEdit ? 7 : null,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(ClassLoadingSkeleton), findsOneWidget);
          expectContentCapped(tester);
          expect(
            tester.getSize(find.byType(ClassLoadingSkeleton)).width,
            size.width > 840 ? 840 : size.width,
          );
          expect(tester.getSize(find.byType(AppBar)).width, size.width);

          if (isEdit) {
            pendingEdit.completeError(const ApiException('offline', 0));
          } else {
            pending.completeError(const ApiException('offline', 0));
          }
          await tester.pumpAndSettle();

          expect(find.byType(AppErrorView), findsOneWidget);
          expectContentCapped(tester);
          expect(
            tester.getSize(find.byType(AppErrorView)).width,
            size.width > 840 ? 840 : size.width,
          );
          expect(tester.getSize(find.byType(AppBar)).width, size.width);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('a form that failed to load fetches again when reopened', (
    tester,
  ) async {
    var calls = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentActionsMemberProvider.overrideWithValue(100),
          conductionQueueStoreProvider.overrideWithValue(_MemoryStore()),
          syllabusTopicsProvider(
            _classId,
          ).overrideWith((ref) async => const {}),
          conductionFormDataProvider(_classId).overrideWith((ref) async {
            calls++;
            if (calls == 1) throw const ApiException('offline', 0);
            return ConductionFormData(
              classInfo: const ConductionClass(
                id: _classId,
                code: 'MK5',
                name: 'Miqdad 5',
              ),
              nextSessionDate: DateTime(2026, 10, 20),
            );
          }),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('Class page')),
        ),
      ),
    );

    MaterialPageRoute<void> route() => MaterialPageRoute<void>(
      builder: (_) => const ConductionFormScreen(classId: _classId),
    );

    navigatorKey.currentState!.push(route());
    await tester.pumpAndSettle();
    expect(find.byType(AppErrorView), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(route());
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(AppErrorView), findsNothing);
    expect(find.text('Save Conduction'), findsOneWidget);
  });
}
