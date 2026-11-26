// `GET /standard-mcqs/sources` and `POST /standard-mcqs/update` (#669): the
// languages and levels whose Standard MCQs can be replaced from the source
// sheet, and what happened to each pair.
//
// Strict about the envelope, tolerant about the rows: a body that is not this
// answer throws, so the screen can say the update did not work.

String _text(Object? value) => value is String ? value : '';

int _int(Object? value) => value is int ? value : 0;

/// A language or a level: the id the update sends, and the name shown.
class McqChoice {
  const McqChoice({required this.id, required this.name});

  final int id;
  final String name;

  static McqChoice fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return McqChoice(id: _int(map['id']), name: _text(map['name']));
  }
}

class StandardMcqSources {
  const StandardMcqSources({required this.languages, required this.levels});

  final List<McqChoice> languages;
  final List<McqChoice> levels;

  static List<McqChoice> _choices(Object? list) =>
      list is List ? list.map(McqChoice.fromJson).toList() : <McqChoice>[];

  static StandardMcqSources fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Standard MCQ sources is not an object');
    }
    return StandardMcqSources(
      languages: _choices(json['languages']),
      levels: _choices(json['levels']),
    );
  }
}

/// One language and level: updated with its quiz count, or failed with why.
class StandardMcqResult {
  const StandardMcqResult({
    required this.language,
    required this.level,
    required this.updated,
    this.quizzes,
    this.reason,
  });

  final String language;
  final String level;
  final bool updated;
  final int? quizzes;
  final String? reason;

  static StandardMcqResult fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final reason = _text(map['reason']);
    return StandardMcqResult(
      language: _text(map['language']),
      level: _text(map['level']),
      updated: map['status'] == 'updated',
      quizzes: map['quizzes'] is int ? map['quizzes'] as int : null,
      reason: reason.isEmpty ? null : reason,
    );
  }

  static List<StandardMcqResult> listFromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['results'] is! List) {
      throw const FormatException('Standard MCQ update is not a results list');
    }
    return (json['results'] as List).map(fromJson).toList();
  }
}
