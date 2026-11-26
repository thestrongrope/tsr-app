import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/user.dart';
import '../models/geo.dart';
import '../models/profile_form_data.dart';
import 'geo_provider.dart';
import '../models/profile_completion_state.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileCompletionNotifier extends StateNotifier<ProfileCompletionState> {
  ProfileCompletionNotifier(this._apiClient)
    : super(const ProfileCompletionState());

  final ApiClient _apiClient;

  /// What the location fields say blocks continuing: a country that is not on the
  /// list, or a postal code that is being checked, not held or could not be
  /// checked. Null means nothing does. Set by the screen, read on submit.
  String? locationProblem;

  void setLocationProblem(String? problem) => locationProblem = problem;

  /// Initialize form data with existing user data
  void initializeWithUser(User user) {
    debugPrint('🔵 Initializing profile form with user data: ${user.email}');

    final formData = ProfileFormData(
      name: user.name,
      mobile: user.mobile ?? '',
      country: user.country ?? '',
      state: user.state ?? '',
      city: user.city ?? '',
      zip: user.zip ?? '',
      gender: _apiValueToGender(user.gender),
      ageRange: user.ageRange,
      language: _apiValueToLanguage(user.language),
    );

    state = state.copyWith(formData: formData);
  }

  /// Update form data
  void updateFormData(ProfileFormData formData) {
    if (state.status == ProfileCompletionStatus.error) {
      state = state.copyWith(
        formData: formData,
        status: ProfileCompletionStatus.initial,
        error: null,
      );
    } else {
      state = state.copyWith(formData: formData);
    }
  }

  /// Move to next step
  void nextStep() {
    // Validate Step 1 (Personal Details)
    if (state.currentStep == 0) {
      if (state.formData.name.trim().isEmpty) {
        state = state.copyWith(
          status: ProfileCompletionStatus.error,
          error: 'Please enter your full name.',
        );
        return;
      }
      if (state.formData.gender == null) {
        state = state.copyWith(
          status: ProfileCompletionStatus.error,
          error: 'Please select your gender.',
        );
        return;
      }
      if (state.formData.ageRange == null) {
        state = state.copyWith(
          status: ProfileCompletionStatus.error,
          error: 'Please select your age range.',
        );
        return;
      }
    }

    if (state.currentStep < 1) {
      // We have 2 steps (0 and 1)
      state = state.copyWith(
        currentStep: state.currentStep + 1,
        status: ProfileCompletionStatus.initial, // Clear error
        error: null,
      );
    }
  }

  /// Move to previous step
  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(
        currentStep: state.currentStep - 1,
        status: ProfileCompletionStatus.initial,
        error: null,
      );
    }
  }

  /// Submit profile data to backend
  Future<void> submitProfile(WidgetRef ref) async {
    // Validate Step 2 (Additional Details)
    final mobile = state.formData.mobile.trim();
    if (mobile.isEmpty) {
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: 'Please enter your mobile number.',
      );
      return;
    }

    // Mobile number regex validation
    final mobileRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!mobileRegex.hasMatch(mobile)) {
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: 'Please enter a valid mobile number (10-15 digits).',
      );
      return;
    }

    if (state.formData.country.trim().isEmpty) {
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: 'Please enter your country.',
      );
      return;
    }
    final problem = locationProblem;
    if (problem != null) {
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: problem,
      );
      return;
    }
    if (state.formData.state.trim().isEmpty) {
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: 'Please enter your state.',
      );
      return;
    }
    if (state.formData.city.trim().isEmpty) {
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: 'Please enter your city.',
      );
      return;
    }
    if (state.formData.zip.trim().isEmpty &&
        zipIsRequired(
          _countryNamed(
            state.formData.country,
            ref.read(geoCountriesProvider).value ?? const [],
          ),
        )) {
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: 'Please enter your ZIP code.',
      );
      return;
    }
    if (state.formData.language == null) {
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: 'Please select your preferred language.',
      );
      return;
    }

    debugPrint('🔵 Submitting profile data...');

    state = state.copyWith(
      status: ProfileCompletionStatus.loading,
      error: null,
    );

    try {
      final payload = state.formData.toApiPayload();
      debugPrint('🔵 Profile payload: $payload');

      final response = await _apiClient.updateProfile(payload);
      debugPrint('🟢 Profile update successful: $response');

      // Update the user in auth state
      final updatedUser = User.fromJson(response);
      await ref.read(authStateProvider.notifier).updateUserLocally(updatedUser);

      state = state.copyWith(status: ProfileCompletionStatus.success);
    } catch (e) {
      debugPrint('🔴 Profile update failed: $e');
      state = state.copyWith(
        status: ProfileCompletionStatus.error,
        error: _mapErrorToMessage(e),
      );
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(
      status: ProfileCompletionStatus.initial,
      error: null,
    );
  }

  /// Reset to initial state
  void reset() {
    state = const ProfileCompletionState();
  }

  String? _apiValueToGender(int? gender) {
    if (gender == null) return null;
    switch (gender) {
      case 1:
        return 'male';
      case 2:
        return 'female';
      default:
        return null;
    }
  }

  String? _apiValueToLanguage(int? language) {
    if (language == null) return null;
    switch (language) {
      case 1:
        return 'english';
      case 2:
        return 'urdu';
      case 3:
        return 'gujarati';
      default:
        return null;
    }
  }

  String _mapErrorToMessage(dynamic error) {
    if (error.toString().contains('timeout')) {
      return 'Request timed out. Please check your connection and try again.';
    }
    if (error.toString().contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    if (error.toString().contains('401') ||
        error.toString().contains('unauthorized')) {
      return 'Authentication failed. Please sign in again.';
    }
    if (error.toString().contains('400') ||
        error.toString().contains('bad request')) {
      return 'Invalid data. Please check your information and try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

/// Profile completion provider
final profileCompletionProvider =
    StateNotifierProvider<ProfileCompletionNotifier, ProfileCompletionState>((
      ref,
    ) {
      final apiClient = ref.read(apiClientProvider);
      return ProfileCompletionNotifier(apiClient);
    });

/// The country in [countries] with this name (case does not matter), or null.
GeoCountry? _countryNamed(String name, List<GeoCountry> countries) {
  final typed = name.trim().toLowerCase();
  for (final c in countries) {
    if (c.name.toLowerCase() == typed) return c;
  }
  return null;
}

/// A ZIP is required, as it always has been, except in a country we know has no
/// postal codes: the form does not even show the field there.
bool zipIsRequired(GeoCountry? country) =>
    country == null || country.hasPostalCodes;
