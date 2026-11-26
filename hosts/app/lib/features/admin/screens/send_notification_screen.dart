import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Target type enum for notifications
enum NotificationTargetType {
  allUsers(
    'ALL_USERS',
    'All Users',
    Icons.group,
    'Send to all registered users',
  ),
  classLevel(
    'CLASS_LEVEL',
    'Class Level',
    Icons.school,
    'Target specific class levels',
  ),
  gender('GENDER', 'Gender', Icons.people, 'Target by gender'),
  teachers('TEACHERS', 'Teachers', Icons.person, 'Send to all teachers');

  final String value;
  final String label;
  final IconData icon;
  final String description;

  const NotificationTargetType(
    this.value,
    this.label,
    this.icon,
    this.description,
  );
}

/// Send Notification Screen
/// Allows super admins and gender admins to send push notifications to users
class SendNotificationScreen extends ConsumerStatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  ConsumerState<SendNotificationScreen> createState() =>
      _SendNotificationScreenState();
}

class _SendNotificationScreenState
    extends ConsumerState<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _actionLinkController = TextEditingController();

  NotificationTargetType _selectedTarget = NotificationTargetType.allUsers;
  final List<String> _selectedValues = [];
  bool _isSending = false;
  bool _isLoadingClassLevels = false;

  List<Map<String, dynamic>> _classLevels = [];

  final List<Map<String, dynamic>> _genderOptions = [
    {'id': 1, 'name': 'Male', 'icon': Icons.male},
    {'id': 2, 'name': 'Female', 'icon': Icons.female},
  ];

  @override
  void initState() {
    super.initState();
    _fetchClassLevels();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _actionLinkController.dispose();
    super.dispose();
  }

  Future<void> _fetchClassLevels() async {
    setState(() => _isLoadingClassLevels = true);

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get<List<dynamic>>('/class-levels');

      setState(() {
        _classLevels = response
            .map(
              (level) => {
                'id': level['id'].toString(),
                'name': level['name'] ?? 'Level ${level['id']}',
                'code': level['code'],
              },
            )
            .toList();
        _isLoadingClassLevels = false;
      });
    } catch (e) {
      debugPrint('❌ Error fetching class levels: $e');
      setState(() => _isLoadingClassLevels = false);
      _classLevels = [
        {'id': '1', 'name': 'SALMAN', 'code': 'SM'},
        {'id': '2', 'name': 'ABUZAR', 'code': 'AG'},
        {'id': '3', 'name': 'MIQDAD', 'code': 'MK'},
        {'id': '4', 'name': 'AMMAR', 'code': 'AY'},
        {'id': '5', 'name': 'BILAL', 'code': 'B'},
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Send Notification'),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: withTabBarInset(
              context,
              const EdgeInsets.all(AppTheme.screenPadding),
            ),
            children: [
              // Header Card
              _buildHeaderCard(theme),
              const SizedBox(height: AppTheme.sectionSpacing),

              // Message Section
              _buildSectionHeader(theme, 'MESSAGE', Icons.edit_note),
              const SizedBox(height: AppTheme.spacingMD),
              _buildMessageSection(theme),
              const SizedBox(height: AppTheme.sectionSpacing),

              // Target Audience Section
              _buildSectionHeader(theme, 'TARGET AUDIENCE', Icons.group),
              const SizedBox(height: AppTheme.spacingMD),
              _buildTargetSection(theme),
              const SizedBox(height: AppTheme.sectionSpacing),

              // Action Link Section (Optional)
              _buildSectionHeader(theme, 'ACTION LINK (OPTIONAL)', Icons.link),
              const SizedBox(height: AppTheme.spacingMD),
              _buildActionLinkSection(theme),
              const SizedBox(height: AppTheme.spacing3XL),

              // Send Button
              _buildSendButton(theme),
              const SizedBox(height: AppTheme.sectionSpacing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: AppTheme.lightGreen,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: const Icon(Icons.campaign, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppTheme.spacingLG),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Push Campaign',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reach your users with targeted notifications',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.mediumText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: AppTheme.spacingSM),
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGreen,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageSection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Field
            Text(
              'Title',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter notification title',
                filled: true,
                fillColor: AppTheme.lightGreen,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLG,
                  vertical: AppTheme.spacingMD,
                ),
              ),
              maxLength: 255,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingLG),

            // Body Field
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Message',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppTheme.darkText,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openFullScreenEditor(context),
                  icon: Icon(Icons.fullscreen, size: 18),
                  label: Text('Expand'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
            TextFormField(
              controller: _bodyController,
              decoration: InputDecoration(
                hintText: 'What would you like to say?',
                filled: true,
                fillColor: AppTheme.lightGreen,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(AppTheme.spacingLG),
              ),
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a message';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Opens full-screen message editor
  void _openFullScreenEditor(BuildContext context) {
    final theme = Theme.of(context);
    final tempController = TextEditingController(text: _bodyController.text);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLG),
          ),
        ),
        child: Column(
          children: [
            // Handle and Header
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Message',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          const SizedBox(width: AppTheme.spacingSM),
                          ElevatedButton(
                            onPressed: () {
                              _bodyController.text = tempController.text;
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Text Field
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                child: TextField(
                  controller: tempController,
                  decoration: InputDecoration(
                    hintText: 'Write your notification message here...',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  maxLength: 2000,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.darkText,
                    height: 1.5,
                  ),
                  autofocus: true,
                ),
              ),
            ),
            // Character counter
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                border: Border(top: BorderSide(color: AppTheme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: tempController,
                    builder: (context, value, child) {
                      return Text(
                        '${value.text.length} / 2000',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Type Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: AppTheme.spacingMD,
              crossAxisSpacing: AppTheme.spacingMD,
              childAspectRatio: 1.6,
              children: NotificationTargetType.values.map((type) {
                final isSelected = _selectedTarget == type;
                return _buildTargetOption(theme, type, isSelected);
              }).toList(),
            ),

            // Value Selector (conditionally shown)
            if (_selectedTarget == NotificationTargetType.classLevel) ...[
              const SizedBox(height: AppTheme.spacingLG),
              const Divider(),
              const SizedBox(height: AppTheme.spacingLG),
              _buildClassLevelSelector(theme),
            ],

            if (_selectedTarget == NotificationTargetType.gender) ...[
              const SizedBox(height: AppTheme.spacingLG),
              const Divider(),
              const SizedBox(height: AppTheme.spacingLG),
              _buildGenderSelector(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTargetOption(
    ThemeData theme,
    NotificationTargetType type,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTarget = type;
          _selectedValues.clear();
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.1)
              : AppTheme.backgroundLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type.icon,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.mediumText,
              size: 24,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              type.label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.darkText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassLevelSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Select Class Levels',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.darkText,
              ),
            ),
            if (_isLoadingClassLevels) ...[
              const SizedBox(width: AppTheme.spacingSM),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppTheme.spacingMD),
        if (_classLevels.isEmpty && !_isLoadingClassLevels)
          Text(
            'No class levels available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mediumText,
            ),
          )
        else
          Wrap(
            spacing: AppTheme.spacingSM,
            runSpacing: AppTheme.spacingSM,
            children: _classLevels.map((classLevel) {
              final isSelected = _selectedValues.contains(classLevel['id']);
              return FilterChip(
                label: Text(
                  '${classLevel['name']}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.darkText,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryGreen,
                checkmarkColor: Colors.white,
                backgroundColor: AppTheme.backgroundLight,
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.dividerColor,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedValues.add(classLevel['id']!);
                    } else {
                      _selectedValues.remove(classLevel['id']!);
                    }
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildGenderSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Gender',
          style: theme.textTheme.labelLarge?.copyWith(color: AppTheme.darkText),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        Row(
          children: _genderOptions.map((option) {
            final genderId = option['id'].toString();
            final isSelected = _selectedValues.contains(genderId);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: option == _genderOptions.last ? 0 : AppTheme.spacingMD,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedValues.clear();
                      _selectedValues.add(genderId);
                    });
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingLG,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                          : AppTheme.backgroundLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : AppTheme.dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          option['icon'] as IconData,
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.mediumText,
                          size: 28,
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Text(
                          option['name'] as String,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionLinkSection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'URL or In-App Route',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            TextFormField(
              controller: _actionLinkController,
              decoration: InputDecoration(
                hintText: 'https://example.com or /home/articles',
                filled: true,
                fillColor: AppTheme.backgroundLight,
                prefixIcon: Icon(Icons.link, color: AppTheme.mediumText),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLG,
                  vertical: AppTheme.spacingMD,
                ),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Opens when user taps the notification',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _isSending ? null : _sendNotification,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingLG),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSending)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.send, size: 20),
          const SizedBox(width: AppTheme.spacingMD),
          Text(
            _isSending ? 'Sending...' : 'Send Notification',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification() async {
    if (_isSending) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedTarget == NotificationTargetType.classLevel &&
        _selectedValues.isEmpty) {
      _showError('Please select at least one class level');
      return;
    }

    if (_selectedTarget == NotificationTargetType.gender &&
        _selectedValues.isEmpty) {
      _showError('Please select a gender');
      return;
    }

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final actionLink = _actionLinkController.text.trim();
    final target = _selectedTarget;

    // Build human-friendly target summary for the confirmation dialog.
    String targetSummary = target.label;
    if (target == NotificationTargetType.classLevel) {
      final selectedLevels = _classLevels
          .where((l) => _selectedValues.contains(l['id']))
          .map((l) => l['name'] ?? l['id'].toString())
          .join(', ');
      targetSummary = 'Levels: $selectedLevels';
    } else if (target == NotificationTargetType.gender) {
      targetSummary = _selectedValues
          .map((v) => v == '1' ? 'Gents' : 'Ladies')
          .join(', ');
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Confirm Send'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target: $targetSummary',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Title: $title',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'This notification will be delivered immediately to all matching registered devices.',
              style: TextStyle(fontSize: 13, color: AppTheme.mediumText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            child: const Text('Send Now'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    _showInProgressSnackbar();

    final values = List<String>.from(_selectedValues);

    _titleController.clear();
    _bodyController.clear();
    _actionLinkController.clear();
    setState(() {
      _selectedValues.clear();
      _selectedTarget = NotificationTargetType.values.first;
      _isSending = true;
    });

    try {
      final apiClient = ApiClient();

      final requestBody = {
        'title': title,
        'body': body,
        if (actionLink.isNotEmpty) 'action_link': actionLink,
        'target': {
          'type': target.value,
          'value':
              target == NotificationTargetType.allUsers ||
                  target == NotificationTargetType.teachers
              ? null
              : values,
        },
      };

      final response = await apiClient.post<Map<String, dynamic>>(
        '/notifications/send',
        data: requestBody,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSuccessSnackbar(response);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showError('Failed to send notification: ${userMessage(e)}');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showInProgressSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: AppTheme.spacingLG),
            const Text('Sending notification...'),
          ],
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 30),
      ),
    );
  }

  void _showSuccessSnackbar(Map<String, dynamic> response) {
    final deviceCount = response['device_count'] ?? 0;
    final successCount = response['success_count'] ?? 0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: Text(
                'Sent to $successCount of $deviceCount devices',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
