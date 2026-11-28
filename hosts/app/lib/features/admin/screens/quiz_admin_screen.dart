import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/utils/api_datetime.dart';
import '../models/quiz_admin.dart';
import '../providers/quiz_admin_provider.dart';
import '../repositories/quiz_admin_repository.dart';
import 'quiz_winners_reveal_screen.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Runs the Grand and Mega quizzes (#673), the mobile counterpart of the web's
/// quiz admin page: settings, the scoreboard download and who is eligible, the
/// draws, and the push to the public sheet.
///
/// The server decides everything: what is blocked and why (`gates`), whether
/// the overall Mega winner is offered, which draws a quiz has. This screen
/// shows those answers, asks before anything is lost or published, and says
/// what every action did. Winner names appear only in the reveal (#674), opened
/// from the Winners section.
class QuizAdminScreen extends ConsumerStatefulWidget {
  const QuizAdminScreen({super.key});

  @override
  ConsumerState<QuizAdminScreen> createState() => _QuizAdminScreenState();
}

enum _Tone { done, warning, error }

class _Outcome {
  const _Outcome(this.tone, this.lines);

  final _Tone tone;
  final List<String> lines;
}

class _QuizAdminScreenState extends ConsumerState<QuizAdminScreen> {
  /// True while an action is in flight: every action is disabled meanwhile.
  bool _running = false;
  _Outcome? _outcome;

  static const _timedOut =
      'The request timed out, so the result is unknown. The state below was '
      'reloaded: check it before trying again.';

  QuizAdminRepository get _repo => ref.read(quizAdminRepositoryProvider);

  /// Runs one action, says what happened, and reloads the state: after a
  /// timeout the server may have finished, so the screen asks it.
  Future<void> _run(Future<QuizActionResult> Function() call) async {
    setState(() {
      _running = true;
      _outcome = null;
    });
    _Outcome outcome;
    try {
      outcome = _describe(await call());
    } catch (e) {
      outcome = quizAdminTimedOut(e)
          ? const _Outcome(_Tone.warning, [_timedOut])
          : _Outcome(_Tone.error, [quizAdminErrorMessage(e)]);
    }
    ref.invalidate(quizAdminStateProvider);
    if (!mounted) return;
    setState(() {
      _running = false;
      _outcome = outcome;
    });
  }

  _Outcome _describe(QuizActionResult result) {
    final lines = [result.message];
    final drawn = result.drawn;
    final missing = result.missing;
    if (drawn != null && missing != null) {
      lines.add('Drawn $drawn, missing $missing.');
      for (final row in result.draws.where((r) => r.missing > 0)) {
        final where = row.episode == null
            ? 'Mega'
            : 'Episode ${row.episode}, prize ${row.prize}';
        lines.add('$where: drawn ${row.drawn}, missing ${row.missing}.');
      }
    }
    return _Outcome(result.complete ? _Tone.done : _Tone.warning, lines);
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            key: const Key('quiz-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('quiz-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return sure == true && mounted;
  }

  Future<void> _confirmThenRun({
    required String title,
    required String body,
    required String confirmLabel,
    required Future<QuizActionResult> Function() call,
  }) async {
    if (await _confirm(title: title, body: body, confirmLabel: confirmLabel)) {
      await _run(call);
    }
  }

  // The confirmations: each says what is lost or published.

  static const _kept = 'The replaced winners are kept in a record.';

  Future<void> _regenerate(String kind, QuizAdminState state) {
    final String title;
    final String body;
    switch (kind) {
      case 'daily':
        final n = state.winners.episodes.length;
        title = 'Regenerate the daily winners?';
        body =
            'This draws again for every started episode and replaces the '
            'daily winners drawn so far ($n ${n == 1 ? 'episode has' : 'episodes have'} '
            'winners now). $_kept';
      case 'grand':
        final n = state.winners.episodes.length;
        title = 'Reset the Grand winners?';
        body =
            'This draws the Grand winners again and replaces every Grand '
            'winner drawn so far ($n ${n == 1 ? 'episode has' : 'episodes have'} '
            'winners now). $_kept';
      case 'mega':
        title = 'Regenerate the overall Mega winner?';
        body = 'The overall Mega winner drawn now is replaced. $_kept';
      default:
        title = 'Regenerate the TSR-student Mega winner?';
        body = 'The TSR-student Mega winner drawn now is replaced. $_kept';
    }
    return _confirmThenRun(
      title: title,
      body: body,
      confirmLabel: kind == 'grand' ? 'Reset' : 'Regenerate',
      call: () => _repo.regenerate(kind),
    );
  }

  Future<void> _publish(String what) {
    final String title;
    final String body;
    switch (what) {
      case 'scoreboard':
        title = 'Publish the scoreboard?';
        body =
            'This writes the current scoreboard to the public sheet, '
            'replacing what is shown there now.';
      case 'winners':
        title = 'Publish the daily winners?';
        body =
            'This writes the daily winners drawn so far to the public '
            'sheet, replacing what is shown there now.';
      case 'mega':
        title = 'Publish the overall Mega winner?';
        body =
            'This writes the overall Mega winner to the public sheet, '
            'replacing what is shown there now.';
      default:
        title = 'Publish the TSR-student Mega winner?';
        body =
            'This writes the TSR-student Mega winner to the public sheet, '
            'replacing what is shown there now.';
    }
    return _confirmThenRun(
      title: title,
      body: '$body Everyone who can open the sheet will see it.',
      confirmLabel: 'Publish',
      call: () => _repo.publish(what),
    );
  }

  Future<void> _deleteAll() => _confirmThenRun(
    title: 'Delete all quiz data?',
    body:
        'This deletes the downloaded submissions, the quiz day, the '
        'scoreboard, every winner drawn (daily, Grand, Mega and '
        'TSR-student) and the download and draw times. It cannot be '
        'undone. $_kept',
    confirmLabel: 'Delete all',
    call: _repo.deleteAll,
  );

  // Building blocks.

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  /// A button, and under it why it cannot be pressed (the gate's reason).
  Widget _action({
    required Key key,
    required String label,
    required VoidCallback onPressed,
    bool allowed = true,
    String? reason,
    bool filled = false,
    bool danger = false,
  }) {
    final enabled = allowed && !_running;
    final style = danger
        ? OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          )
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: filled
                ? FilledButton(
                    key: key,
                    onPressed: enabled ? onPressed : null,
                    child: Text(label),
                  )
                : OutlinedButton(
                    key: key,
                    style: style,
                    onPressed: enabled ? onPressed : null,
                    child: Text(label),
                  ),
          ),
          if (!allowed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                reason ?? 'Not available yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  static String _stamp(QuizStamp stamp) {
    final by = stamp.by == null ? '' : ' by ${stamp.by}';
    return '${formatApiLocalDateTime(stamp.at)}$by';
  }

  Widget _line(String label, String? value) => value == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('$label: $value'),
        );

  // Sections.

  Widget _settings(QuizSettings s) {
    final counts = <String>[];
    for (var i = 0; i < s.winnerCounts.length; i++) {
      final label = i < s.winnerLabels.length
          ? s.winnerLabels[i]
          : 'Prize ${i + 1}';
      counts.add('$label ${s.winnerCounts[i]}');
    }
    return _section('Settings', [
      if (!s.loaded)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'The settings have not been loaded yet. Refresh them from the '
            'settings sheet.',
          ),
        ),
      _line('Quiz', s.kind == QuizKind.grand ? 'Grand' : 'Mega'),
      _line('Series', s.series),
      _line('Title', s.title),
      _line('Mode', s.mode),
      _line('Registration', s.registration),
      _line('Stops', s.stop),
      _line('Episodes', s.episodes.isEmpty ? null : '${s.episodes.length}'),
      _line('Winners per episode', counts.isEmpty ? null : counts.join(', ')),
      _line('Mega minimum', s.megaMinimum?.toString()),
      const SizedBox(height: 8),
      _action(
        key: const Key('quiz-refresh'),
        label: 'Refresh settings',
        onPressed: () => _run(_repo.refreshSettings),
      ),
    ]);
  }

  Widget _scoreboard(QuizAdminState state) {
    final download = state.download;
    return _section('Scoreboard', [
      _line('Quiz day', state.quizDay > 0 ? '${state.quizDay}' : 'not started'),
      if (download == null)
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('Not downloaded yet.'),
        )
      else ...[
        _line(
          'Last downloaded',
          _stamp(QuizStamp(at: download.at, by: download.by)),
        ),
        for (final row in download.submissions)
          Text('Episode ${row.episode}: ${row.submissions} submissions'),
      ],
      const SizedBox(height: 8),
      _action(
        key: const Key('quiz-download'),
        label: 'Download submissions',
        filled: true,
        onPressed: () => _run(_repo.download),
      ),
      if (state.eligibility.isNotEmpty) _eligibility(state.eligibility),
    ]);
  }

  Widget _eligibility(List<QuizEligibility> rows) {
    String status(QuizEligibility r) => switch (r.status) {
      'ok' => 'OK',
      'blocked' => 'Blocked',
      _ => 'Not started',
    };
    return Column(
      key: const Key('quiz-eligibility'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Eligibility', style: Theme.of(context).textTheme.titleSmall),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Ep')),
              DataColumn(label: Text('Submitted'), numeric: true),
              DataColumn(label: Text('Unique'), numeric: true),
              DataColumn(label: Text('Members'), numeric: true),
              DataColumn(label: Text('Country ok'), numeric: true),
              DataColumn(label: Text('Not excluded'), numeric: true),
              DataColumn(label: Text('Passing'), numeric: true),
              DataColumn(label: Text('Needed'), numeric: true),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final r in rows)
                DataRow(
                  cells: [
                    DataCell(Text('${r.episode}')),
                    DataCell(Text('${r.submitted}')),
                    DataCell(Text('${r.afterDedup}')),
                    DataCell(Text('${r.members}')),
                    DataCell(Text('${r.countryAllowed}')),
                    DataCell(Text('${r.notExcluded}')),
                    DataCell(Text('${r.passing}')),
                    DataCell(Text('${r.needed}')),
                    DataCell(Text(status(r))),
                  ],
                ),
            ],
          ),
        ),
        for (final r in rows.where((r) => r.blocked))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Episode ${r.episode} is blocked: ${r.reason ?? 'not enough eligible people'}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _winners(QuizAdminState state) {
    final grand = state.settings.kind == QuizKind.grand;
    final g = state.gates;
    final w = state.winners;
    final total = state.settings.episodes.length;
    final summary = grand
        ? 'Grand winners drawn for ${w.episodes.length} of $total episodes.'
        : 'Daily winners drawn for ${w.episodes.length} of $total episodes.';

    final actions = grand
        ? <Widget>[
            _action(
              key: const Key('quiz-generate-grand'),
              label: 'Generate Grand winners',
              filled: true,
              allowed: g.generate.allowed,
              reason: g.generate.reason,
              onPressed: () => _run(() => _repo.generate('grand')),
            ),
            _action(
              key: const Key('quiz-regenerate-grand'),
              label: 'Reset Grand winners',
              allowed: g.generate.allowed,
              reason: g.generate.reason,
              onPressed: () => _regenerate('grand', state),
            ),
          ]
        : <Widget>[
            _action(
              key: const Key('quiz-generate-daily'),
              label: 'Generate daily winners',
              filled: true,
              allowed: g.generate.allowed,
              reason: g.generate.reason,
              onPressed: () => _run(() => _repo.generate('daily')),
            ),
            _action(
              key: const Key('quiz-regenerate-daily'),
              label: 'Regenerate daily winners',
              allowed: g.generate.allowed,
              reason: g.generate.reason,
              onPressed: () => _regenerate('daily', state),
            ),
            if (g.mega.offered) ...[
              const Divider(),
              _action(
                key: const Key('quiz-generate-mega'),
                label: 'Generate overall Mega winner',
                filled: true,
                allowed: g.mega.allowed,
                reason: g.mega.reason,
                onPressed: () => _run(() => _repo.generate('mega')),
              ),
              _action(
                key: const Key('quiz-regenerate-mega'),
                label: 'Regenerate overall Mega winner',
                allowed: g.mega.allowed,
                reason: g.mega.reason,
                onPressed: () => _regenerate('mega', state),
              ),
            ],
            const Divider(),
            _action(
              key: const Key('quiz-generate-mega_student'),
              label: 'Generate TSR-student Mega winner',
              filled: true,
              allowed: g.megaStudent.allowed,
              reason: g.megaStudent.reason,
              onPressed: () => _run(() => _repo.generate('mega_student')),
            ),
            _action(
              key: const Key('quiz-regenerate-mega_student'),
              label: 'Regenerate TSR-student Mega winner',
              allowed: g.megaStudent.allowed,
              reason: g.megaStudent.reason,
              onPressed: () => _regenerate('mega_student', state),
            ),
          ];

    return _section('Winners', [
      Text(summary),
      const SizedBox(height: 12),
      ...actions,
      const Divider(),
      ..._revealButtons(state),
    ]);
  }

  void _openReveal(
    QuizAdminState state,
    String heading,
    List<QuizWinner> winners,
  ) {
    // The root navigator, so the tab bar does not stay under the reveal.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => QuizWinnersRevealScreen(
          quizTitle: state.settings.title,
          heading: heading,
          winners: winners,
          colors: state.settings.colors,
        ),
      ),
    );
  }

  /// A button per drawn set of winners: a Grand quiz only has its own, a Mega
  /// quiz has each episode's daily winners and the two Mega winners. The
  /// reveal gets a copy of the winners as they are now.
  List<Widget> _revealButtons(QuizAdminState state) {
    final grand = state.settings.kind == QuizKind.grand;
    final w = state.winners;
    final episodes = w.byEpisode.keys.toList()..sort();
    final buttons = <Widget>[
      for (final episode in episodes)
        _revealButton(
          key: 'quiz-reveal-episode-$episode',
          label: grand
              ? 'Reveal Grand winners, episode $episode'
              : 'Reveal daily winners, episode $episode',
          onPressed: () => _openReveal(
            state,
            grand
                ? 'Grand winners, episode $episode'
                : 'Daily winners, episode $episode',
            w.byEpisode[episode]!,
          ),
        ),
      if (!grand && w.megaDrawn)
        _revealButton(
          key: 'quiz-reveal-mega',
          label: 'Reveal overall Mega winner',
          onPressed: () => _openReveal(state, 'Mega winner', w.mega),
        ),
      if (!grand && w.megaStudentDrawn)
        _revealButton(
          key: 'quiz-reveal-mega_student',
          label: 'Reveal TSR-student Mega winner',
          onPressed: () =>
              _openReveal(state, 'TSR-student Mega winner', w.megaStudent),
        ),
    ];
    if (buttons.isEmpty) {
      return const [
        Text(
          'No winners have been drawn yet, so there is nothing to reveal.',
          key: Key('quiz-reveal-none'),
        ),
      ];
    }
    return buttons;
  }

  Widget _revealButton({
    required String key,
    required String label,
    required VoidCallback onPressed,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton.icon(
      key: Key(key),
      icon: const Icon(Icons.slideshow),
      label: Text(label),
      onPressed: onPressed,
    ),
  );

  /// Mega only: Grand has nothing to push.
  Widget _publishing(QuizAdminState state) {
    final w = state.winners;
    final g = state.gates;
    return _section('Public sheet', [
      _action(
        key: const Key('quiz-publish-scoreboard'),
        label: 'Publish scoreboard',
        onPressed: () => _publish('scoreboard'),
      ),
      _action(
        key: const Key('quiz-publish-winners'),
        label: 'Publish daily winners',
        allowed: w.episodes.isNotEmpty,
        reason: 'No daily winners have been drawn yet.',
        onPressed: () => _publish('winners'),
      ),
      if (g.mega.offered)
        _action(
          key: const Key('quiz-publish-mega'),
          label: 'Publish overall Mega winner',
          allowed: w.megaDrawn,
          reason: 'The overall Mega winner has not been drawn yet.',
          onPressed: () => _publish('mega'),
        ),
      _action(
        key: const Key('quiz-publish-mega_student'),
        label: 'Publish TSR-student Mega winner',
        allowed: w.megaStudentDrawn,
        reason: 'The TSR-student Mega winner has not been drawn yet.',
        onPressed: () => _publish('mega_student'),
      ),
    ]);
  }

  static const _activityLabels = {
    'scoreboard_published': 'Scoreboard published',
    'winners_generated': 'Daily winners drawn',
    'winners_reset': 'Winners reset',
    'winners_published': 'Daily winners published',
    'mega_generated': 'Mega winner drawn',
    'mega_reset': 'Mega winner reset',
    'mega_published': 'Mega winner published',
    'mega_student_generated': 'TSR-student Mega winner drawn',
    'mega_student_reset': 'TSR-student Mega winner reset',
    'mega_student_published': 'TSR-student Mega winner published',
  };

  Widget _activity(QuizAdminState state) {
    final rows = [
      for (final entry in _activityLabels.entries)
        if (state.activity[entry.key] != null)
          _line(entry.value, _stamp(state.activity[entry.key]!)),
    ];
    return rows.isEmpty ? const SizedBox.shrink() : _section('Activity', rows);
  }

  Widget _outcomeBanner() {
    final outcome = _outcome;
    if (outcome == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (outcome.tone) {
      _Tone.done => (Icons.check_circle_outline, Colors.green),
      _Tone.warning => (Icons.warning_amber_outlined, Colors.orange),
      _Tone.error => (Icons.error_outline, scheme.error),
    };
    return Padding(
      key: const Key('quiz-outcome'),
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final line in outcome.lines) Text(line)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(QuizAdminState state, bool canReset) {
    final grand = state.settings.kind == QuizKind.grand;
    return SingleChildScrollView(
      padding: withTabBarInset(context, const EdgeInsets.all(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_running)
            const Padding(
              key: Key('quiz-working'),
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Working, this can take a minute.')),
                ],
              ),
            ),
          _outcomeBanner(),
          _settings(state.settings),
          _scoreboard(state),
          _winners(state),
          if (!grand) _publishing(state),
          _activity(state),
          if (canReset)
            _section('Delete', [
              _action(
                key: const Key('quiz-delete-all'),
                label: 'Delete all quiz data',
                danger: true,
                onPressed: _deleteAll,
              ),
            ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quizAdminStateProvider);
    final canReset = ref.watch(capabilitiesProvider).canResetQuiz;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz admin')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is ApiException
                      ? quizAdminErrorMessage(e)
                      : 'The quiz could not be loaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('quiz-retry'),
                  onPressed: () => ref.invalidate(quizAdminStateProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _body(data, canReset),
      ),
    );
  }
}
