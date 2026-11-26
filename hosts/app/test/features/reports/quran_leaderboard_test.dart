import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/reports/models/quran_leaderboard.dart';

Map<String, dynamic> _student({int rank = 1, String name = 'Ali'}) => {
  'rank': rank,
  'name': name,
  'token': 1001,
  'class': 'A1',
  'recitation': 120,
};

void main() {
  test('reads the envelope and each ranked student', () {
    final board = QuranLeaderboard.fromJson({
      'gender': 2,
      'from': '2025-10-15',
      'to': '2026-10-15',
      'levels': ['AMMAR', 'BILAL'],
      'total': 150,
      'students': [_student(), _student(rank: 1, name: 'Zayd')],
    });

    expect(board.gender, 2);
    expect(board.from, '2025-10-15');
    expect(board.levels, ['AMMAR', 'BILAL']);
    expect(board.total, 150);
    expect(board.students.map((s) => s.name), ['Ali', 'Zayd']);
    final ali = board.students.first;
    expect(ali.rank, 1);
    expect(ali.token, 1001);
    expect(ali.className, 'A1');
    expect(ali.recitation, 120);
  });

  test('a body that is not a leaderboard throws, so the screen can retry', () {
    expect(
      () => QuranLeaderboard.fromJson({'gender': 1}),
      throwsFormatException,
    );
    expect(() => QuranLeaderboard.fromJson('nope'), throwsFormatException);
  });

  test('a row that is not an object is skipped, a missing field is zero', () {
    final board = QuranLeaderboard.fromJson({
      'students': [
        'junk',
        {'name': 'Ali'},
      ],
    });

    expect(board.students, hasLength(1));
    expect(board.students.single.rank, 0);
    expect(board.students.single.recitation, 0);
    expect(board.gender, 1);
    expect(board.levels, isEmpty);
  });
}
