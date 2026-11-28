import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/providers/conduction_queue_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/classes_repository.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_form_screen.dart';
import 'package:the_strong_rope/features/classes/screens/conduction_list_screen.dart';
import 'package:the_strong_rope/features/classes/services/conduction_queue_store.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';

const _classId = 42;

/// The server is whatever the test says: down, or refusing.
class _Repository extends ClassesRepository {
  _Repository(this.failure);

  /// Null means the server accepts the record.
  final ApiException? failure;
  var attempts = 0;
  final payloads = <Map<String, dynamic>>[];

  /// What the server says about the form's default date.
  var dateTaken = false;

  @override
  Future<ConductionSession> addConduction(
    int classId,
    Map<String, dynamic> payload,
  ) async {
    attempts++;
    payloads.add(payload);
    if (failure != null) throw failure!;
    return ConductionSession(
      id: 1,
      conductedOn: DateTime.parse(payload['conductedOn'] as String),
      conducted: false,
    );
  }

  @override
  Future<ConductionDateCheck> checkConductionDate(
    int classId,
    DateTime date,
  ) async => ConductionDateCheck(alreadyConducted: dateTaken);
}

/// Kept in memory: Hive's file I/O never completes inside a widget test's
/// fake-async zone. The store's own round trip is covered in
/// conduction_queue_test.dart.
class _MemoryStore extends ConductionQueueStore {
  final _saved = <int, List<QueuedConduction>>{};

  @override
  List<QueuedConduction> read(int token) => _saved[token] ?? const [];

  @override
  Future<void> write(int token, List<QueuedConduction> items) async =>
      _saved[token] = items;
}

class _Online extends OfflineNotifier {
  @override
  bool build() => false;
}

void main() {
  var formFetches = 0;

  setUp(() => formFetches = 0);

  Future<(ProviderContainer, _Repository, GoRouter)> open(
    WidgetTester tester,
    ApiException? failure,
  ) async {
    final repo = _Repository(failure);
    final container = ProviderContainer(
      overrides: [
        recentActionsMemberProvider.overrideWithValue(100),
        conductionQueueStoreProvider.overrideWithValue(_MemoryStore()),
        classesRepositoryProvider.overrideWithValue(repo),
        isOfflineProvider.overrideWith(_Online.new),
        syllabusTopicsProvider(_classId).overrideWith((ref) async => const {}),
        conductionFormDataProvider(_classId).overrideWith((ref) async {
          formFetches++;
          return ConductionFormData(
            classInfo: const ConductionClass(
              id: _classId,
              code: 'MK5',
              name: 'Miqdad 5',
            ),
            nextSessionDate: DateTime(2026, 10, 20),
          );
        }),
        conductionSessionsProvider(
          _classId,
        ).overrideWith((ref) async => throw const ApiException('offline', 0)),
      ],
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Class page')),
        ),
        GoRoute(
          path: '/form',
          builder: (_, _) => const ConductionFormScreen(classId: _classId),
        ),
        GoRoute(
          path: '/list',
          builder: (_, _) => const ConductionListScreen(classId: _classId),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    return (container, repo, router);
  }

  /// Unmounts the app and disposes the container inside the test: the queue
  /// keeps a retry timer, and the framework fails a test that ends with one
  /// pending, which a teardown callback is too late to stop.
  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  Future<void> saveNotConducted(
    WidgetTester tester,
    GoRouter router, {
    String reason = 'Eid holiday',
  }) async {
    router.push('/form');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not Conducted'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, reason);
    final save = find.text('Save Conduction');
    await tester.scrollUntilVisible(
      save,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('saved with no network: kept on the device and the form closes', (
    tester,
  ) async {
    final (container, _, router) = await open(
      tester,
      const ApiException('offline', 0),
    );

    await saveNotConducted(tester, router);

    final queued = container.read(conductionQueueProvider).single;
    expect(queued.classId, _classId);
    expect(queued.conductedOn, '2026-10-20');
    expect(queued.payload['nonConductionReason'], 'Eid holiday');
    expect(
      DateTime.tryParse(queued.payload['recordedAt'] as String),
      isNotNull,
      reason: 'the server needs the time the teacher pressed save',
    );
    expect(find.byType(ConductionFormScreen), findsNothing);
    expect(find.text('Class page'), findsOneWidget);
    await close(tester, container);
  });

  testWidgets('refused by the server: shown, nothing queued, form stays', (
    tester,
  ) async {
    final (container, _, router) = await open(
      tester,
      const ApiException('You do not have permission', 403),
    );

    await saveNotConducted(tester, router);

    expect(container.read(conductionQueueProvider), isEmpty);
    expect(find.byType(ConductionFormScreen), findsOneWidget);
    expect(find.textContaining('permission'), findsWidgets);
    expect(find.textContaining('Not saved'), findsOneWidget);
    expect(find.text('Eid holiday'), findsOneWidget);
    await close(tester, container);
  });

  testWidgets('the list shows an unsent record even when it cannot load', (
    tester,
  ) async {
    final (container, repo, router) = await open(
      tester,
      const ApiException('offline', 0),
    );
    await container.read(conductionQueueProvider.notifier).enqueue(_classId, {
      'conductedOn': '2026-10-20',
      'recordedAt': '2026-10-20T08:30:00.000Z',
    });
    repo.attempts = 0;

    router.push('/list');
    await tester.pumpAndSettle();

    expect(find.textContaining('waiting to send'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.textContaining('waiting to send'), findsNothing);
    expect(container.read(conductionQueueProvider), isEmpty);
    await close(tester, container);
  });

  testWidgets('the save time goes with the first attempt and the queue keeps '
      'the same one', (tester) async {
    final (container, repo, router) = await open(
      tester,
      const ApiException('offline', 0),
    );

    await saveNotConducted(tester, router);

    final sent = repo.payloads.single['recordedAt'] as String?;
    expect(sent, isNotNull, reason: 'a resend is recognised by this time');
    expect(
      container.read(conductionQueueProvider).single.payload['recordedAt'],
      sent,
    );
    await close(tester, container);
  });

  testWidgets('a second save for a date already waiting is refused and the '
      'first record stays', (tester) async {
    final (container, repo, router) = await open(
      tester,
      const ApiException('offline', 0),
    );
    await saveNotConducted(tester, router);
    expect(repo.attempts, 1);
    // Let the first save's snackbar go: it sits over the Save button.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    await saveNotConducted(tester, router, reason: 'Second try');

    expect(
      repo.attempts,
      1,
      reason: 'the second save never reached the server',
    );
    final queue = container.read(conductionQueueProvider);
    expect(queue.single.payload['nonConductionReason'], 'Eid holiday');
    expect(find.byType(ConductionFormScreen), findsOneWidget);
    expect(find.textContaining('already waiting'), findsWidgets);
    await close(tester, container);
  });

  testWidgets('a default date that already has a record is refused before '
      'anything is sent', (tester) async {
    final (container, repo, router) = await open(
      tester,
      const ApiException('offline', 0),
    );
    repo.dateTaken = true;

    await saveNotConducted(tester, router);

    expect(repo.attempts, 0);
    expect(container.read(conductionQueueProvider), isEmpty);
    expect(find.textContaining('already exists'), findsWidgets);
    await close(tester, container);
  });

  testWidgets('after a save the form data is fetched again, so the next form '
      'does not open on the date just recorded', (tester) async {
    final (container, _, router) = await open(tester, null);

    await saveNotConducted(tester, router);
    await container.read(conductionFormDataProvider(_classId).future);

    expect(formFetches, greaterThan(1));
    await close(tester, container);
  });
}
