import 'dart:math';

import 'package:flutter/material.dart';

import '../models/quiz_admin.dart';

/// The winners announcement (#674): one full-screen page per reveal, in the
/// quiz's own colours, with each prize's names uncovered when the admin taps
/// its Reveal button. The web's `show_winners.php` did this; the app is where
/// it lives now.
///
/// It is built from the winners handed to it, never from a provider, so a
/// refresh behind it cannot change what the audience is looking at. Opening
/// the reveal again reads the newest winners.
class QuizWinnersRevealScreen extends StatelessWidget {
  const QuizWinnersRevealScreen({
    super.key,
    required this.quizTitle,
    required this.heading,
    required this.winners,
    required this.colors,
  });

  /// The quiz's title from its settings, if the sheet has one.
  final String? quizTitle;

  /// What is being revealed: "Daily winners, episode 3", "Mega winner".
  final String heading;
  final List<QuizWinner> winners;

  /// The sheet's colours by name, as written; unreadable ones fall back.
  final Map<String, String> colors;

  /// `#rgb`, `#rrggbb` or the same without the `#`; anything else is null.
  static Color? parseColor(String? text) {
    if (text == null) return null;
    var hex = text.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
    if (hex.length != 6) return null;
    final value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  Color _color(String name, Color fallback) =>
      parseColor(colors[name]) ?? fallback;

  /// Winners by prize, the highest prize first, as the web showed them.
  Map<int, List<QuizWinner>> _byPrize() {
    final byPrize = <int, List<QuizWinner>>{};
    for (final winner in winners) {
      byPrize.putIfAbsent(winner.prize, () => []).add(winner);
    }
    final prizes = byPrize.keys.toList()..sort((a, b) => b.compareTo(a));
    return {
      for (final prize in prizes)
        prize: byPrize[prize]!..sort((a, b) => a.rank.compareTo(b.rank)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = (width / 60).clamp(14.0, 36.0);
    final background = _color('background', const Color(0xFFFFFFFF));
    final headingColor = _color('heading', const Color(0xFF222222));
    final style = _RevealStyle(
      scale: scale,
      heading: headingColor,
      subHeading: _color('sub_heading', const Color(0xFFDDDDDD)),
      headingText: _color('heading_text', const Color(0xFF222222)),
      odd: _color('odd', const Color(0xFFF2F2F2)),
      even: _color('even', const Color(0xFFFFFFFF)),
      text: _color('text', const Color(0xFF222222)),
      background: background,
    );
    final prizes = _byPrize();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
                  children: [
                    if (quizTitle != null)
                      Text(
                        quizTitle!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: headingColor,
                          fontSize: scale * 1.6,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                    Text(
                      heading,
                      key: const Key('reveal-heading'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: headingColor,
                        fontSize: scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    for (final entry in prizes.entries)
                      _PrizeSection(
                        key: ValueKey('reveal-prize-${entry.key}'),
                        prize: entry.key,
                        winners: entry.value,
                        style: style,
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                key: const Key('reveal-close'),
                tooltip: 'Close',
                icon: Icon(Icons.close, color: headingColor),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealStyle {
  const _RevealStyle({
    required this.scale,
    required this.heading,
    required this.subHeading,
    required this.headingText,
    required this.odd,
    required this.even,
    required this.text,
    required this.background,
  });

  final double scale;
  final Color heading;
  final Color subHeading;
  final Color headingText;
  final Color odd;
  final Color even;
  final Color text;
  final Color background;
}

/// One prize: its heading, a Reveal button, and the winners' rows, blank until
/// revealed and then scrambled into place over three seconds.
class _PrizeSection extends StatefulWidget {
  const _PrizeSection({
    super.key,
    required this.prize,
    required this.winners,
    required this.style,
  });

  final int prize;
  final List<QuizWinner> winners;
  final _RevealStyle style;

  @override
  State<_PrizeSection> createState() => _PrizeSectionState();
}

class _PrizeSectionState extends State<_PrizeSection>
    with SingleTickerProviderStateMixin {
  static const _scrambleChars = 'zpxVpasdfh86136░█▒▓>';

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  final _random = Random();
  bool _started = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal() {
    setState(() => _started = true);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  String _name(QuizWinner winner) =>
      winner.known ? winner.name : 'Unknown member';

  /// The text of every uncovered cell, in reading order; the scramble moves
  /// through them one character at a time.
  List<String> _cells() => [
    for (final winner in widget.winners) ...[
      '${winner.token}',
      _name(winner),
      winner.city,
    ],
  ];

  List<String> _shown(double progress) {
    final cells = _cells();
    final total = cells.fold<int>(0, (sum, cell) => sum + cell.length);
    var left = (progress * total).floor();
    final shown = <String>[];
    for (final cell in cells) {
      if (progress >= 1 || left >= cell.length) {
        shown.add(cell);
      } else if (left > 0) {
        shown.add(
          cell.substring(0, left) +
              _scrambleChars[_random.nextInt(_scrambleChars.length)],
        );
      } else {
        shown.add('');
      }
      left = max(0, left - cell.length);
    }
    return shown;
  }

  Widget _cell(String text, double scale, Color color, {bool italic = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(
          text.isEmpty ? ' ' : text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: scale,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final scale = style.scale;
    final label = widget.winners.first.label.isEmpty
        ? 'Prize'
        : widget.winners.first.label;
    final plural = widget.winners.length > 1 ? 's' : '';

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shown = _started ? _shown(_controller.value) : null;
          return Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 24,
                children: [
                  Text(
                    '$label Prize Winner$plural',
                    style: TextStyle(
                      color: style.heading,
                      fontSize: scale * 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  FilledButton(
                    key: Key('reveal-button-${widget.prize}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: style.heading,
                      foregroundColor: style.background,
                    ),
                    onPressed: _started ? null : _reveal,
                    child: Text(_started ? 'Revealed' : 'Reveal'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(4),
                  3: FlexColumnWidth(3),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: style.subHeading),
                    children: [
                      for (final title in ['Rank', 'Token', 'Name', 'City'])
                        _cell(title, scale, style.headingText),
                    ],
                  ),
                  for (var i = 0; i < widget.winners.length; i++)
                    TableRow(
                      key: ValueKey('reveal-row-${widget.prize}-$i'),
                      decoration: BoxDecoration(
                        color: i.isEven ? style.even : style.odd,
                      ),
                      children: [
                        _cell('${widget.winners[i].rank}', scale, style.text),
                        _cell(shown?[i * 3] ?? '', scale, style.text),
                        _cell(
                          shown?[i * 3 + 1] ?? '',
                          scale,
                          style.text,
                          italic: !widget.winners[i].known,
                        ),
                        _cell(shown?[i * 3 + 2] ?? '', scale, style.text),
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
