import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/deletion_requests.dart';

Map<String, dynamic> _request({
  int id = 4,
  String status = 'pending',
  String? confirmedAt,
  Map<String, dynamic>? confirmation,
  bool canComplete = false,
  bool isDemo = false,
}) => {
  'id': id,
  'status': status,
  'source': 'app',
  'token': 55,
  'member_name': 'Ali Raza',
  'contact_email': 'ali@example.test',
  'requested_at': '2026-10-01T10:00:00',
  'reason': null,
  'operator_note': null,
  'confirmation_sent_at': confirmedAt,
  'completed_at': null,
  'cancelled_at': null,
  'handled_by': null,
  'handled_by_name': null,
  'member_zip': null,
  'member_mobile': null,
  'is_demo': isDemo,
  'can_complete': canComplete,
  'confirmation': confirmation,
};

void main() {
  test('the queue parses with its counts, newest first', () {
    final queue = DeletionQueue.fromJson({
      'counts': {
        'pending': 2,
        'awaiting_prize_delivery': 1,
        'completed': 1,
        'cancelled': 0,
      },
      'requests': [_request(id: 4), _request(id: 3)],
    });

    expect(queue.requests.map((r) => r.id), [4, 3]);
    expect(queue.count('pending'), 2);
    expect(queue.count('cancelled'), 0);
    expect(queue.total, 4);
  });

  test('a request carries what the issue asks the screen to show', () {
    final r = DeletionRequest.fromJson(
      _request(confirmedAt: '2026-10-02T09:00:00', canComplete: true)
        ..['handled_by_name'] = 'Zayd Khan',
    );

    expect(r.memberName, 'Ali Raza');
    expect(r.contactEmail, 'ali@example.test');
    expect(r.confirmationSent, isTrue);
    expect(r.handledByName, 'Zayd Khan');
    expect(r.isLive, isTrue);
    expect(r.canComplete, isTrue);
    expect(r.confirmation, isNull);
  });

  test('a live request with no confirmation carries the text to send', () {
    final r = DeletionRequest.fromJson(
      _request(
        confirmation: {
          'to': 'ali@example.test',
          'subject': 'Your account has been deleted',
          'body': 'Dear Ali,',
        },
      ),
    );

    expect(r.confirmationSent, isFalse);
    expect(r.confirmation!.to, 'ali@example.test');
    expect(r.confirmation!.subject, 'Your account has been deleted');
    expect(r.confirmation!.body, 'Dear Ali,');
  });

  test('a settled request is not live', () {
    expect(
      DeletionRequest.fromJson(_request(status: 'completed')).isLive,
      isFalse,
    );
    expect(
      DeletionRequest.fromJson(_request(status: 'cancelled')).isLive,
      isFalse,
    );
    expect(
      DeletionRequest.fromJson(
        _request(status: 'awaiting_prize_delivery'),
      ).isLive,
      isTrue,
    );
  });

  test('raising answers with the request and whether it was opened', () {
    final opened = RaisedDeletionRequest.fromJson({
      'request': _request(id: 10),
      'created': true,
    });
    final existing = RaisedDeletionRequest.fromJson({
      'request': _request(id: 10),
      'created': false,
    });

    expect(opened.created, isTrue);
    expect(existing.created, isFalse);
    expect(existing.request.id, 10);
  });

  test('a body that is not the queue throws, so the screen offers a retry', () {
    expect(
      () => DeletionQueue.fromJson({'requests': 'x'}),
      throwsFormatException,
    );
    expect(
      () => DeletionRequest.oneFromJson({'nope': 1}),
      throwsFormatException,
    );
  });
}
