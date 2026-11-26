import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/models.dart';

/// Reusable attendance list widget for the conduction form.
///
/// Shows regular and extra students with present/absent toggles,
/// recitation score selectors, and search/filter functionality.
class ConductionAttendanceSheet extends StatefulWidget {
  final List<ConductionStudent> students;
  final List<ConductionStudent> extraStudents;
  final ValueChanged<List<ConductionStudent>> onStudentsChanged;
  final ValueChanged<List<ConductionStudent>> onExtraStudentsChanged;
  final bool enabled;

  const ConductionAttendanceSheet({
    super.key,
    required this.students,
    required this.extraStudents,
    required this.onStudentsChanged,
    required this.onExtraStudentsChanged,
    this.enabled = true,
  });

  @override
  State<ConductionAttendanceSheet> createState() =>
      _ConductionAttendanceSheetState();
}

class _ConductionAttendanceSheetState extends State<ConductionAttendanceSheet> {
  String _searchQuery = '';

  List<ConductionStudent> get _filteredStudents {
    if (_searchQuery.isEmpty) return widget.students;
    return widget.students
        .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<ConductionStudent> get _filteredExtraStudents {
    if (_searchQuery.isEmpty) return widget.extraStudents;
    return widget.extraStudents
        .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  int get _presentCount =>
      widget.students.where((s) => s.present).length +
      widget.extraStudents.where((s) => s.present).length;

  int get _totalCount => widget.students.length + widget.extraStudents.length;

  void _toggleAllPresent(bool present) {
    widget.onStudentsChanged(
      widget.students.map((s) => s.withPresent(present)).toList(),
    );
    widget.onExtraStudentsChanged(
      widget.extraStudents.map((s) => s.withPresent(present)).toList(),
    );
  }

  void _updateStudent(int index, ConductionStudent updated) {
    final list = List<ConductionStudent>.from(widget.students);
    // Find the actual index (not filtered)
    final realIndex = widget.students.indexWhere(
      (s) => s.token == updated.token,
    );
    if (realIndex >= 0) {
      list[realIndex] = updated;
      widget.onStudentsChanged(list);
    }
  }

  void _updateExtraStudent(int index, ConductionStudent updated) {
    final list = List<ConductionStudent>.from(widget.extraStudents);
    final realIndex = widget.extraStudents.indexWhere(
      (s) => s.token == updated.token,
    );
    if (realIndex >= 0) {
      list[realIndex] = updated;
      widget.onExtraStudentsChanged(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with summary
        _buildHeader(context),
        const SizedBox(height: 12),

        // Search bar
        _buildSearchBar(context),
        const SizedBox(height: 16),

        // Regular students
        if (_filteredStudents.isNotEmpty) ...[
          _buildSectionLabel(
            context,
            'Students',
            count: widget.students.length,
          ),
          const SizedBox(height: 8),
          ..._filteredStudents.asMap().entries.map(
            (e) => _StudentRow(
              student: e.value,
              enabled: widget.enabled,
              onTogglePresent: (present) {
                _updateStudent(e.key, e.value.withPresent(present));
              },
              onRecitationChanged: (recitation) {
                _updateStudent(e.key, e.value.withRecitation(recitation));
              },
            ),
          ),
        ],

        // Extra students
        if (_filteredExtraStudents.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSectionLabel(
            context,
            'Extra Students',
            count: widget.extraStudents.length,
          ),
          const SizedBox(height: 8),
          ..._filteredExtraStudents.asMap().entries.map(
            (e) => _StudentRow(
              student: e.value,
              enabled: widget.enabled,
              isExtra: true,
              onTogglePresent: (present) {
                _updateExtraStudent(e.key, e.value.withPresent(present));
              },
              onRecitationChanged: (recitation) {
                _updateExtraStudent(e.key, e.value.withRecitation(recitation));
              },
            ),
          ),
        ],

        if (_filteredStudents.isEmpty && _filteredExtraStudents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 48,
                    color: AppTheme.lightText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No students in this class'
                        : 'No students matching "$_searchQuery"',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final allPresent = _presentCount == _totalCount && _totalCount > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.08),
            AppTheme.primaryGreen.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_alt_rounded,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_presentCount / $_totalCount present',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
                ),
              ],
            ),
          ),
          if (widget.enabled && _totalCount > 0)
            TextButton.icon(
              onPressed: () => _toggleAllPresent(!allPresent),
              icon: Icon(
                allPresent ? Icons.deselect_rounded : Icons.select_all_rounded,
                size: 18,
              ),
              label: Text(allPresent ? 'Deselect All' : 'Select All'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search students...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () => setState(() => _searchQuery = ''),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String label, {
    required int count,
  }) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
      ],
    );
  }
}

/// Individual student row in the attendance sheet.
class _StudentRow extends StatelessWidget {
  final ConductionStudent student;
  final bool enabled;
  final bool isExtra;
  final ValueChanged<bool> onTogglePresent;
  final ValueChanged<int> onRecitationChanged;

  const _StudentRow({
    required this.student,
    required this.enabled,
    this.isExtra = false,
    required this.onTogglePresent,
    required this.onRecitationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: student.present
            ? AppTheme.successGreen.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: student.present
              ? AppTheme.successGreen.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Present/Absent toggle
          GestureDetector(
            onTap: enabled ? () => onTogglePresent(!student.present) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: student.present
                    ? AppTheme.successGreen
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
                boxShadow: student.present
                    ? [
                        BoxShadow(
                          color: AppTheme.successGreen.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                student.present ? Icons.check_rounded : Icons.close_rounded,
                color: student.present ? Colors.white : Colors.grey.shade500,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isExtra)
                  Text(
                    'Extra Student',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Recitation score
          if (student.present) ...[
            const SizedBox(width: 8),
            _RecitationSelector(
              studentName: student.name,
              value: student.recitation,
              enabled: enabled,
              onChanged: onRecitationChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// Recitation selector that allows typing any Para number (0–30+),
/// stepper adjustments, and one-tap presets.
class _RecitationSelector extends StatelessWidget {
  final String? studentName;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _RecitationSelector({
    this.studentName,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  void _openRecitationDialog(BuildContext context) {
    final controller = TextEditingController(
      text: value > 0 ? value.toString() : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Quran Recitation',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (studentName != null) ...[
                  Text(
                    'Student: $studentName',
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  'Type the Para / Siparah number or recitation score:',
                  style: TextStyle(color: AppTheme.mediumText, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Stepper + Text Input
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () {
                        final current =
                            int.tryParse(controller.text.trim()) ?? 0;
                        if (current > 0) {
                          final newVal = (current - 1).toString();
                          controller.text = newVal;
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: newVal.length),
                          );
                          setDialogState(() {});
                        }
                      },
                      icon: const Icon(Icons.remove),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.lightGreen,
                        foregroundColor: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: 'Para ',
                          prefixStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.mediumText,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD,
                            ),
                            borderSide: BorderSide(
                              color: AppTheme.primaryGreen,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () {
                        final current =
                            int.tryParse(controller.text.trim()) ?? 0;
                        final newVal = (current + 1).toString();
                        controller.text = newVal;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: newVal.length),
                        );
                        setDialogState(() {});
                      },
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.lightGreen,
                        foregroundColor: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Quick Presets
                Text(
                  'Quick Presets:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mediumText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [0, 1, 2, 3, 5, 10, 15, 20, 25, 30].map((preset) {
                    final isCurrent =
                        (int.tryParse(controller.text.trim()) ?? 0) == preset;
                    return InkWell(
                      onTap: () {
                        final str = preset.toString();
                        controller.text = str;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: str.length),
                        );
                        setDialogState(() {});
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.primaryGreen
                              : AppTheme.lightGreen,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrent
                                ? AppTheme.primaryGreen
                                : AppTheme.primaryGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          preset == 0 ? 'None (0)' : 'Para $preset',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? Colors.white
                                : AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim()) ?? 0;
                onChanged(parsed < 0 ? 0 : parsed);
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
              ),
              child: const Text('Set Recitation'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value > 0;
    return InkWell(
      onTap: enabled ? () => _openRecitationDialog(context) : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: hasValue ? const Color(0xFFFFF8E1) : AppTheme.lightGreen,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(
            color: hasValue
                ? const Color(0xFFFFB300)
                : AppTheme.primaryGreen.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 14,
              color: hasValue ? const Color(0xFFE65100) : AppTheme.primaryGreen,
            ),
            const SizedBox(width: 4),
            Text(
              hasValue ? 'Para $value' : 'Para 0',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: hasValue
                    ? const Color(0xFFE65100)
                    : AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.edit_rounded,
              size: 11,
              color: hasValue ? const Color(0xFFE65100) : AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }
}
