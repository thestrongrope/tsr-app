import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../../core/models/user.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

/// State for user profile operations
class UserProfileState {
  final bool isLoading;
  final String? error;
  final bool isUpdatingProfile;
  final bool isUploadingImage;

  const UserProfileState({
    this.isLoading = false,
    this.error,
    this.isUpdatingProfile = false,
    this.isUploadingImage = false,
  });

  UserProfileState copyWith({
    bool? isLoading,
    String? error,
    bool? isUpdatingProfile,
    bool? isUploadingImage,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isUpdatingProfile: isUpdatingProfile ?? this.isUpdatingProfile,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
    );
  }
}

/// User profile provider for handling profile operations
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
      return UserProfileNotifier(ref);
    });

/// User profile notifier
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier(this._ref) : super(const UserProfileState());

  final Ref _ref;

  /// Update user profile
  Future<void> updateProfile({
    String? name,
    String? firstName,
    String? lastName,
    int? gender,
    int? ageRange,
    String? mobile,
    String? country,
    String? userState,
    String? city,
    String? zip,
    int? language,
    String? timezone,
    bool? sendupdates,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(error: 'No user found');
      return;
    }

    state = state.copyWith(isUpdatingProfile: true, error: null);

    try {
      debugPrint('🔵 Updating user profile...');

      // Prepare update data - only include non-null values
      final Map<String, dynamic> updateData = {};

      if (name != null) updateData['name'] = name;
      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (gender != null) updateData['gender'] = gender;
      if (ageRange != null) updateData['age_range'] = ageRange;
      if (mobile != null) updateData['mobile'] = mobile;
      if (country != null) updateData['country'] = country;
      if (userState != null) updateData['state'] = userState;
      if (city != null) updateData['city'] = city;
      if (zip != null) updateData['zip'] = zip;
      if (language != null) updateData['language'] = language;
      if (timezone != null) updateData['timezone'] = timezone;
      if (sendupdates != null) updateData['sendupdates'] = sendupdates ? 1 : 0;

      debugPrint('🔵 Profile update data: $updateData');

      // Send update to backend
      final apiClient = _ref.read(apiClientProvider);
      final updatedUserData = await apiClient.updateProfile(updateData);

      // Convert response to User object
      final updatedUser = User.fromJson(updatedUserData);

      // Update local storage and auth state
      await _updateUserLocally(updatedUser);

      state = state.copyWith(isUpdatingProfile: false);
      debugPrint('🟢 Profile updated successfully');
    } catch (e) {
      debugPrint('🔴 Failed to update profile: $e');
      state = state.copyWith(
        isUpdatingProfile: false,
        error: _mapErrorToMessage(e),
      );
      rethrow;
    }
  }

  /// Upload profile picture (for custom images, not Google profile picture)
  Future<void> updateProfilePicture(String imagePath) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      state = state.copyWith(error: 'No user found');
      return;
    }

    state = state.copyWith(isUploadingImage: true, error: null);

    try {
      debugPrint('🔵 Uploading profile picture...');

      // TODO: Implement file upload to your backend
      // For now, this is a placeholder
      // final apiClient = _ref.read(apiClientProvider);
      // final updatedUserData = await apiClient.uploadProfilePicture(imagePath);

      // Simulate upload for now
      await Future.delayed(const Duration(seconds: 2));

      // Create updated user with new profile image URL
      final updatedUser = currentUser.copyWith(
        picture: 'uploaded_image_url', // Replace with actual uploaded URL
      );

      await _updateUserLocally(updatedUser);

      state = state.copyWith(isUploadingImage: false);
      debugPrint('🟢 Profile picture updated successfully');
    } catch (e) {
      debugPrint('🔴 Failed to upload profile picture: $e');
      state = state.copyWith(
        isUploadingImage: false,
        error: _mapErrorToMessage(e),
      );
      rethrow;
    }
  }

  /// Get user profile details from backend
  Future<User?> fetchUserProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('🔵 Fetching user profile from backend...');

      final apiClient = _ref.read(apiClientProvider);
      final userData = await apiClient.getCurrentUser();

      final user = User.fromJson(userData);
      await _updateUserLocally(user);

      state = state.copyWith(isLoading: false);
      debugPrint('🟢 User profile fetched successfully');

      return user;
    } catch (e) {
      debugPrint('🔴 Failed to fetch user profile: $e');
      state = state.copyWith(isLoading: false, error: _mapErrorToMessage(e));
      return null;
    }
  }

  /// Update user data locally and in Hive storage
  Future<void> _updateUserLocally(User updatedUser) async {
    debugPrint('🔵 Updating user locally: ${updatedUser.email}');

    try {
      // Update Hive storage
      final userBox = Hive.box<User>(AppConstants.userBoxKey);
      await userBox.put('current_user', updatedUser);

      // Update auth state
      await _ref
          .read(authStateProvider.notifier)
          .updateUserLocally(updatedUser);

      debugPrint('🟢 User updated locally successfully');
    } catch (e) {
      debugPrint('🔴 Failed to update user locally: $e');
      throw Exception('Failed to save user data locally');
    }
  }

  /// Clear any errors
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Map exceptions to user-friendly messages
  String _mapErrorToMessage(dynamic error) {
    final errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('network') ||
        errorMessage.contains('connection')) {
      return 'Network error. Please check your connection.';
    } else if (errorMessage.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorMessage.contains('unauthorized') ||
        errorMessage.contains('401')) {
      return 'Unauthorized. Please log in again.';
    } else if (errorMessage.contains('validation') ||
        errorMessage.contains('400')) {
      return 'Invalid data. Please check your input.';
    } else if (errorMessage.contains('404')) {
      return 'User not found.';
    } else if (errorMessage.contains('500')) {
      return 'Server error. Please try again later.';
    }
    return 'An error occurred. Please try again.';
  }
}

/// Constants for dropdown options
class ProfileConstants {
  // Gender options (matching backend integer values)
  static const Map<int, String> genderOptions = {1: 'Male', 2: 'Female'};

  // Age range options (matching backend integer values)
  static const Map<int, String> ageRangeOptions = {
    1: '13-17 years (Youth)',
    2: '18-25 years (Young Adult)',
    3: '26-40 years (Adult)',
    4: '41+ years (Senior)',
  };

  // Language options (matching backend integer values)
  static const Map<int, String> languageOptions = {
    1: 'English',
    2: 'Urdu',
    3: 'Gujarati',
  };

  // Country options (you can expand this based on your needs)
  static const List<String> countryOptions = [
    'India',
    'Pakistan',
    'Bangladesh',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    // Add more countries as needed
  ];

  // States for India (you can expand based on country selection)
  static const Map<String, List<String>> stateOptions = {
    'India': [
      'Maharashtra',
      'Gujarat',
      'Karnataka',
      'Tamil Nadu',
      'West Bengal',
      'Rajasthan',
      'Uttar Pradesh',
      'Madhya Pradesh',
      'Bihar',
      'Haryana',
      'Punjab',
      'Assam',
      'Odisha',
      'Telangana',
      'Andhra Pradesh',
      'Kerala',
      'Jharkhand',
      'Chhattisgarh',
      'Uttarakhand',
      'Goa',
      'Himachal Pradesh',
      'Jammu and Kashmir',
      'Ladakh',
      'Manipur',
      'Meghalaya',
      'Mizoram',
      'Nagaland',
      'Sikkim',
      'Tripura',
      'Arunachal Pradesh',
      'Delhi',
      'Puducherry',
      'Chandigarh',
      'Andaman and Nicobar Islands',
      'Dadra and Nagar Haveli and Daman and Diu',
      'Lakshadweep',
    ],
    // Add more states for other countries
  };

  // Major cities for states (you can expand this)
  static const Map<String, List<String>> cityOptions = {
    'Maharashtra': [
      'Mumbai',
      'Pune',
      'Nagpur',
      'Thane',
      'Nashik',
      'Aurangabad',
      'Solapur',
      'Kolhapur',
      'Sangli',
      'Satara',
    ],
    'Gujarat': [
      'Ahmedabad',
      'Surat',
      'Vadodara',
      'Rajkot',
      'Bhavnagar',
      'Jamnagar',
      'Junagadh',
      'Gandhinagar',
      'Anand',
      'Bharuch',
    ],
    // Add more cities for other states
  };
}
