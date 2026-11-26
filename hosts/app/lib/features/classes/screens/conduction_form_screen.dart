import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/saved_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../models/models.dart';
import '../widgets/class_loading_skeleton.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/content_width_cap.dart';
import '../providers/providers.dart';
import '../utils/topic_codec.dart';
import '../widgets/conduction_attendance_sheet.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Combined Add/Edit screen for class conduction records.
///
/// In **add** mode, loads form data (students, Quran surahs, next dates) from
/// the API. In **edit** mode, loads the existing session + attendance.
class ConductionFormScreen extends ConsumerStatefulWidget {
  final int classId;
  final int? sessionId; // null = add, non-null = edit

  const ConductionFormScreen({
    super.key,
    required this.classId,
    this.sessionId,
  });

  bool get isEdit => sessionId != null;

  @override
  ConsumerState<ConductionFormScreen> createState() =>
      _ConductionFormScreenState();
}

class _ConductionFormScreenState extends ConsumerState<ConductionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form state
  DateTime? _conductedOn;
  bool _conducted = true;
  int _duration = 60;
  int? _quranSurahId;
  int? _quranVerse;
  String _nonConductionReason = '';

  /// `class_level_id` of Miqdad, the level whose Arabic, Aqaed, Ahkam and
  /// Akhlaq sessions are compulsory.
  static const _miqdadLevelId = 3;

  /// The hour and minute buttons of the web form: 1 to 4 hours, then 0, 15, 30
  /// or 45 minutes on top. The −/+ stepper below them is for anything else.
  static const _durationHours = [0, 1, 2, 3, 4];
  static const _durationMinutes = [0, 15, 30, 45];

  // Subject toggles and topics
  bool _arabicConducted = false;
  bool _aqaedConducted = false;
  bool _ahkamConducted = false;
  bool _akhlaqConducted = false;
  bool _otherConducted = false;
  String _arabicTopic = '';
  String _aqaedTopic = '';
  String _ahkamTopic = '';
  String _akhlaqTopic = '';
  String _otherTopic = '';

  /// The syllabus this class's level offers, and the dropdown state it drives.
  ///
  /// A subject missing from [_catalog] keeps the plain topic text field. That
  /// is the normal case: only Miqdad has a syllabus, so every other level — and
  /// a request that failed — shows exactly the form teachers had before.
  SyllabusTopics _catalog = const {};
  final Map<String, TopicSelection> _topicSelections = {};

  // Attendance
  List<ConductionStudent> _students = [];
  List<ConductionStudent> _extraStudents = [];

  // UI state
  bool _isSubmitting = false;
  bool _initialized = false;
  ConductionDateCheck? _dateCheck;

  // Quran surahs cache
  List<HolyQuranSurah> _holyQuran = [];

  @override
  Widget build(BuildContext context) {
    // Load form data
    if (widget.isEdit) {
      return _buildEditMode(context);
    }
    return _buildAddMode(context);
  }

  Widget _buildAddMode(BuildContext context) {
    // Both watched before either is waited on, so the two requests overlap
    // rather than queueing behind each other.
    final catalog = _watchCatalog();
    final formDataAsync = ref.watch(conductionFormDataProvider(widget.classId));
    if (catalog == null) return _buildLoadingScaffold(context);

    return formDataAsync.when(
      data: (formData) {
        _initializeFromFormData(formData, catalog);
        return _buildScaffold(context, formData.classInfo);
      },
      loading: () => _buildLoadingScaffold(context),
      error: (error, _) => _buildErrorScaffold(context, error),
    );
  }

  Widget _buildEditMode(BuildContext context) {
    final catalog = _watchCatalog();
    final editDataAsync = ref.watch(
      conductionSessionProvider((
        classId: widget.classId,
        sessionId: widget.sessionId!,
      )),
    );
    // The session payload carries the surah list, but an older server may not —
    // fall back to the shared list so the Quran section still appears.
    final fallbackQuranAsync = ref.watch(holyQuranProvider);
    if (catalog == null) return _buildLoadingScaffold(context);

    return editDataAsync.when(
      data: (editData) {
        _initializeFromEditData(editData, catalog);
        if (_holyQuran.isEmpty && fallbackQuranAsync.asData?.value != null) {
          _holyQuran = fallbackQuranAsync.asData!.value;
        }
        return _buildScaffold(context, editData.classInfo);
      },
      loading: () => _buildLoadingScaffold(context),
      error: (error, _) => _buildErrorScaffold(context, error),
    );
  }

  /// The syllabus catalog, or null while it is still being fetched.
  ///
  /// The wait is worth blocking on because a stored topic cannot be split back
  /// into its dropdown parts without the catalog, so the form must not be built
  /// before it lands. A catalog that fails to arrive is an empty one, which is
  /// the free-text form — never an error screen.
  SyllabusTopics? _watchCatalog() {
    final async = ref.watch(syllabusTopicsProvider(widget.classId));
    if (async.isLoading) return null;
    return async.asData?.value ?? const <String, SubjectCatalog>{};
  }

  void _initializeFromFormData(
    ConductionFormData formData,
    SyllabusTopics catalog,
  ) {
    if (_initialized) return;
    _initialized = true;

    _catalog = catalog;
    _conductedOn = formData.nextSessionDate ?? DateTime.now();
    _holyQuran = formData.holyQuran;
    // The Surah starts on the class's last one. A Surah that is no longer in
    // the list starts empty (the dropdown cannot hold a value it has no item for).
    if (_holyQuran.any((surah) => surah.id == formData.latestSurah)) {
      _quranSurahId = formData.latestSurah;
    }
    // The default date is checked like a chosen one: the form can open on a date
    // that already has a record, for instance a second Add Record in one session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkDate(_conductedOn!);
    });

    // Start a new record from whatever the class last covered in each subject,
    // which is almost always what the teacher is about to build on. The prefill
    // offers a topic, it does not claim the subject was taught, so the subject
    // checkboxes stay clear, except for Miqdad's compulsory four (below).
    _arabicTopic = formData.latestTopics['arabic'] ?? '';
    _aqaedTopic = formData.latestTopics['aqaed'] ?? '';
    _ahkamTopic = formData.latestTopics['ahkam'] ?? '';
    _akhlaqTopic = formData.latestTopics['akhlaq'] ?? '';
    _otherTopic = formData.latestTopics['other'] ?? '';
    _hydrateTopicSelections();

    // Miqdad's four compulsory subjects start ticked; the teacher unticks the
    // ones this session skipped. Other levels start clear.
    if (formData.classInfo?.level == _miqdadLevelId) {
      _arabicConducted = true;
      _aqaedConducted = true;
      _ahkamConducted = true;
      _akhlaqConducted = true;
    }

    if (formData.classInfo != null) {
      _students = List.from(formData.classInfo!.students);
      _extraStudents = List.from(formData.classInfo!.extraStudents);
    }
  }

  void _initializeFromEditData(
    ConductionEditData editData,
    SyllabusTopics catalog,
  ) {
    if (_initialized) return;
    _initialized = true;

    _catalog = catalog;
    _holyQuran = editData.holyQuran;

    final session = editData.session;
    if (session != null) {
      _conductedOn = session.conductedOn;
      _conducted = session.conducted;
      _duration = session.duration ?? 60;
      _quranSurahId = session.quranRecitationSurah;
      _quranVerse = session.quranRecitationVerse;
      _nonConductionReason = session.nonConductionReason ?? '';
      _arabicConducted = session.arabicConducted;
      _aqaedConducted = session.aqaedConducted;
      _ahkamConducted = session.ahkamConducted;
      _akhlaqConducted = session.akhlaqConducted;
      _otherConducted = session.otherConducted;
      _arabicTopic = session.arabicTopic ?? '';
      _aqaedTopic = session.aqaedTopic ?? '';
      _ahkamTopic = session.ahkamTopic ?? '';
      _akhlaqTopic = session.akhlaqTopic ?? '';
      _otherTopic = session.otherTopic ?? '';
    }

    _hydrateTopicSelections();

    _students = List.from(editData.attendance.where((s) => !s.extra));
    _extraStudents = List.from(editData.attendance.where((s) => s.extra));
  }

  /// Splits each stored topic back into the parts its dropdowns show.
  ///
  /// Only subjects the catalog covers: for the others the stored value stays
  /// exactly as it is, in the text field.
  void _hydrateTopicSelections() {
    final stored = {
      'arabic': _arabicTopic,
      'aqaed': _aqaedTopic,
      'ahkam': _ahkamTopic,
      'akhlaq': _akhlaqTopic,
      'other': _otherTopic,
    };

    for (final entry in stored.entries) {
      final subjectCatalog = _catalog[entry.key];
      if (subjectCatalog == null || subjectCatalog.isEmpty) continue;
      _topicSelections[entry.key] = hydrateTopicSelection(
        entry.value,
        subjectCatalog,
      );
    }
  }

  /// Records a dropdown change and re-flattens it into the value that is saved.
  void _onSelectionChanged(
    String subject,
    TopicSelection selection,
    ValueChanged<String> assign,
  ) {
    setState(() {
      _topicSelections[subject] = selection;
      assign(composeTopic(selection, _catalog[subject] ?? const {}));
    });
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Conduction' : 'Add Conduction'),
      ),
      body: const ContentWidthCap(child: ClassLoadingSkeleton()),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, Object error) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Conduction' : 'Add Conduction'),
      ),
      body: ContentWidthCap(
        child: AppErrorView(
          error: error,
          onRetry: () {
            setState(() => _initialized = false);
            if (widget.isEdit) {
              ref.invalidate(conductionSessionProvider);
            } else {
              ref.invalidate(conductionFormDataProvider(widget.classId));
            }
          },
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, ConductionClass? classInfo) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Conduction' : 'Add Conduction'),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
              ),
            ),
        ],
      ),
      body: ContentWidthCap(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: withTabBarInset(context, const EdgeInsets.all(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class info header
                if (classInfo != null) _buildClassInfoCard(context, classInfo),
                const SizedBox(height: 20),

                // Date picker
                _buildDateSection(context),
                const SizedBox(height: 20),

                // Conducted toggle
                _buildConductedToggle(context),
                const SizedBox(height: 20),

                if (_conducted) ...[
                  // Duration
                  _buildDurationSection(context),
                  const SizedBox(height: 20),

                  // Quran recitation
                  if (_holyQuran.isNotEmpty) ...[
                    _buildQuranSection(context),
                    const SizedBox(height: 20),
                  ],

                  // Subjects
                  _buildSubjectsSection(context),
                  const SizedBox(height: 20),

                  // Attendance
                  _buildAttendanceSection(context),
                ] else ...[
                  // Non-conduction reason
                  _buildReasonSection(context),
                ],

                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: AppTheme.buttonHeightLarge,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Saving...'
                          : (widget.isEdit
                                ? 'Update Conduction'
                                : 'Save Conduction'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassInfoCard(BuildContext context, ConductionClass classInfo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classInfo.code,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  classInfo.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                if (classInfo.teacherName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          classInfo.teacherName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${classInfo.totalStudents} students',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(BuildContext context) {
    final dateFormatted = _conductedOn != null
        ? DateFormat('EEEE, MMM d, yyyy').format(_conductedOn!)
        : 'Select date';

    return _FormSectionCard(
      icon: Icons.calendar_today_rounded,
      title: 'Session Date',
      child: Column(
        children: [
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateFormatted,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppTheme.mediumText,
                  ),
                ],
              ),
            ),
          ),
          if (_dateCheck != null) ...[
            const SizedBox(height: 8),
            if (_dateCheck!.alreadyConducted)
              _buildWarningBanner(
                'A conduction record already exists for this date.',
                AppTheme.errorRed,
              ),
            if (_dateCheck!.sameWeek && !_dateCheck!.alreadyConducted)
              _buildWarningBanner(
                'Another session exists in the same week.',
                AppTheme.warningOrange,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningBanner(String message, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConductedToggle(BuildContext context) {
    return _FormSectionCard(
      icon: Icons.check_circle_outline_rounded,
      title: 'Class Status',
      child: Row(
        children: [
          Expanded(
            child: _ToggleOption(
              label: 'Conducted',
              icon: Icons.check_circle_rounded,
              selected: _conducted,
              color: AppTheme.successGreen,
              onTap: () => setState(() => _conducted = true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ToggleOption(
              label: 'Not Conducted',
              icon: Icons.cancel_rounded,
              selected: !_conducted,
              color: AppTheme.warningOrange,
              onTap: () => setState(() => _conducted = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSection(BuildContext context) {
    return _FormSectionCard(
      icon: Icons.timer_outlined,
      title: 'Duration (minutes)',
      child: Column(
        children: [
          _buildDurationChips(
            key: const ValueKey('durationHours'),
            label: 'Hours',
            values: _durationHours,
            selected: _duration ~/ 60,
            onSelected: (hours) => _setDuration(hours * 60 + _duration % 60),
          ),
          const SizedBox(height: 12),
          _buildDurationChips(
            key: const ValueKey('durationMinutes'),
            label: 'Minutes',
            values: _durationMinutes,
            selected: _duration % 60,
            onSelected: (minutes) =>
                _setDuration(_duration ~/ 60 * 60 + minutes),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DurationButton(
                icon: Icons.remove,
                label: 'Shorter by 15 minutes',
                onTap: () {
                  if (_duration > 15) setState(() => _duration -= 15);
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_duration min',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ),
              _DurationButton(
                icon: Icons.add,
                label: 'Longer by 15 minutes',
                onTap: () {
                  if (_duration < 300) setState(() => _duration += 15);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A duration of nothing is not a session, so 0 hours and 0 minutes is ignored.
  void _setDuration(int minutes) {
    if (minutes > 0) setState(() => _duration = minutes);
  }

  /// One row of the web form's duration buttons, as a segmented button so the
  /// segments share the card's width instead of wrapping.
  Widget _buildDurationChips({
    required Key key,
    required String label,
    required List<int> values,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            key: key,
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              for (final value in values)
                ButtonSegment<int>(value: value, label: Text('$value')),
            ],
            selected: {if (values.contains(selected)) selected},
            onSelectionChanged: (picked) {
              if (picked.isNotEmpty) onSelected(picked.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuranSection(BuildContext context) {
    // A stored surah missing from the list (stale data) would crash the
    // dropdown, so only offer it when it is actually present.
    final validSurahId = _holyQuran.any((s) => s.id == _quranSurahId)
        ? _quranSurahId
        : null;
    return _FormSectionCard(
      icon: Icons.auto_stories_rounded,
      title: 'Quran Recitation',
      child: Column(
        children: [
          // Surah dropdown
          DropdownButtonFormField<int>(
            initialValue: validSurahId,
            decoration: AppTheme.dropdownDecoration(
              label: 'Surah',
              prefixIcon: Icons.menu_book_rounded,
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<int>(
                value: null,
                child: Text('None / Not covered'),
              ),
              ..._holyQuran.map((surah) {
                return DropdownMenuItem<int>(
                  value: surah.id,
                  child: Text(
                    '${surah.id}. ${surah.surah}${surah.arabic != null ? ' (${surah.arabic})' : ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (value) => setState(() {
              _quranSurahId = value;
              // A verse only means something within a surah.
              if (value == null) _quranVerse = null;
            }),
          ),
          const SizedBox(height: 12),
          // Verse number
          TextFormField(
            // Rebuilt when the surah is cleared so the old verse disappears.
            key: ValueKey(_quranSurahId == null),
            initialValue: _quranVerse?.toString() ?? '',
            decoration: InputDecoration(
              labelText: 'Verse / Ayah number',
              prefixIcon: const Icon(Icons.tag_rounded),
              filled: true,
              fillColor: AppTheme.lightGreen,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              _quranVerse = int.tryParse(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsSection(BuildContext context) {
    return _FormSectionCard(
      icon: Icons.subject_rounded,
      title: 'Subjects Covered',
      child: Column(
        children: [
          _SubjectToggle(
            subject: 'arabic',
            label: 'Arabic',
            icon: Icons.translate_rounded,
            color: const Color(0xFF5C6BC0),
            checked: _arabicConducted,
            topic: _arabicTopic,
            catalog: _catalog['arabic'],
            selection: _topicSelections['arabic'] ?? const TopicSelection(),
            onToggle: (v) => setState(() => _arabicConducted = v),
            onTopicChanged: (v) => _arabicTopic = v,
            onSelectionChanged: (s) =>
                _onSelectionChanged('arabic', s, (v) => _arabicTopic = v),
          ),
          _SubjectToggle(
            subject: 'aqaed',
            label: 'Aqaed (Beliefs)',
            icon: Icons.lightbulb_outline_rounded,
            color: const Color(0xFF26A69A),
            checked: _aqaedConducted,
            topic: _aqaedTopic,
            catalog: _catalog['aqaed'],
            selection: _topicSelections['aqaed'] ?? const TopicSelection(),
            onToggle: (v) => setState(() => _aqaedConducted = v),
            onTopicChanged: (v) => _aqaedTopic = v,
            onSelectionChanged: (s) =>
                _onSelectionChanged('aqaed', s, (v) => _aqaedTopic = v),
          ),
          _SubjectToggle(
            subject: 'ahkam',
            label: 'Ahkam (Rulings)',
            icon: Icons.gavel_rounded,
            color: const Color(0xFFFF7043),
            checked: _ahkamConducted,
            topic: _ahkamTopic,
            catalog: _catalog['ahkam'],
            selection: _topicSelections['ahkam'] ?? const TopicSelection(),
            onToggle: (v) => setState(() => _ahkamConducted = v),
            onTopicChanged: (v) => _ahkamTopic = v,
            onSelectionChanged: (s) =>
                _onSelectionChanged('ahkam', s, (v) => _ahkamTopic = v),
          ),
          // Akhlaq and Other are free text on purpose — the syllabus has no
          // catalog for them, on the web form either.
          _SubjectToggle(
            subject: 'akhlaq',
            label: 'Akhlaq (Ethics)',
            icon: Icons.favorite_border_rounded,
            color: const Color(0xFFEC407A),
            checked: _akhlaqConducted,
            topic: _akhlaqTopic,
            onToggle: (v) => setState(() => _akhlaqConducted = v),
            onTopicChanged: (v) => _akhlaqTopic = v,
          ),
          _SubjectToggle(
            subject: 'other',
            label: 'Other',
            icon: Icons.more_horiz_rounded,
            color: const Color(0xFF78909C),
            checked: _otherConducted,
            topic: _otherTopic,
            onToggle: (v) => setState(() => _otherConducted = v),
            onTopicChanged: (v) => _otherTopic = v,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection(BuildContext context) {
    return ConductionAttendanceSheet(
      students: _students,
      extraStudents: _extraStudents,
      onStudentsChanged: (updated) => setState(() => _students = updated),
      onExtraStudentsChanged: (updated) =>
          setState(() => _extraStudents = updated),
    );
  }

  Widget _buildReasonSection(BuildContext context) {
    return _FormSectionCard(
      icon: Icons.info_outline_rounded,
      title: 'Reason for Not Conducting',
      child: TextFormField(
        initialValue: _nonConductionReason,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Please provide the reason...',
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        validator: (value) {
          if (!_conducted && (value == null || value.trim().isEmpty)) {
            return 'Reason is required when class was not conducted';
          }
          return null;
        },
        onChanged: (value) => _nonConductionReason = value,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _conductedOn ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _conductedOn = picked;
        _dateCheck = null;
      });
      _checkDate(picked);
    }
  }

  Future<void> _checkDate(DateTime date) async {
    try {
      final repo = ref.read(classesRepositoryProvider);
      final check = await repo.checkConductionDate(widget.classId, date);
      if (mounted) {
        setState(() => _dateCheck = check);
      }
    } catch (e) {
      debugPrint('Date check failed: $e');
    }
  }

  /// Closes the form, then drops the form data. It holds the date the next form
  /// opens on, so a second Add Record in the same session must not reuse the
  /// date just recorded. Done after the pop so the form being left does not
  /// fetch it again on its way out.
  void _leaveAndRefresh() {
    final container = ProviderScope.containerOf(context);
    context.pop();
    container.invalidate(conductionFormDataProvider);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_conductedOn == null) {
      AppSnackBar.showError(context, message: 'Please select a date');
      return;
    }
    if (_dateCheck?.alreadyConducted == true && !widget.isEdit) {
      AppSnackBar.showError(
        context,
        message: 'A record already exists for this date',
      );
      return;
    }

    if (!widget.isEdit) {
      final date = _conductedOn!.toIso8601String().split('T').first;
      final waiting = ref
          .read(conductionQueueProvider)
          .any((i) => i.classId == widget.classId && i.conductedOn == date);
      if (waiting) {
        AppSnackBar.showError(
          context,
          message:
              'A record for this date is already waiting on this device. '
              'Send or discard it first.',
        );
        return;
      }
    }

    if (_conducted) {
      // 1. At least one student must be present
      final anyPresent =
          _students.any((s) => s.present) ||
          _extraStudents.any((s) => s.present);
      if (!anyPresent) {
        AppSnackBar.showError(
          context,
          message: 'At least one student must be marked present',
        );
        return;
      }

      // 2. At least one subject must be covered
      final anySubject =
          _arabicConducted ||
          _aqaedConducted ||
          _ahkamConducted ||
          _akhlaqConducted ||
          _otherConducted;
      if (!anySubject) {
        AppSnackBar.showError(
          context,
          message: 'Please select at least one subject covered',
        );
        return;
      }

      // 3. For each selected subject, topic covered is compulsory
      if (_arabicConducted && _arabicTopic.trim().isEmpty) {
        AppSnackBar.showError(
          context,
          message: 'Please enter topic covered for Arabic',
        );
        return;
      }
      if (_aqaedConducted && _aqaedTopic.trim().isEmpty) {
        AppSnackBar.showError(
          context,
          message: 'Please enter topic covered for Aqaed',
        );
        return;
      }
      if (_ahkamConducted && _ahkamTopic.trim().isEmpty) {
        AppSnackBar.showError(
          context,
          message: 'Please enter topic covered for Ahkam',
        );
        return;
      }
      if (_akhlaqConducted && _akhlaqTopic.trim().isEmpty) {
        AppSnackBar.showError(
          context,
          message: 'Please enter topic covered for Akhlaq',
        );
        return;
      }
      if (_otherConducted && _otherTopic.trim().isEmpty) {
        AppSnackBar.showError(
          context,
          message: 'Please enter topic covered for Other',
        );
        return;
      }
    } else {
      // Non-conduction reason is compulsory if not conducted
      if (_nonConductionReason.trim().isEmpty) {
        AppSnackBar.showError(
          context,
          message: 'Please enter the reason why class was not conducted',
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final payload = <String, dynamic>{
      'conductedOn': _conductedOn!.toIso8601String().split('T').first,
      'conducted': _conducted,
      'duration': _conducted ? _duration : null,
      'quranRecitationSurah': _conducted ? _quranSurahId : null,
      'quranRecitationVerse': _conducted && _quranSurahId != null
          ? _quranVerse
          : null,
      'arabicConducted': _conducted && _arabicConducted,
      'aqaedConducted': _conducted && _aqaedConducted,
      'ahkamConducted': _conducted && _ahkamConducted,
      'akhlaqConducted': _conducted && _akhlaqConducted,
      'otherConducted': _conducted && _otherConducted,
      'arabicTopic': _conducted && _arabicConducted ? _arabicTopic : null,
      'aqaedTopic': _conducted && _aqaedConducted ? _aqaedTopic : null,
      'ahkamTopic': _conducted && _ahkamConducted ? _ahkamTopic : null,
      'akhlaqTopic': _conducted && _akhlaqConducted ? _akhlaqTopic : null,
      'otherTopic': _conducted && _otherConducted ? _otherTopic : null,
      'nonConductionReason': !_conducted ? _nonConductionReason : null,
      'students': _students
          .map(
            (s) => {
              'token': s.token,
              'present': s.present,
              'recitation': s.recitation,
            },
          )
          .toList(),
      'extraStudents': _extraStudents
          .map((s) => {'token': s.token, 'name': s.name, 'present': s.present})
          .toList(),
    };

    // The moment the teacher pressed save. It is the record's creation time on the
    // server and what tells a resend of this request from a second record, so the
    // queue keeps the same value if the first attempt cannot be completed.
    if (!widget.isEdit) {
      payload['recordedAt'] = DateTime.now().toUtc().toIso8601String();
    }

    try {
      final repo = ref.read(classesRepositoryProvider);
      if (widget.isEdit) {
        await repo.updateConduction(widget.classId, widget.sessionId!, payload);
      } else {
        await repo.addConduction(widget.classId, payload);
      }

      ref.invalidate(conductionSessionsProvider);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: widget.isEdit
              ? 'Conduction updated successfully'
              : 'Conduction saved successfully',
        );
        _leaveAndRefresh();
      }
    } catch (e) {
      if (!widget.isEdit && isUnreachable(e)) {
        // No network: keep the record on this device and send it later. The
        // time it was saved goes with it, so the server counts the edit window
        // from now, not from when it arrives.
        await ref
            .read(conductionQueueProvider.notifier)
            .enqueue(widget.classId, payload);
        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            message:
                'Saved on this device. It will be sent when you are online.',
          );
          _leaveAndRefresh();
        }
        return;
      }
      if (mounted) {
        AppSnackBar.showError(
          context,
          message:
              'Not saved. ${userMessage(e)} What you entered is still here; '
              'tap Save to try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

// ============ Helper Widgets ============

/// Card wrapper for form sections.
class _FormSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _FormSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Toggle option used for the conducted/not-conducted selector.
class _ToggleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? color : Colors.grey.shade400,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppTheme.mediumText,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Duration increment/decrement button.
class _DurationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DurationButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.lightGreen,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
        ),
      ),
    );
  }
}

/// Subject toggle row with the topic input it reveals when ticked.
///
/// The input is either the syllabus pickers — topic, then sub-topic, then an
/// optional detail — or a single free-text field. Which one depends on whether
/// [catalog] actually has topics for this subject, never on the subject or the
/// class: a level with no syllabus, a subject the syllabus skips and a catalog
/// that failed to load all get the text field, because a dropdown that can only
/// offer "Other" is worse than the box teachers had before.
class _SubjectToggle extends StatelessWidget {
  /// The subject's wire code, used to keep this row's field keys distinct.
  final String subject;
  final String label;
  final IconData icon;
  final Color color;
  final bool checked;

  /// The composed value that will be saved, and what the text field shows.
  final String topic;

  /// This subject's syllabus, or null when it has none.
  final SubjectCatalog? catalog;

  /// [topic] split into the parts the pickers show. Ignored without a catalog.
  final TopicSelection selection;

  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onTopicChanged;
  final ValueChanged<TopicSelection>? onSelectionChanged;

  const _SubjectToggle({
    required this.subject,
    required this.label,
    required this.icon,
    required this.color,
    required this.checked,
    required this.topic,
    required this.onToggle,
    required this.onTopicChanged,
    this.catalog,
    this.selection = const TopicSelection(),
    this.onSelectionChanged,
  });

  bool get _hasPickers =>
      catalog != null && catalog!.isNotEmpty && onSelectionChanged != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            onTap: () => onToggle(!checked),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: checked
                    ? color.withValues(alpha: 0.06)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: checked
                      ? color.withValues(alpha: 0.3)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: checked ? color : Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: checked
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: checked
                            ? AppTheme.darkText
                            : AppTheme.mediumText,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: checked ? color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: checked ? color : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: checked
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          if (checked) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: _hasPickers
                  ? _buildPickers(context)
                  : _buildFreeTextField(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFreeTextField(BuildContext context) {
    return TextFormField(
      initialValue: topic,
      decoration: _inputDecoration('Topic covered (required)...'),
      validator: (value) {
        if (checked && (value == null || value.trim().isEmpty)) {
          return 'Topic is required';
        }
        return null;
      },
      onChanged: onTopicChanged,
    );
  }

  /// Topic, then sub-topic, then an optional detail, each appearing once the one
  /// before it is answered.
  ///
  /// The two text fields carry a key that changes with the choice above them.
  /// That is what makes a reset visible: a TextFormField reads `initialValue`
  /// only when its state is created, so picking the next sub-topic would
  /// otherwise leave the previous lesson's detail on screen. The dropdowns need
  /// no such key — DropdownButtonFormField tracks `initialValue` itself.
  Widget _buildPickers(BuildContext context) {
    final topics = catalog!.keys.where((t) => t != otherTopicOption).toList();
    final isCustom = selection.topic == otherTopicOption;
    final subtopics = subtopicsFor(catalog!, selection.topic);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selection.topic.isEmpty ? null : selection.topic,
          isExpanded: true,
          decoration: AppTheme.dropdownDecoration(
            label: 'Topic',
            prefixIcon: Icons.menu_book_rounded,
          ),
          items: [
            for (final topic in topics)
              DropdownMenuItem(
                value: topic,
                child: Text(topic, overflow: TextOverflow.ellipsis),
              ),
            const DropdownMenuItem(
              value: otherTopicOption,
              child: Text('Other (not in the syllabus)'),
            ),
          ],
          validator: (value) => checked && (value == null || value.isEmpty)
              ? 'Pick a topic'
              : null,
          // Changing the topic invalidates the sub-topic and the detail below
          // it, and the custom text belongs to "Other" alone.
          onChanged: (value) =>
              onSelectionChanged!(TopicSelection(topic: value ?? '')),
        ),

        if (isCustom) ...[
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('$subject-custom'),
            initialValue: selection.custom,
            decoration: _inputDecoration('Topic covered (required)...'),
            validator: (value) =>
                checked && (value == null || value.trim().isEmpty)
                ? 'Topic is required'
                : null,
            onChanged: (value) =>
                onSelectionChanged!(selection.copyWith(custom: value)),
          ),
        ] else if (subtopics.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selection.subtopic.isEmpty
                ? null
                : selection.subtopic,
            isExpanded: true,
            decoration: AppTheme.dropdownDecoration(
              label: 'Sub-topic',
              prefixIcon: Icons.list_alt_rounded,
            ),
            items: [
              for (final subtopic in subtopics)
                DropdownMenuItem(
                  value: subtopic,
                  child: Text(subtopic, overflow: TextOverflow.ellipsis),
                ),
            ],
            validator: (value) => checked && (value == null || value.isEmpty)
                ? 'Pick a sub-topic'
                : null,
            onChanged: (value) => onSelectionChanged!(
              TopicSelection(topic: selection.topic, subtopic: value ?? ''),
            ),
          ),
        ],

        // The detail is optional, and only offered once there is a lesson for it
        // to belong to.
        if (!isCustom &&
            selection.topic.isNotEmpty &&
            (subtopics.isEmpty || selection.subtopic.isNotEmpty)) ...[
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey(
              '$subject-details-${selection.topic}-${selection.subtopic}',
            ),
            initialValue: selection.details,
            decoration: _inputDecoration('Add details (optional)...'),
            onChanged: (value) =>
                onSelectionChanged!(selection.copyWith(details: value)),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: BorderSide(color: AppTheme.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: BorderSide(color: AppTheme.errorRed, width: 2),
      ),
    );
  }
}
