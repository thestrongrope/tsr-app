import 'package:flutter/material.dart';

/// Months as the report routes take them: `MM-YYYY`. Shared by the weekly and
/// summary screens (#569, #570).
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

/// The current month and the [count] - 1 before it, newest first.
List<String> lastMonths(int count) {
  final now = DateTime.now();
  return [
    for (var i = 0; i < count; i++)
      () {
        final d = DateTime(now.year, now.month - i);
        return '${d.month.toString().padLeft(2, '0')}-${d.year}';
      }(),
  ];
}

/// `09-2026` as `Sep 2026`.
String monthLabel(String month) {
  final parts = month.split('-');
  return '${_monthNames[int.parse(parts[0]) - 1]} ${parts[1]}';
}

/// `MM-YYYY` as a number that sorts and compares.
int monthKey(String month) {
  final parts = month.split('-');
  return int.parse(parts[1]) * 12 + int.parse(parts[0]);
}

/// One end of a month range: a labelled dropdown of [months].
class MonthDropdown extends StatelessWidget {
  const MonthDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.months,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> months;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    key: ValueKey('$label-$value'),
    decoration: InputDecoration(labelText: label),
    items: [
      for (final m in months)
        DropdownMenuItem(value: m, child: Text(monthLabel(m))),
    ],
    onChanged: (m) {
      if (m != null) onChanged(m);
    },
  );
}
