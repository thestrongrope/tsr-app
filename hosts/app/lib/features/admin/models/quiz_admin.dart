// The quiz admin (Grand and Mega) as the API sends it (#673): `GET /admin/quiz`
// and the answers of the actions. Shapes: docs/specs/quiz-admin-mobile/plan.md,
// "Wire shapes, as built".
//
// Strict about the envelope, tolerant about the parts: a body that is not an
// object throws, so the screen can say the state could not be read; a missing
// or mistyped field reads as empty, never as an error. Winners are reduced to
// what the screen counts, plus the winners themselves for the reveal (#674).

String? _textOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

String _text(Object? value) => value is String ? value : '';

int _int(Object? value) => value is int ? value : 0;

int? _intOrNull(Object? value) => value is int ? value : null;

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const <String, dynamic>{};

List<Object?> _list(Object? value) => value is List ? value : const [];

/// The quiz's kind decides which actions exist: a Mega quiz has daily draws,
/// the overall and TSR-student Mega winners and the public sheet; a Grand
/// quiz has its own draw and reset and nothing to push.
enum QuizKind { mega, grand }

class QuizEpisode {
  const QuizEpisode({required this.episode, this.start, this.stop});

  final int episode;
  final String? start;
  final String? stop;

  static QuizEpisode fromJson(Object? json) {
    final map = _map(json);
    return QuizEpisode(
      episode: _int(map['episode']),
      start: _textOrNull(map['start']),
      stop: _textOrNull(map['stop']),
    );
  }
}

class QuizSettings {
  const QuizSettings({
    required this.loaded,
    required this.kind,
    this.series,
    this.title,
    this.mode,
    this.registration,
    this.stop,
    this.megaMinimum,
    this.episodes = const [],
    this.winnerCounts = const [],
    this.winnerLabels = const [],
    this.colors = const {},
  });

  /// False until a Refresh has filled the server's cache.
  final bool loaded;
  final QuizKind kind;
  final String? series;
  final String? title;
  final String? mode;
  final String? registration;
  final String? stop;
  final int? megaMinimum;
  final List<QuizEpisode> episodes;
  final List<int> winnerCounts;
  final List<String> winnerLabels;

  /// The sheet's colours by name (`heading`, `sub_heading`, `odd`, `even`,
  /// `background`, `text`, `heading_text`), as the sheet wrote them.
  final Map<String, String> colors;

  static QuizSettings fromJson(Object? json) {
    final map = _map(json);
    return QuizSettings(
      loaded: map['loaded'] == true,
      kind: map['kind'] == 'grand' ? QuizKind.grand : QuizKind.mega,
      series: _textOrNull(map['series']),
      title: _textOrNull(map['title']),
      mode: _textOrNull(map['mode']),
      registration: _textOrNull(map['registration']),
      stop: _textOrNull(map['stop']),
      megaMinimum: _intOrNull(map['mega_minimum']),
      episodes: _list(map['episodes']).map(QuizEpisode.fromJson).toList(),
      winnerCounts: _list(map['winner_counts']).whereType<int>().toList(),
      winnerLabels: _list(map['winner_labels']).whereType<String>().toList(),
      colors: {
        for (final entry in _map(map['colors']).entries)
          if (_textOrNull(entry.value) != null)
            entry.key: entry.value as String,
      },
    );
  }
}

/// When something last happened and who did it (the name only).
class QuizStamp {
  const QuizStamp({this.at, this.by});

  final String? at;
  final String? by;

  static QuizStamp? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return QuizStamp(at: _textOrNull(json['at']), by: _textOrNull(json['by']));
  }
}

class QuizSubmissions {
  const QuizSubmissions({required this.episode, required this.submissions});

  final int episode;
  final int submissions;

  static QuizSubmissions fromJson(Object? json) {
    final map = _map(json);
    return QuizSubmissions(
      episode: _int(map['episode']),
      submissions: _int(map['submissions']),
    );
  }

  static List<QuizSubmissions> listFromJson(Object? json) =>
      _list(json).map(fromJson).toList();
}

class QuizDownload {
  const QuizDownload({this.at, this.by, this.submissions = const []});

  final String? at;
  final String? by;
  final List<QuizSubmissions> submissions;

  static QuizDownload? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return QuizDownload(
      at: _textOrNull(json['at']),
      by: _textOrNull(json['by']),
      submissions: QuizSubmissions.listFromJson(json['submissions']),
    );
  }
}

/// One started episode: how many submissions survive each step, against the
/// winners needed. `blocked` carries the reason.
class QuizEligibility {
  const QuizEligibility({
    required this.episode,
    required this.submitted,
    required this.afterDedup,
    required this.members,
    required this.countryAllowed,
    required this.notExcluded,
    required this.passing,
    required this.needed,
    required this.status,
    this.reason,
  });

  final int episode;
  final int submitted;
  final int afterDedup;
  final int members;
  final int countryAllowed;
  final int notExcluded;
  final int passing;
  final int needed;

  /// `ok`, `blocked` or `not_started`.
  final String status;
  final String? reason;

  bool get blocked => status == 'blocked';

  static QuizEligibility fromJson(Object? json) {
    final map = _map(json);
    return QuizEligibility(
      episode: _int(map['episode']),
      submitted: _int(map['submitted']),
      afterDedup: _int(map['after_dedup']),
      members: _int(map['members']),
      countryAllowed: _int(map['country_allowed']),
      notExcluded: _int(map['not_excluded']),
      passing: _int(map['passing']),
      needed: _int(map['needed']),
      status: _text(map['status']),
      reason: _textOrNull(map['reason']),
    );
  }
}

/// Whether an action may run now, and why not. `offered` is only sent for the
/// overall Mega winner; every other gate is always offered.
class QuizGate {
  const QuizGate({required this.allowed, this.reason, this.offered = true});

  final bool allowed;
  final String? reason;
  final bool offered;

  static QuizGate fromJson(Object? json) {
    final map = _map(json);
    return QuizGate(
      allowed: map['allowed'] == true,
      reason: _textOrNull(map['reason']),
      offered: map['offered'] != false,
    );
  }
}

class QuizGates {
  const QuizGates({
    required this.generate,
    required this.mega,
    required this.megaStudent,
  });

  final QuizGate generate;
  final QuizGate mega;
  final QuizGate megaStudent;

  /// Nothing allowed, nothing offered: what a body with no gates reads as.
  static const closed = QuizGates(
    generate: QuizGate(allowed: false),
    mega: QuizGate(allowed: false, offered: false),
    megaStudent: QuizGate(allowed: false),
  );

  static QuizGates fromJson(Object? json) {
    final map = _map(json);
    return QuizGates(
      generate: QuizGate.fromJson(map['generate']),
      // A missing overall Mega gate is not offered, never offered by default.
      mega: map['mega'] is Map<String, dynamic>
          ? QuizGate.fromJson(map['mega'])
          : const QuizGate(allowed: false, offered: false),
      megaStudent: QuizGate.fromJson(map['mega_student']),
    );
  }
}

/// One drawn winner, as the reveal shows them. `known` is false when the
/// member record could not be found.
class QuizWinner {
  const QuizWinner({
    required this.prize,
    required this.label,
    required this.rank,
    required this.token,
    required this.name,
    required this.city,
    required this.known,
  });

  final int prize;
  final String label;
  final int rank;
  final int token;
  final String name;
  final String city;
  final bool known;

  static QuizWinner fromJson(Object? json) {
    final map = _map(json);
    return QuizWinner(
      prize: _int(map['prize']),
      label: _text(map['label']),
      rank: _int(map['rank']),
      token: _int(map['token']),
      name: _text(map['name']),
      city: _text(map['city']),
      known: map['known'] == true,
    );
  }
}

/// The winners drawn so far: who, and per episode how many.
class QuizWinnerCounts {
  const QuizWinnerCounts({
    this.episodes = const {},
    this.megaDrawn = false,
    this.megaStudentDrawn = false,
    this.byEpisode = const {},
    this.mega = const [],
    this.megaStudent = const [],
  });

  /// Episode number to the number of winners drawn for it.
  final Map<int, int> episodes;
  final bool megaDrawn;
  final bool megaStudentDrawn;

  /// Episode number to its winners; an episode with none is absent.
  final Map<int, List<QuizWinner>> byEpisode;
  final List<QuizWinner> mega;
  final List<QuizWinner> megaStudent;

  static List<QuizWinner> _winnersIn(Object? entry) =>
      _list(_map(entry)['winners']).map(QuizWinner.fromJson).toList();

  static QuizWinnerCounts fromJson(Object? json) {
    final map = _map(json);
    final episodes = <int, int>{};
    final byEpisode = <int, List<QuizWinner>>{};
    for (final entry in _list(map['episodes'])) {
      final winners = _winnersIn(entry);
      final episode = _intOrNull(_map(entry)['episode']);
      if (episode != null && winners.isNotEmpty) {
        episodes[episode] = winners.length;
        byEpisode[episode] = winners;
      }
    }
    final mega = _winnersIn(map['mega']);
    final megaStudent = _winnersIn(map['mega_student']);
    return QuizWinnerCounts(
      episodes: episodes,
      megaDrawn: mega.isNotEmpty,
      megaStudentDrawn: megaStudent.isNotEmpty,
      byEpisode: byEpisode,
      mega: mega,
      megaStudent: megaStudent,
    );
  }
}

class QuizAdminState {
  const QuizAdminState({
    required this.settings,
    required this.quizDay,
    required this.download,
    required this.eligibility,
    required this.gates,
    required this.winners,
    required this.activity,
    required this.canReset,
  });

  final QuizSettings settings;
  final int quizDay;
  final QuizDownload? download;
  final List<QuizEligibility> eligibility;
  final QuizGates gates;
  final QuizWinnerCounts winners;

  /// Name (`winners_generated`, `mega_published`, ...) to when and by whom.
  final Map<String, QuizStamp> activity;

  /// The server's own answer; the delete-all control follows the
  /// `quiz:reset` permission, and the server refuses it either way.
  final bool canReset;

  static QuizAdminState fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Quiz admin state is not an object');
    }
    final activity = <String, QuizStamp>{};
    _map(json['activity']).forEach((name, value) {
      final stamp = QuizStamp.fromJson(value);
      if (stamp != null) activity[name] = stamp;
    });
    return QuizAdminState(
      settings: QuizSettings.fromJson(json['settings']),
      quizDay: _int(json['quiz_day']),
      download: QuizDownload.fromJson(json['download']),
      eligibility: _list(
        json['eligibility'],
      ).map(QuizEligibility.fromJson).toList(),
      gates: json['gates'] is Map<String, dynamic>
          ? QuizGates.fromJson(json['gates'])
          : QuizGates.closed,
      winners: QuizWinnerCounts.fromJson(json['winners']),
      activity: activity,
      canReset: json['can_reset'] == true,
    );
  }
}

/// One episode and prize of a draw: how many were drawn and how many were
/// short. Mega rows have no episode.
class QuizDrawRow {
  const QuizDrawRow({
    required this.episode,
    required this.prize,
    required this.drawn,
    required this.missing,
  });

  final int? episode;
  final int prize;
  final int drawn;
  final int missing;

  static QuizDrawRow fromJson(Object? json) {
    final map = _map(json);
    return QuizDrawRow(
      episode: _intOrNull(map['episode']),
      prize: _int(map['prize']),
      drawn: _int(map['drawn']),
      missing: _int(map['missing']),
    );
  }
}

/// What an action answered. `complete` is the only outcome that is not a
/// shortfall; `changed` is false when nothing was written.
class QuizActionResult {
  const QuizActionResult({
    required this.complete,
    required this.message,
    required this.changed,
    this.drawn,
    this.missing,
    this.rows,
    this.draws = const [],
  });

  final bool complete;
  final String message;
  final bool changed;

  /// Draws only.
  final int? drawn;
  final int? missing;
  final List<QuizDrawRow> draws;

  /// Publishes only: the rows written.
  final int? rows;

  static QuizActionResult fromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['message'] is! String) {
      throw const FormatException('Quiz admin action has no message');
    }
    return QuizActionResult(
      complete: json['outcome'] == 'complete',
      message: json['message'] as String,
      changed: json['changed'] == true,
      drawn: _intOrNull(json['drawn']),
      missing: _intOrNull(json['missing']),
      rows: _intOrNull(json['rows']),
      draws: _list(json['episodes']).map(QuizDrawRow.fromJson).toList(),
    );
  }
}
