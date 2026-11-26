import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/quiz.dart';
import 'package:the_strong_rope/features/mcq_manage/models/mcq_manage.dart';
import 'package:the_strong_rope/features/notifications/models/user_notification.dart';

/// The API sends timestamps as UTC with no zone marker (#722). Each model
/// must read them as the instant they are, so the screens show the member's
/// own clock. Asserting on the instant keeps these valid in any time zone.
void main() {
  final instant = DateTime.utc(2026, 10, 20, 10, 0);
  const wire = '2026-10-20T10:00:00';

  test('an inbox notification: sent and read times', () {
    final n = UserNotification.fromJson({
      'id': 1,
      'title': 'Invented',
      'body': 'Invented body',
      'sentAt': wire,
      'readAt': wire,
    });

    expect(n.sentAt.toUtc(), instant);
    expect(n.readAt!.toUtc(), instant);
    expect(n.sentAt.isUtc, isFalse, reason: 'shown in the member\'s clock');
  });

  test('an unread inbox notification has no read time', () {
    final n = UserNotification.fromJson({
      'id': 1,
      'title': 'Invented',
      'body': 'Invented body',
      'sentAt': wire,
      'readAt': null,
    });

    expect(n.readAt, isNull);
  });

  test('a published quiz', () {
    final q = Quiz.fromJson({'id': 1, 'classId': 2, 'publishedAt': wire});

    expect(q.publishedAt!.toUtc(), instant);
  });

  test('an MCQ quiz in the manage list: created, published, deactivated', () {
    final q = McqManageQuiz.fromJson({
      'id': 1,
      'classId': 2,
      'createdAt': wire,
      'publishedAt': wire,
      'deactivatedAt': null,
    });

    expect(q.createdAt.toUtc(), instant);
    expect(q.publishedAt!.toUtc(), instant);
    expect(q.deactivatedAt, isNull);
  });
}
