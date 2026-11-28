// `GET /reports/quran-leaderboard` (#404): the same ranking as the web page
// quran_recitation_leaderboard.php, from the server's QuranRecitationModel.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not this report throws, so the screen offers a retry.

/// One ranked student. Students who recited the same amount share a rank.
class LeaderboardStudent {
  const LeaderboardStudent({
    required this.rank,
    required this.name,
    required this.token,
    required this.className,
    required this.recitation,
  });

  final int rank;
  final String name;
  final int token;
  final String className;
  final int recitation;

  factory LeaderboardStudent.fromJson(Map<String, dynamic> json) =>
      LeaderboardStudent(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        token: (json['token'] as num?)?.toInt() ?? 0,
        className: json['class'] as String? ?? '',
        recitation: (json['recitation'] as num?)?.toInt() ?? 0,
      );
}

class QuranLeaderboard {
  const QuranLeaderboard({
    required this.gender,
    required this.from,
    required this.to,
    required this.levels,
    required this.total,
    required this.students,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// `YYYY-MM-DD`, the first and last day of the period.
  final String from;
  final String to;
  final List<String> levels;

  /// Everyone ranked in the period; [students] holds only the top of them.
  final int total;
  final List<LeaderboardStudent> students;

  /// Throws [FormatException] when [body] is not this report.
  factory QuranLeaderboard.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['students'] is! List) {
      throw const FormatException('quran leaderboard: unexpected response');
    }
    return QuranLeaderboard(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      from: body['from'] as String? ?? '',
      to: body['to'] as String? ?? '',
      levels: [
        if (body['levels'] is List)
          for (final level in body['levels'] as List)
            if (level is String) level,
      ],
      total: (body['total'] as num?)?.toInt() ?? 0,
      students: [
        for (final s in body['students'] as List)
          if (s is Map<String, dynamic>) LeaderboardStudent.fromJson(s),
      ],
    );
  }
}
