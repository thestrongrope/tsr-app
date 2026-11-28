import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/quran_leaderboard.dart';
import '../providers/reports_provider.dart';
import '../widgets/level_filter.dart';
import '../../../core/widgets/tab_bar_inset.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The Quran recitation leaderboard (#404), the mobile counterpart of the web's
/// quran_recitation_leaderboard.php: the top students by recitation over a
/// period, opening on the last year. The server decides which gender the user
/// may see; the file carries every ranked student.
class QuranLeaderboardScreen extends ConsumerStatefulWidget {
  const QuranLeaderboardScreen({super.key});

  @override
  ConsumerState<QuranLeaderboardScreen> createState() =>
      _QuranLeaderboardScreenState();
}

class _QuranLeaderboardScreenState
    extends ConsumerState<QuranLeaderboardScreen> {
  int? _gender;
  // The last year, as the web page opens.
  late DateTime _to = DateTime.now();
  late DateTime _from = DateTime(_to.year - 1, _to.month, _to.day);
  String? _level;
  bool _sharing = false;

  // The fewest recitations to be listed; 1 as on the web page. The field is
  // outside the list, so it stays editable when nobody meets the minimum.
  int _minimum = 1;
  final _minimumController = TextEditingController(text: '1');
  Timer? _minimumDebounce;

  QuranLeaderboardQuery get _query => (
    gender: _gender,
    from: _date(_from),
    to: _date(_to),
    level: _level,
    minimum: _minimum,
  );

  @override
  void dispose() {
    _minimumDebounce?.cancel();
    _minimumController.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing, then asks again. Blank or invalid is 1.
  void _minimumChanged(String text) {
    _minimumDebounce?.cancel();
    _minimumDebounce = Timer(const Duration(milliseconds: 400), () {
      final typed = int.tryParse(text.trim());
      final minimum = (typed == null || typed < 0) ? 1 : typed;
      if (mounted && minimum != _minimum) setState(() => _minimum = minimum);
    });
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2021, 11),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null) return;
    setState(() {
      _from = range.start;
      _to = range.end;
    });
  }

  Future<void> _share(ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareQuranLeaderboardProvider)(_query, format);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'The file could not be prepared. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesLeaderboardGender;
    final board = ref.watch(quranLeaderboardProvider(_query));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Quran leaderboard'),
        actions: [
          if (board.asData case AsyncData(
            :final value,
          ) when value.students.isNotEmpty)
            PopupMenuButton<ReportFormat>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              enabled: !_sharing,
              onSelected: _share,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: ReportFormat.xlsx,
                  child: Text('Share as Excel'),
                ),
                PopupMenuItem(
                  value: ReportFormat.pdf,
                  child: Text('Share as PDF'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          if (choosesGender) ...[
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Gents')),
                ButtonSegment(value: 2, label: Text('Ladies')),
              ],
              selected: {_gender ?? board.asData?.value.gender ?? 1},
              onSelectionChanged: (choice) => setState(() {
                _gender = choice.first;
                _level = null;
              }),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _pickDates,
            icon: const Icon(Icons.date_range),
            label: Text('${_date(_from)} to ${_date(_to)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('quran-minimum'),
            controller: _minimumController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Minimum recitations',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _minimumChanged,
          ),
          const SizedBox(height: 12),
          ...board.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              const Text('The leaderboard could not be loaded.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(quranLeaderboardProvider(_query)),
                  child: const Text('Try again'),
                ),
              ),
            ],
            data: _body,
          ),
        ],
      ),
    );
  }

  List<Widget> _body(QuranLeaderboard data) {
    return [
      if (data.levels.length > 1) ...[
        LevelFilter(
          levels: data.levels,
          selected: _level,
          onChanged: (level) => setState(() => _level = level),
        ),
        const SizedBox(height: 12),
      ],
      if (data.students.isEmpty)
        Text(
          _minimum > 1
              ? 'No member has $_minimum or more recitations in this period.'
              : 'Nobody recited in this period.',
        )
      else ...[
        Text(
          data.total > data.students.length
              ? 'Top ${data.students.length} of ${data.total} students. '
                    'Share the file for everyone.'
              : '${data.total} students',
        ),
        const SizedBox(height: 12),
        for (final s in data.students) _StudentCard(student: s),
      ],
    ];
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student});

  final LeaderboardStudent student;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text('${student.rank}')),
        title: Text(
          student.name,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${student.className} · token ${student.token}',
          style: muted,
        ),
        trailing: Text(
          '${student.recitation}',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
