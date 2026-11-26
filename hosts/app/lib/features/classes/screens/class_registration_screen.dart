import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/custom_back_button.dart';
import '../widgets/class_loading_skeleton.dart';
import '../models/class_registration.dart';
import '../providers/class_registration_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Native class request form.
///
/// Replaces the old screen that opened the (non-existent)
/// `class-registration.php` URL in a browser. Submits to the PHP API layer's
/// POST /registration, which wraps the existing `tsr_class.php` /
/// `tsr_class_save.php` web form — so admin review pages keep working.
class ClassRegistrationScreen extends ConsumerStatefulWidget {
  const ClassRegistrationScreen({super.key});

  @override
  ConsumerState<ClassRegistrationScreen> createState() =>
      _ClassRegistrationScreenState();
}

class _ClassRegistrationScreenState
    extends ConsumerState<ClassRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ---- Required ----
  final _preferredLocationController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _islamicStudyYearsController = TextEditingController();

  // ---- Optional ----
  final _linkedinUrlController = TextEditingController();
  final _residenceLocationController = TextEditingController();
  final _workLocationController = TextEditingController();

  // ---- Education & Qualification ----
  String? _education;
  final Set<String> _fieldOfStudy = {};
  final _fieldOfStudyOtherController = TextEditingController();
  final Set<String> _professionalCourses = {};
  final _professionalCoursesOtherController = TextEditingController();

  // ---- Occupation ----
  String? _occupationType;
  String? _fieldOfWork;
  String? _yearsExperience;
  String? _roleLevel;

  // ---- Skills & Interests ----
  final Set<int> _interestIds = {};
  final _otherInterestsController = TextEditingController();

  // ---- Language Proficiency ----
  final Map<String, Map<String, String>> _languages = {};

  bool _submitting = false;
  bool _prefilled = false;

  // Option lists — must match the whitelists in tsr_class_save.php.
  static const List<String> _languagesList = [
    'Arabic',
    'English',
    'Gujarati',
    'Hindi',
    'Persian',
    'Urdu',
  ];
  static const List<String> _skills = ['Read', 'Speak', 'Understand', 'Write'];
  static const List<String> _proficiencyLevels = [
    "Don't Know",
    'Beginner',
    'Learning',
    'Fluent',
  ];

  static const List<String> _educationOptions = [
    'Doctorate (PhD / DPhil)',
    "Graduate (Bachelor's Degree)",
    'Islamic / Religious Studies (Hawza, Madrasah, etc.)',
    'Not Applicable / Prefer not to say',
    'Other Learning / Self-taught Skills',
    "Postgraduate (Master's Degree and above)",
    'Professional Course (CA, CFA, CS, Diploma, Certification, etc.)',
    'Undergraduate (up to Grade 14)',
  ];

  static const List<String> _fieldOfStudyOptions = [
    'Agriculture / Veterinary / Environmental Studies',
    'Arts / Humanities',
    'Commerce',
    'Design / Architecture',
    'Education',
    'Engineering / Technology (non-IT streams)',
    'Islamic / Religious Studies',
    'IT, Computer Applications, AI / ML',
    'Law',
    'Management',
    'Media / Communication',
    'Medicine / Healthcare',
    'Not Applicable / Prefer not to say',
    'Other',
    'Science',
  ];

  static const List<String> _professionalCoursesOptions = [
    'Finance & Accounting Certifications (CA, CS, CMA, ACCA, CPA, CFA, FRM)',
    'Data / Analytics',
    'Cloud Certifications (AWS / Azure / GCP)',
    'Project Management (PMP / PRINCE2 / Agile / Scrum)',
    'Six Sigma / Lean',
    'SAP / Oracle / ERP',
    'Teaching / Education Diploma',
    'Islamic Studies Certificate / Course',
    'Other',
    'Not Applicable / Prefer not to say',
  ];

  static const List<String> _occupationTypeOptions = [
    'Entrepreneur / Business Owner',
    'Homemaker',
    'Not Applicable / Prefer not to say',
    'Retired',
    'Salaried Professional',
    'Self-Employed Professional',
    'Student (School / College)',
  ];

  static const List<String> _fieldOfWorkOptions = [
    'Business / Trade / Commerce',
    'Design / Architecture / Creative Arts',
    'Digital Marketing & Social Media',
    'Education / Training',
    'Engineering / Manufacturing / Infrastructure',
    'Finance / Accounting / Banking / Insurance / Investments',
    'Government / Public Sector',
    'Human Resources (HR) / Talent / L&D / People Functions',
    'Islamic / Religious Work',
    'IT, Computer Applications, AI / ML',
    'Law / Legal Services',
    'Management / Consulting / General Administration',
    'Media & Communication',
    'Medicine / Healthcare / Pharma',
    'Not Applicable / Prefer not to say',
    'Sales and Marketing (Traditional / Offline)',
    'Social Work / Community Services',
    'Translation Services',
  ];

  static const List<String> _yearsExperienceOptions = [
    '0-1 year',
    '1-3 years',
    '3-5 years',
    '5-8 years',
    '8-12 years',
    '12+ years',
    'Not Applicable / Prefer not to say',
  ];

  static const List<String> _roleLevelOptions = [
    'Early Career / Junior Level (Intern, Trainee, Associate, Executive)',
    'Mid / Managerial Level (Senior Executive, Analyst, Specialist, AM, DM, Manager)',
    'Senior Professional / Leader Level (Senior Manager, AVP, AGM, Team Lead, Supervisor)',
    'Leadership Level (Director, Head, VP, GM)',
    'CXO Level (CEO, COO, CTO, CHRO, CFO)',
    'Business Owner / Founder / Co-founder',
    'Not Applicable / Prefer not to say',
  ];

  @override
  void dispose() {
    _preferredLocationController.dispose();
    _birthYearController.dispose();
    _islamicStudyYearsController.dispose();
    _linkedinUrlController.dispose();
    _residenceLocationController.dispose();
    _workLocationController.dispose();
    _fieldOfStudyOtherController.dispose();
    _professionalCoursesOtherController.dispose();
    _otherInterestsController.dispose();
    super.dispose();
  }

  void _initLanguages(Map<String, Map<String, String>> saved) {
    _languages.clear();
    for (final language in _languagesList) {
      final skills = <String, String>{};
      for (final skill in _skills) {
        skills[skill] = saved[language]?[skill] ?? "Don't Know";
      }
      _languages[language] = skills;
    }
  }

  void _prefill(ClassRegistrationFormData data) {
    _initLanguages(data.languages);
    final reg = data.registration;
    if (reg == null) return;

    _preferredLocationController.text = reg.preferredLocation ?? '';
    _birthYearController.text = reg.birthYear?.toString() ?? '';
    _islamicStudyYearsController.text = reg.islamicStudyYears?.toString() ?? '';
    _linkedinUrlController.text = reg.linkedinUrl ?? '';
    _residenceLocationController.text = reg.residenceLocation ?? '';
    _workLocationController.text = reg.workLocation ?? '';
    _education = reg.education;
    _fieldOfStudy
      ..clear()
      ..addAll(reg.fieldOfStudy);
    _fieldOfStudyOtherController.text = reg.fieldOfStudyOther ?? '';
    _professionalCourses
      ..clear()
      ..addAll(reg.professionalCourses);
    _professionalCoursesOtherController.text =
        reg.professionalCoursesOther ?? '';
    _occupationType = reg.occupationType;
    _fieldOfWork = reg.fieldOfWork;
    _yearsExperience = reg.yearsExperience;
    _roleLevel = reg.roleLevel;
    _interestIds
      ..clear()
      ..addAll(data.selectedInterestIds);
    _otherInterestsController.text = reg.otherInterests ?? '';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    String? nullable(String value) =>
        value.trim().isEmpty ? null : value.trim();

    final payload = <String, dynamic>{
      'preferredLocation': _preferredLocationController.text.trim(),
      'birthYear': int.tryParse(_birthYearController.text.trim()),
      'islamicStudyYears': int.tryParse(
        _islamicStudyYearsController.text.trim(),
      ),
      'linkedinUrl': nullable(_linkedinUrlController.text),
      'residenceLocation': nullable(_residenceLocationController.text),
      'workLocation': nullable(_workLocationController.text),
      'education': _education,
      'fieldOfStudy': _fieldOfStudy.toList(),
      'fieldOfStudyOther': nullable(_fieldOfStudyOtherController.text),
      'professionalCourses': _professionalCourses.toList(),
      'professionalCoursesOther': nullable(
        _professionalCoursesOtherController.text,
      ),
      'occupationType': _occupationType,
      'fieldOfWork': _fieldOfWork,
      'yearsExperience': _yearsExperience,
      'roleLevel': _roleLevel,
      'interestIds': _interestIds.toList(),
      'otherInterests': nullable(_otherInterestsController.text),
      'languages': _languages,
    };

    try {
      final repo = ref.read(classRegistrationRepositoryProvider);
      await repo.submit(payload);
      if (!mounted) return;
      // Re-fetch so the form pre-fills with what was just saved.
      ref.invalidate(classRegistrationFormProvider);
      await _showSuccessDialog();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.errorRed),
      );
    } catch (e) {
      debugPrint('Error submitting class registration: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.successGreen,
                size: 52,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Thank You!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Thanks for showing your interest. '
              'You will be contacted soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppTheme.mediumText,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formData = ref.watch(classRegistrationFormProvider);

    return Scaffold(
      backgroundColor: AppTheme.softCream,
      appBar: AppBar(
        title: const Text(
          'Class Registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
        centerTitle: true,
        leading: Center(
          child: CustomBackButton(onPressed: () => Navigator.of(context).pop()),
        ),
      ),
      body: formData.when(
        loading: () => const ClassLoadingSkeleton(),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(classRegistrationFormProvider),
        ),
        data: (data) {
          if (!_prefilled) {
            _prefilled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _prefill(data));
            });
          }
          return _buildForm(data);
        },
      ),
    );
  }

  Widget _buildForm(ClassRegistrationFormData data) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: withTabBarInset(
          context,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),

          _SectionCard(
            icon: Icons.person_outline_rounded,
            title: 'Required Information',
            children: [
              _buildTextField(
                label: 'Preferred location for offline class',
                controller: _preferredLocationController,
                hint: 'e.g., Andheri (W), Bandra (E)',
                required: true,
              ),
              _buildTextField(
                label: 'Year of Birth',
                controller: _birthYearController,
                hint: 'e.g., 2000, 2010',
                keyboardType: TextInputType.number,
                required: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your year of birth';
                  }
                  final year = int.tryParse(value.trim());
                  if (year == null ||
                      year < 1900 ||
                      year > DateTime.now().year) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
              ),
              _buildTextField(
                label: 'No. of years spent in Islamic studies',
                controller: _islamicStudyYearsController,
                hint: 'e.g., 0, 2, 5',
                keyboardType: TextInputType.number,
                required: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter years of Islamic studies';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              _buildTextField(
                label: 'LinkedIn Profile',
                controller: _linkedinUrlController,
                hint: 'https://www.linkedin.com/in/your-profile',
                keyboardType: TextInputType.url,
                helper: 'Recommended — helps us keep your profile updated',
              ),
            ],
          ),

          _SectionCard(
            icon: Icons.location_on_outlined,
            title: 'Additional Information',
            subtitle: 'Optional location details',
            children: [
              _buildTextField(
                label: 'Residence Location',
                controller: _residenceLocationController,
                hint: 'e.g., Andheri (W), Bandra (E)',
              ),
              _buildTextField(
                label: 'Work Location',
                controller: _workLocationController,
                hint: 'e.g., BKC, Lower Parel',
              ),
            ],
          ),

          _SectionCard(
            icon: Icons.school_outlined,
            title: 'Education & Qualification',
            children: [
              _buildDropdown(
                label: 'Education / Qualification',
                value: _education,
                items: _educationOptions,
                prefixIcon: Icons.school_outlined,
                helper:
                    'What is your highest level or type of education completed or currently pursuing?',
                onChanged: (v) => setState(() => _education = v),
              ),
              _buildCheckboxGroup(
                label: 'Field of Study',
                helper:
                    'Select the main academic or educational field(s) you have studied in.',
                options: _fieldOfStudyOptions,
                selected: _fieldOfStudy,
                onToggle: (option) => setState(() {
                  if (!_fieldOfStudy.add(option)) _fieldOfStudy.remove(option);
                }),
              ),
              if (_fieldOfStudy.contains('Other') ||
                  _fieldOfStudyOtherController.text.isNotEmpty)
                _buildTextField(
                  label: 'If Other field of study, please specify',
                  controller: _fieldOfStudyOtherController,
                  hint: 'Specify other field',
                ),
              _buildCheckboxGroup(
                label: 'Professional Courses',
                helper:
                    'Mention any additional professional certifications or specialised courses completed.',
                options: _professionalCoursesOptions,
                selected: _professionalCourses,
                onToggle: (option) => setState(() {
                  if (!_professionalCourses.add(option)) {
                    _professionalCourses.remove(option);
                  }
                }),
              ),
              if (_professionalCourses.contains('Other') ||
                  _professionalCoursesOtherController.text.isNotEmpty)
                _buildTextField(
                  label: 'If Other professional course, please specify',
                  controller: _professionalCoursesOtherController,
                  hint: 'Specify other certification or course',
                ),
            ],
          ),

          _SectionCard(
            icon: Icons.work_outline_rounded,
            title: 'Occupation Details',
            children: [
              _buildDropdown(
                label: 'Occupation Type',
                value: _occupationType,
                items: _occupationTypeOptions,
                prefixIcon: Icons.work_outline,
                helper:
                    'Select the category that best describes your current engagement or work situation.',
                onChanged: (v) => setState(() => _occupationType = v),
              ),
              _buildDropdown(
                label: 'Field of Work / Business',
                value: _fieldOfWork,
                items: _fieldOfWorkOptions,
                prefixIcon: Icons.business_center_outlined,
                helper:
                    'Choose the area(s) in which you currently work or conduct business.',
                onChanged: (v) => setState(() => _fieldOfWork = v),
              ),
              _buildDropdown(
                label: 'Years of Professional Experience',
                value: _yearsExperience,
                items: _yearsExperienceOptions,
                prefixIcon: Icons.timeline_outlined,
                onChanged: (v) => setState(() => _yearsExperience = v),
              ),
              _buildDropdown(
                label: 'Role / Level',
                value: _roleLevel,
                items: _roleLevelOptions,
                prefixIcon: Icons.badge_outlined,
                helper:
                    'Current seniority or level of responsibility in your work or profession.',
                onChanged: (v) => setState(() => _roleLevel = v),
              ),
            ],
          ),

          _SectionCard(
            icon: Icons.handshake_outlined,
            title: 'Skills & Interests',
            children: [
              _buildCheckboxGroup(
                label: 'Areas you can contribute to TSR',
                options: data.interestOptions.map((o) => o.name).toList(),
                selected: data.interestOptions
                    .where((o) => _interestIds.contains(o.id))
                    .map((o) => o.name)
                    .toSet(),
                onToggle: (option) => setState(() {
                  final optionId = data.interestOptions
                      .firstWhere((o) => o.name == option)
                      .id;
                  if (!_interestIds.add(optionId)) {
                    _interestIds.remove(optionId);
                  }
                }),
              ),
              if (_otherInterestsController.text.isNotEmpty ||
                  data.interestOptions.any(
                    (o) =>
                        o.name.toLowerCase().contains('other') &&
                        _interestIds.contains(o.id),
                  ))
                _buildTextField(
                  label: 'If Other interests, please specify',
                  controller: _otherInterestsController,
                  hint: 'Specify other interests or skills',
                ),
            ],
          ),

          _SectionCard(
            icon: Icons.translate_rounded,
            title: 'Language Proficiency',
            subtitle: 'Rate your proficiency in each language',
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Beginner = Know a little · Learning = Actively improving · Fluent = Fully comfortable · Don\'t know = No knowledge',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.darkText,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ..._languagesList.map(_buildLanguageRow),
            ],
          ),

          const SizedBox(height: 8),
          _buildSubmitButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Request Enrollment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'You are currently not enrolled in any class. Submit your details and our team will review your request.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
        ),
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, size: 20),
        label: Text(
          _submitting ? 'Submitting…' : 'Submit Registration',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildLanguageRow(String language) {
    final skills = _languages[language] ?? {};
    final skillWidgets = _skills.map((skill) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              key: ValueKey('lang_${language}_$skill'),
              initialValue: skills[skill] ?? "Don't Know",
              isExpanded: true,
              isDense: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppTheme.primaryGreen,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 1.5,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 13, color: AppTheme.darkText),
              items: _proficiencyLevels
                  .map(
                    (level) => DropdownMenuItem<String>(
                      value: level,
                      child: Text(
                        level,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (level) {
                if (level == null) return;
                setState(() {
                  _languages[language]?[skill] = level;
                });
              },
            ),
          ],
        ),
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.softCream.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                language,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              skillWidgets[0],
              const SizedBox(width: 10),
              skillWidgets[1],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              skillWidgets[2],
              const SizedBox(width: 10),
              skillWidgets[3],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? helper,
    TextInputType? keyboardType,
    bool required = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.mediumText,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: AppTheme.darkText),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppTheme.mediumText,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryGreen,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.errorRed,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.errorRed,
                  width: 2,
                ),
              ),
            ),
            validator:
                validator ??
                (required
                    ? (value) => (value == null || value.trim().isEmpty)
                          ? 'Please enter $label'
                          : null
                    : null),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? helper,
    IconData? prefixIcon,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  required ? '$label *' : label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.mediumText,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('dd_${label}_$value'),
            initialValue: value,
            isExpanded: true,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.primaryGreen,
            ),
            decoration: InputDecoration(
              hintText: 'Tap to select…',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppTheme.mediumText,
              ),
              filled: true,
              fillColor: AppTheme.lightGreen.withValues(alpha: 0.35),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryGreen,
                  width: 2,
                ),
              ),
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkText,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxGroup({
    required String label,
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
              ),
              if (selected.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${selected.length} selected',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.mediumText,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.darkText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => onToggle(option),
                selectedColor: AppTheme.lightGreen,
                checkmarkColor: AppTheme.primaryGreen,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.dividerColor,
                  width: isSelected ? 1.5 : 1.0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkText,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.mediumText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppTheme.dividerColor),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
