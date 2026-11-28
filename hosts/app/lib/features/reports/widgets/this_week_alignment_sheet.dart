import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/this_week.dart';
import '../providers/reports_provider.dart';

/// What one class taught in each of the last eight weeks (#615), newest first.
/// A look, not a verdict: for a level with a Standard Syllabus Chart the chart
/// is there to read it against, and nothing is scored.
class ThisWeekAlignmentSheet extends ConsumerWidget {
  const ThisWeekAlignmentSheet({
    super.key,
    required this.classId,
    required this.code,
  });

  final int classId;
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alignment = ref.watch(classAlignmentProvider(classId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Last 8 weeks: $code',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...alignment.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              const Text('This class could not be loaded.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(classAlignmentProvider(classId)),
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

  List<Widget> _body(ClassAlignment data) => [
    for (final week in data.weeks) _WeekTile(week: week),
    const SizedBox(height: 8),
    if (data.chart == null)
      const Text('No chart for this level yet')
    else
      ExpansionTile(
        title: const Text('Standard Syllabus Chart'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final subject in data.chart!.entries) ...[
            Text(
              _label(subject.key),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            for (final group in (subject.value as Map).keys)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text('$group'),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
  ];
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({required this.week});

  final AlignmentWeek week;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${week.from} to ${week.to}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            switch (week.status) {
              'taught' => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final topic in week.subjects.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 80, child: Text(_label(topic.key))),
                          Expanded(child: Text(topic.value)),
                        ],
                      ),
                    ),
                ],
              ),
              'no class' => const Text('No class'),
              _ => const Text('No form'),
            },
          ],
        ),
      ),
    );
  }
}

/// `ahkam` as `Ahkam`.
String _label(String subject) =>
    subject.isEmpty ? subject : subject[0].toUpperCase() + subject.substring(1);
