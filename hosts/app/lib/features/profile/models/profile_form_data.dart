import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_form_data.freezed.dart';
part 'profile_form_data.g.dart';

@freezed
sealed class ProfileFormData with _$ProfileFormData {
  const factory ProfileFormData({
    @Default('') String name,
    @Default('') String mobile,
    @Default('') String country,
    @Default('') String state,
    @Default('') String city,
    @Default('') String zip,
    String? gender, // 'male', 'female'
    int? ageRange, // 1, 2, 3, 4
    String? language, // 'english', 'urdu', 'gujarati'
  }) = _ProfileFormData;

  factory ProfileFormData.fromJson(Map<String, dynamic> json) =>
      _$ProfileFormDataFromJson(json);
}

extension ProfileFormDataX on ProfileFormData {
  bool get isComplete => name.isNotEmpty && gender != null && language != null;

  Map<String, dynamic> toApiPayload() {
    return {
      'name': name,
      'mobile': mobile.isEmpty ? null : mobile,
      'country': country.isEmpty ? null : country,
      'state': state.isEmpty ? null : state,
      'city': city.isEmpty ? null : city,
      'zip': zip.isEmpty ? null : zip,
      'gender': _genderToApiValue(gender),
      'age_range': ageRange,
      'language': _languageToApiValue(language),
    }..removeWhere((key, value) => value == null);
  }

  int? _genderToApiValue(String? gender) {
    switch (gender) {
      case 'male':
        return 1;
      case 'female':
        return 2;
      default:
        return null;
    }
  }

  int? _languageToApiValue(String? language) {
    switch (language) {
      case 'english':
        return 1;
      case 'urdu':
        return 2;
      case 'gujarati':
        return 3;
      default:
        return null;
    }
  }
}
