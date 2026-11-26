import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/admin/models/deletion_requests.dart';
import 'package:the_strong_rope/features/admin/providers/deletion_requests_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/deletion_requests_repository.dart';
import 'package:the_strong_rope/features/admin/screens/deletion_requests_screen.dart';

Map<String, dynamic> _json({
  required int id,
  String status = 'pending',
  String name = 'Ali Raza',
  String? confirmedAt,
  Map<String, dynamic>? confirmation,
  bool canComplete = false,
  bool isDemo = false,
  String? note,
  String? zip,
  String? mobile,
}) => {
  'id': id,
  'status': status,
  'source': 'app',
  'token': 55,
  'member_name': name,
  'contact_email': 'ali@example.test',
  'requested_at': '2026-10-01T10:00:00',
  'reason': null,
  'operator_note': note,
  'confirmation_sent_at': confirmedAt,
  'completed_at': null,
  'cancelled_at': null,
  'handled_by': null,
  'handled_by_name': null,
  'member_zip': zip,
  'member_mobile': mobile,
  'is_demo': isDemo,
  'can_complete': canComplete,
  'confirmation': confirmation,
};

const _mail = {
  'to': 'ali@example.test',
  'subject': 'Your account has been deleted',
  'body': 'Dear Ali Raza, we have finished.',
};

DeletionQueue _queue(List<Map<String, dynamic>> requests) =>
    DeletionQueue.fromJson({
      'counts': {
        'pending': 2,
        'awaiting_prize_delivery': 1,
        'completed': 1,
        'cancelled': 0,
      },
      'requests': requests,
    });

/// Records what the screen asked for; answers from the queue it was given.
class _FakeRepository implements DeletionRequestsRepository {
  _FakeRepository(this.queue);

  final DeletionQueue queue;
  final calls = <String>[];
  Object? failComplete;
  bool raiseCreates = true;

  @override
  Future<DeletionQueue> getQueue({String? status}) async {
    calls.add('queue:$status');
    return queue;
  }

  @override
  Future<RaisedDeletionRequest> raise(String email) async {
    calls.add('raise:$email');
    return RaisedDeletionRequest(
      request: DeletionRequest.fromJson(_json(id: 10)),
      created: raiseCreates,
    );
  }

  @override
  Future<DeletionRequest> hold(int id, String note) async {
    calls.add('hold:$id:$note');
    return DeletionRequest.fromJson(
      _json(id: id, status: 'awaiting_prize_delivery'),
    );
  }

  @override
  Future<DeletionRequest> confirmationSent(int id) async {
    calls.add('confirmationSent:$id');
    return DeletionRequest.fromJson(
      _json(id: id, confirmedAt: '2026-10-02T09:00:00'),
    );
  }

  @override
  Future<DeletionRequest> complete(int id) async {
    calls.add('complete:$id');
    if (failComplete != null) throw failComplete!;
    return DeletionRequest.fromJson(_json(id: id, status: 'completed'));
  }
}

Future<_FakeRepository> _open(
  WidgetTester tester,
  List<Map<String, dynamic>> requests, {
  void Function(_FakeRepository)? configure,
}) async {
  final repo = _FakeRepository(_queue(requests));
  configure?.call(repo);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [deletionRequestsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: DeletionRequestsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('shows a chip per status with its count, and the requests', (
    tester,
  ) async {
    await _open(tester, [_json(id: 4)]);

    expect(find.text('All (4)'), findsOneWidget);
    expect(find.text('Pending (2)'), findsOneWidget);
    expect(find.text('Awaiting prize delivery (1)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Cancelled (0)'), findsOneWidget);
    expect(find.textContaining('#4'), findsOneWidget);
    expect(find.textContaining('Ali Raza'), findsWidgets);
    expect(find.textContaining('ali@example.test'), findsWidgets);
  });

  testWidgets('tapping a chip asks the server for that status', (tester) async {
    final repo = await _open(tester, [_json(id: 4)]);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('queue:completed'));
  });

  testWidgets('an empty queue says so', (tester) async {
    await _open(tester, []);

    expect(find.text('Nothing here.'), findsOneWidget);
  });

  testWidgets('a held request shows the postal code and mobile and the note', (
    tester,
  ) async {
    await _open(tester, [
      _json(
        id: 3,
        status: 'awaiting_prize_delivery',
        confirmedAt: '2026-10-02T09:00:00',
        note: 'Prize on its way',
        zip: '400001',
        mobile: '+919800000000',
        canComplete: true,
      ),
    ]);

    expect(find.textContaining('400001'), findsOneWidget);
    expect(find.textContaining('+919800000000'), findsOneWidget);
    expect(find.textContaining('Prize on its way'), findsOneWidget);
  });

  testWidgets('an unconfirmed request shows the text to send, not Complete', (
    tester,
  ) async {
    await _open(tester, [_json(id: 4, confirmation: _mail)]);

    expect(
      find.textContaining('Your account has been deleted'),
      findsOneWidget,
    );
    expect(find.textContaining('Dear Ali Raza'), findsOneWidget);
    expect(find.text('I have sent this confirmation'), findsOneWidget);
    expect(find.text('Complete deletion'), findsNothing);
  });

  testWidgets('recording the confirmation calls the server once', (
    tester,
  ) async {
    final repo = await _open(tester, [_json(id: 4, confirmation: _mail)]);

    await tester.ensureVisible(find.text('I have sent this confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I have sent this confirmation'));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c.startsWith('confirmationSent')), [
      'confirmationSent:4',
    ]);
  });

  testWidgets('holding asks for a note and sends it', (tester) async {
    final repo = await _open(tester, [_json(id: 4, confirmation: _mail)]);

    await tester.tap(find.text('Hold for prize delivery'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Prize pending');
    await tester.tap(find.text('Hold'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('hold:4:Prize pending'));
  });

  testWidgets('complete asks first, saying it cannot be undone', (
    tester,
  ) async {
    final repo = await _open(tester, [
      _json(id: 3, confirmedAt: '2026-10-02T09:00:00', canComplete: true),
    ]);

    await tester.tap(find.text('Complete deletion'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('complete')), isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('complete')), isEmpty);
  });

  testWidgets('confirming completes it once', (tester) async {
    final repo = await _open(tester, [
      _json(id: 3, confirmedAt: '2026-10-02T09:00:00', canComplete: true),
    ]);

    await tester.tap(find.text('Complete deletion'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Complete deletion'));
    await tester.pumpAndSettle();

    expect(repo.calls.where((c) => c.startsWith('complete')), ['complete:3']);
  });

  testWidgets('a refused completion shows the reason and reloads', (
    tester,
  ) async {
    final repo = await _open(
      tester,
      [_json(id: 3, confirmedAt: '2026-10-02T09:00:00', canComplete: true)],
      configure: (r) =>
          r.failComplete = const ApiException('Firebase is unreachable', 409),
    );

    await tester.tap(find.text('Complete deletion'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Complete deletion'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Firebase is unreachable'), findsOneWidget);
    expect(
      repo.calls.where((c) => c.startsWith('queue')).length,
      greaterThan(1),
    );
  });

  testWidgets('the reviewer demo accounts cannot be completed', (tester) async {
    await _open(tester, [
      _json(id: 2, confirmedAt: '2026-10-02T09:00:00', isDemo: true),
    ]);

    expect(find.text('Complete deletion'), findsNothing);
    expect(find.textContaining('reviewer demo'), findsWidgets);
  });

  testWidgets('a settled request offers no action', (tester) async {
    await _open(tester, [_json(id: 1, status: 'completed')]);

    expect(find.text('Complete deletion'), findsNothing);
    expect(find.text('Hold for prize delivery'), findsNothing);
    expect(find.text('I have sent this confirmation'), findsNothing);
  });

  testWidgets(
    'raising from an email sends the address and says what happened',
    (tester) async {
      final repo = await _open(tester, [_json(id: 4)]);

      await tester.tap(find.byTooltip('Raise from an email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'ali@example.test');
      await tester.tap(find.text('Raise request'));
      await tester.pumpAndSettle();

      expect(repo.calls, contains('raise:ali@example.test'));
      expect(find.textContaining('Opened request #10'), findsOneWidget);
    },
  );

  testWidgets('raising for a member who already has one says so', (
    tester,
  ) async {
    await _open(tester, [
      _json(id: 4),
    ], configure: (r) => r.raiseCreates = false);

    await tester.tap(find.byTooltip('Raise from an email'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ali@example.test');
    await tester.tap(find.text('Raise request'));
    await tester.pumpAndSettle();

    expect(find.textContaining('already has request #10 open'), findsOneWidget);
  });
}
