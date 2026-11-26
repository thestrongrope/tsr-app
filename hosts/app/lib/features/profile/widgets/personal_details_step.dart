import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/profile_completion_provider.dart';

class PersonalDetailsStep extends ConsumerStatefulWidget {
  const PersonalDetailsStep({super.key});

  @override
  ConsumerState<PersonalDetailsStep> createState() =>
      _PersonalDetailsStepState();
}

class _PersonalDetailsStepState extends ConsumerState<PersonalDetailsStep> {
  late TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();

    // Initialize with current form data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formData = ref.read(profileCompletionProvider).formData;
      _nameController.text = formData.name;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileCompletionProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome message
          Container(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
              border: Border.all(
                color: AppTheme.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 48,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(height: 12),
                Text(
                  'Let\'s get to know you better!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us personalize your experience by sharing some basic information.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Name field
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              hintText: 'Enter your full name',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters long';
              }
              return null;
            },
            onChanged: (value) {
              final formData = profileState.formData.copyWith(
                name: value.trim(),
              );
              ref
                  .read(profileCompletionProvider.notifier)
                  .updateFormData(formData);
            },
          ),

          const SizedBox(height: 24),

          // Gender selection
          Text(
            'Gender *',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  title: 'Male',
                  icon: Icons.male,
                  isSelected: profileState.formData.gender == 'male',
                  onTap: () {
                    final formData = profileState.formData.copyWith(
                      gender: 'male',
                    );
                    ref
                        .read(profileCompletionProvider.notifier)
                        .updateFormData(formData);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderCard(
                  title: 'Female',
                  icon: Icons.female,
                  isSelected: profileState.formData.gender == 'female',
                  onTap: () {
                    final formData = profileState.formData.copyWith(
                      gender: 'female',
                    );
                    ref
                        .read(profileCompletionProvider.notifier)
                        .updateFormData(formData);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Age Range selection
          DropdownButtonFormField<int>(
            initialValue: profileState.formData.ageRange,
            decoration: AppTheme.dropdownDecoration(
              label: 'Age Range *',
              hintText: 'Select your age range',
              prefixIcon: Icons.cake_outlined,
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Less than 15')),
              DropdownMenuItem(value: 2, child: Text('15 to 25')),
              DropdownMenuItem(value: 3, child: Text('26 to 40')),
              DropdownMenuItem(value: 4, child: Text('Above 40')),
            ],
            onChanged: (v) {
              if (v != null) {
                final formData = profileState.formData.copyWith(ageRange: v);
                ref
                    .read(profileCompletionProvider.notifier)
                    .updateFormData(formData);
              }
            },
          ),

          const SizedBox(height: 24),

          // Language selection
          Text(
            'Preferred Language *',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _LanguageCard(
                title: 'English',
                subtitle: 'Primary language for content',
                isSelected: profileState.formData.language == 'english',
                onTap: () {
                  final formData = profileState.formData.copyWith(
                    language: 'english',
                  );
                  ref
                      .read(profileCompletionProvider.notifier)
                      .updateFormData(formData);
                },
              ),
              const SizedBox(height: 8),
              _LanguageCard(
                title: 'Urdu',
                subtitle: 'اردو میں مواد',
                isSelected: profileState.formData.language == 'urdu',
                onTap: () {
                  final formData = profileState.formData.copyWith(
                    language: 'urdu',
                  );
                  ref
                      .read(profileCompletionProvider.notifier)
                      .updateFormData(formData);
                },
              ),
              const SizedBox(height: 8),
              _LanguageCard(
                title: 'Gujarati',
                subtitle: 'ગુજરાતી ભાષામાં સામગ્રી',
                isSelected: profileState.formData.language == 'gujarati',
                onTap: () {
                  final formData = profileState.formData.copyWith(
                    language: 'gujarati',
                  );
                  ref
                      .read(profileCompletionProvider.notifier)
                      .updateFormData(formData);
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Required fields note
          Text(
            '* Required fields',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.mediumText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.mediumText,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected ? AppTheme.primaryGreen : AppTheme.darkText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryGreen : AppTheme.mediumText,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.language, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isSelected
                          ? AppTheme.primaryGreen
                          : AppTheme.darkText,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 24),
          ],
        ),
      ),
    );
  }
}
