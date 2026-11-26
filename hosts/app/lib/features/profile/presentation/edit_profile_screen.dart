import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../widgets/location_fields.dart';
import '../widgets/profile_widgets.dart';
import '../../../core/models/user.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _zipController = TextEditingController();

  int? _selectedGender;
  int? _selectedLanguage;
  int? _selectedAgeRange;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _mobileController.text = user.mobile ?? '';
      _cityController.text = user.city ?? '';
      _stateController.text = user.state ?? '';
      _countryController.text = user.country ?? '';
      _zipController.text = user.zip ?? '';
      _selectedGender = user.gender;
      _selectedLanguage = user.language;
      _selectedAgeRange = user.ageRange;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  String? _validateSafeText(
    String? value,
    String label, {
    bool required = false,
  }) {
    if (value == null || value.isEmpty) {
      return required ? '$label is required' : null;
    }
    if (value.length < 2) return '$label must be at least 2 characters';
    if (value.length > 50) return '$label must be less than 50 characters';
    final valid = RegExp(r"^[a-zA-Z0-9\s\.\,\'-]+$");
    if (!valid.hasMatch(value)) {
      return '$label contains invalid characters';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) throw Exception('User not found');

      final payload = {
        'name': _nameController.text.trim(),
        'mobile': _mobileController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'country': _countryController.text.trim(),
        'zip': _zipController.text.trim(),
        'gender': _selectedGender,
        'language': _selectedLanguage,
        'age_range': _selectedAgeRange,
      };

      payload.removeWhere((key, value) => value == null);

      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.updateProfile(payload);
      final updatedUser = User.fromJson(response);

      await ref.read(authStateProvider.notifier).updateUserLocally(updatedUser);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          message: 'Profile updated successfully!',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        // The form keeps what the member typed, so they can fix it or retry.
        AppSnackBar.showError(
          context,
          message: 'Your changes were not saved. ${userMessage(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(title: const Text('Edit profile')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
        child: _body(authState),
      ),
    );
  }

  Widget _body(AuthState authState) {
    final user = authState.user;
    if (user != null) return _buildForm(user);
    if (authState.status == AuthStatus.loading) {
      return const ProfileSkeleton();
    }
    return ProfileLoadError(onRetry: () => ref.invalidate(authStateProvider));
  }

  Widget _buildForm(User user) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: withTabBarInset(
          context,
          const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.spacingSM,
            AppTheme.screenPadding,
            AppTheme.spacing3XL,
          ),
        ),
        children: [
          ProfileHeroCard(
            name: user.name,
            email: user.email,
            picture: user.picture,
          ),
          const SizedBox(height: AppTheme.sectionSpacing),
          const AppSectionHeader(title: 'Personal information'),
          const SizedBox(height: AppTheme.spacingMD),
          AppSurfaceCard(child: _buildPersonalFields()),
          const SizedBox(height: AppTheme.sectionSpacing),
          const AppSectionHeader(title: 'Location details'),
          const SizedBox(height: AppTheme.spacingMD),
          AppSurfaceCard(child: _buildLocationFields()),
          const SizedBox(height: AppTheme.sectionSpacing),
          _buildUpdateButton(),
        ],
      ),
    );
  }

  Widget _buildPersonalFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'FULL NAME',
          icon: Icons.badge_outlined,
          validator: (v) => _validateSafeText(v, 'Name', required: true),
        ),
        const SizedBox(height: AppTheme.spacingLG),
        // Email is not editable here, so it is shown read-only.
        _buildTextField(
          controller: _emailController,
          label: 'EMAIL',
          icon: Icons.email_outlined,
          readOnly: true,
        ),
        const SizedBox(height: AppTheme.spacingLG),
        _buildTextField(
          controller: _mobileController,
          label: 'MOBILE',
          icon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v != null && v.isNotEmpty) {
              if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v)) {
                return 'Invalid number';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: AppTheme.spacingLG),
        DropdownButtonFormField<int>(
          initialValue: _selectedGender,
          decoration: AppTheme.dropdownDecoration(
            label: 'GENDER',
            prefixIcon: Icons.people_outline,
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Male')),
            DropdownMenuItem(value: 2, child: Text('Female')),
          ],
          onChanged: (v) => setState(() => _selectedGender = v),
        ),
        const SizedBox(height: AppTheme.spacingLG),
        DropdownButtonFormField<int>(
          initialValue: _selectedAgeRange,
          decoration: AppTheme.dropdownDecoration(
            label: 'AGE RANGE',
            prefixIcon: Icons.cake_outlined,
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('Less than 15')),
            DropdownMenuItem(value: 2, child: Text('15 to 25')),
            DropdownMenuItem(value: 3, child: Text('26 to 40')),
            DropdownMenuItem(value: 4, child: Text('Above 40')),
          ],
          onChanged: (v) => setState(() => _selectedAgeRange = v),
        ),
        const SizedBox(height: AppTheme.spacingLG),
        DropdownButtonFormField<int>(
          initialValue: _selectedLanguage,
          decoration: AppTheme.dropdownDecoration(
            label: 'LANGUAGE',
            prefixIcon: Icons.language,
          ),
          items: const [
            DropdownMenuItem(value: 1, child: Text('English')),
            DropdownMenuItem(value: 2, child: Text('Urdu')),
            DropdownMenuItem(value: 3, child: Text('Gujarati')),
          ],
          onChanged: (v) => setState(() => _selectedLanguage = v),
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    // Country, postal code, state and city (#443): picked or looked up from
    // our own copy of GeoNames. The country is picked; the rest is editable text.
    return LocationFields(
      country: _countryController,
      zip: _zipController,
      state: _stateController,
      city: _cityController,
      onChanged: (field, value) {},
      decoration: (label, icon, {hint}) => InputDecoration(
        labelText: label.toUpperCase(),
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.mediumText, size: 20),
      ),
      countryValidator: (v) => _validateSafeText(v, 'Country'),
      zipValidator: (v) {
        if (v != null && v.isNotEmpty) {
          if (!RegExp(r'^[0-9A-Za-z\s-]{3,12}$').hasMatch(v)) {
            return 'Invalid postal code';
          }
        }
        return null;
      },
      stateValidator: (v) => _validateSafeText(v, 'State'),
      cityValidator: (v) => _validateSafeText(v, 'City'),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.mediumText, size: 20),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.buttonHeightLarge,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveProfile,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(_isLoading ? 'Updating...' : 'Update Profile'),
      ),
    );
  }
}
