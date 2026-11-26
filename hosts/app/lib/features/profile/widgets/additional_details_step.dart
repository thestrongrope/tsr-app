import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/profile_completion_provider.dart';
import 'location_fields.dart';

class AdditionalDetailsStep extends ConsumerStatefulWidget {
  const AdditionalDetailsStep({super.key});

  @override
  ConsumerState<AdditionalDetailsStep> createState() =>
      _AdditionalDetailsStepState();
}

class _AdditionalDetailsStepState extends ConsumerState<AdditionalDetailsStep> {
  late TextEditingController _mobileController;
  late TextEditingController _countryController;
  late TextEditingController _stateController;
  late TextEditingController _cityController;
  late TextEditingController _zipController;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController();
    _countryController = TextEditingController();
    _stateController = TextEditingController();
    _cityController = TextEditingController();
    _zipController = TextEditingController();

    // Initialize with current form data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formData = ref.read(profileCompletionProvider).formData;
      _mobileController.text = formData.mobile;
      _countryController.text = formData.country;
      _stateController.text = formData.state;
      _cityController.text = formData.city;
      _zipController.text = formData.zip;
    });
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileCompletionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome message
        Container(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
            border: Border.all(
              color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 48,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(height: 12),
              Text(
                'Almost Done!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Add your contact and location details to help us serve you better.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Contact Information Section
        Text(
          'Contact Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Mobile number field
        TextFormField(
          controller: _mobileController,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            hintText: '+1 (555) 123-4567',
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          onChanged: (value) {
            final formData = profileState.formData.copyWith(
              mobile: value.trim(),
            );
            ref
                .read(profileCompletionProvider.notifier)
                .updateFormData(formData);
          },
        ),

        const SizedBox(height: 32),

        // Location Information Section
        Text(
          'Location Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us provide region-specific content and class schedules.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.mediumText,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),

        // Country, postal code, state and city (#443): picked or looked up from
        // our own copy of GeoNames. The country is picked; the rest is editable text.
        LocationFields(
          country: _countryController,
          zip: _zipController,
          state: _stateController,
          city: _cityController,
          onProblemChanged: ref
              .read(profileCompletionProvider.notifier)
              .setLocationProblem,
          decoration: (label, icon, {hint}) => InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon),
          ),
          zipValidator: (v) {
            if (v != null && v.isNotEmpty) {
              if (!RegExp(r'^[0-9A-Za-z\s-]{3,12}$').hasMatch(v)) {
                return 'Invalid postal code';
              }
            }
            return null;
          },
          onChanged: (field, value) {
            final formData = ref.read(profileCompletionProvider).formData;
            ref.read(profileCompletionProvider.notifier).updateFormData(
              switch (field) {
                LocationField.country => formData.copyWith(country: value),
                LocationField.zip => formData.copyWith(zip: value),
                LocationField.state => formData.copyWith(state: value),
                LocationField.city => formData.copyWith(city: value),
              },
            );
          },
        ),

        const SizedBox(height: 32),

        // Privacy note
        Container(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Notice',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your information is secure and will only be used to enhance your learning experience. You can update these details anytime in your profile settings.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.blue[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Profile completion summary
        Container(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
          ),
          child: Column(
            children: [
              Text(
                'Profile Summary',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildSummaryRow('Name', profileState.formData.name),
              _buildSummaryRow(
                'Gender',
                _formatGender(profileState.formData.gender),
              ),
              _buildSummaryRow(
                'Language',
                _formatLanguage(profileState.formData.language),
              ),
              if (profileState.formData.ageRange != null)
                _buildSummaryRow(
                  'Age Range',
                  _formatAgeRange(profileState.formData.ageRange!),
                ),
              if (profileState.formData.mobile.isNotEmpty)
                _buildSummaryRow('Mobile', profileState.formData.mobile),
              if (profileState.formData.country.isNotEmpty)
                _buildSummaryRow('Country', profileState.formData.country),
              if (profileState.formData.zip.isNotEmpty)
                _buildSummaryRow('ZIP', profileState.formData.zip),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
            ),
          ),
        ],
      ),
    );
  }

  String _formatGender(String? gender) {
    switch (gender) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Not specified';
    }
  }

  String _formatLanguage(String? language) {
    switch (language) {
      case 'english':
        return 'English';
      case 'urdu':
        return 'Urdu';
      case 'gujarati':
        return 'Gujarati';
      default:
        return 'Not specified';
    }
  }

  String _formatAgeRange(int ageRange) {
    switch (ageRange) {
      case 1:
        return 'Less than 15';
      case 2:
        return '15 to 25';
      case 3:
        return '26 to 40';
      case 4:
        return 'Above 40';
      default:
        return 'Not specified';
    }
  }
}
