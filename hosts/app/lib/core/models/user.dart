import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
@HiveType(typeId: 1) // Unique typeId for Hive
sealed class User with _$User {
  const User._(); // Private constructor for custom getters

  const factory User({
    @HiveField(0) required int id,
    @HiveField(1) required int token,
    @HiveField(2) required String email,
    @HiveField(3) required String name,
    @HiveField(4) required int roleId,
    @HiveField(5) String? picture,
    @HiveField(6) int? gender,
    @HiveField(7) int? ageRange,
    @HiveField(8) String? mobile,
    @HiveField(9) String? country,
    @HiveField(10) String? state,
    @HiveField(11) String? city,
    @HiveField(12) int? language,
    @HiveField(13) String? zip,
    @HiveField(14) String? sendupdates,
    @HiveField(15) String? unsubscribe,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      token: json['token'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      roleId: json['roleid'] as int,
      picture: json['picture'] as String?,
      gender: _parseIntField(json['gender']),
      ageRange: _parseIntField(json['age_range']),
      mobile: json['mobile'] as String?,
      country: json['country'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
      language: _parseIntField(json['language']),
      zip: json['zip'] as String?,
      sendupdates: json['sendupdates'] as String?,
      unsubscribe: json['unsubscribe'] as String?,
    );
  }

  /// Helper method to parse fields that can be either int or string
  static int? _parseIntField(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  bool get isProfileComplete {
    return name.isNotEmpty &&
        gender != null &&
        ageRange != null &&
        mobile != null &&
        mobile!.isNotEmpty &&
        language != null &&
        country != null &&
        country!.isNotEmpty &&
        state != null &&
        state!.isNotEmpty &&
        city != null &&
        city!.isNotEmpty &&
        zip != null &&
        zip!.isNotEmpty;
  }
}
