import 'package:flutter/material.dart';

/// A search box for the reports list and for the class lists inside a report
/// (#576). Filtering is the caller's, with [matchesSearch].
class ReportSearchField extends StatelessWidget {
  const ReportSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
  });

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search),
      isDense: true,
    ),
  );
}

/// Whether any of [fields] contains [query], ignoring case and surrounding
/// spaces. An empty query matches everything.
bool matchesSearch(String query, Iterable<String> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => f.toLowerCase().contains(q));
}
