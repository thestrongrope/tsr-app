import 'package:freezed_annotation/freezed_annotation.dart';
import 'class_schedule.dart';

part 'class_model.freezed.dart';
part 'class_model.g.dart';

@freezed
sealed class ClassModel with _$ClassModel {
  const ClassModel._();

  const factory ClassModel({
    required int id,
    required String code,
    required String name,
    required int level,
    String? levelName,
    int? language,
    required int gender,
    required String status,
    String? location,
    String? teacherName,
    String? teacherMobile,
    String? format,
    DateTime? startedOn,
    // 'conducting' when the user is the class teacher, 'managing' when they
    // manage the class without attending or teaching it, else 'attending'.
    String? role,
    // The class join link to share; the server sends it to the class
    // teacher only, null for everyone else.
    String? joinUrl,
    // Where the class meets and how it is tagged, for search and the card.
    String? city,
    String? country,
    @Default([]) List<String> tags,
    // Enrolled students; the server sends it for managed classes only.
    int? studentCount,
    @Default([]) List<ClassSchedule> schedules,
  }) = _ClassModel;

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    // Handle schedules parsing
    List<ClassSchedule> schedules = [];
    if (json['schedules'] != null) {
      schedules = (json['schedules'] as List)
          .map((s) => ClassSchedule.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return ClassModel(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      level: json['level'] as int,
      levelName: json['levelName'] as String?,
      language: json['language'] as int?,
      gender: json['gender'] as int,
      status: json['status'] as String,
      location: json['location'] as String?,
      teacherName: json['teacherName'] as String?,
      teacherMobile: json['teacherMobile'] as String?,
      format: json['format'] as String?,
      startedOn: json['startedOn'] != null
          ? DateTime.tryParse(json['startedOn'].toString())
          : null,
      role: json['role'] as String?,
      joinUrl: json['joinUrl'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      tags: (json['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
      studentCount: json['studentCount'] as int?,
      schedules: schedules,
    );
  }

  /// Whether the user conducts (teaches) this class.
  bool get isConducting => role == 'conducting';

  /// Whether the user manages this class without teaching or attending it.
  bool get isManaging => role == 'managing';

  /// Whether the user attends (is enrolled in) this class.
  bool get isAttending => !isConducting && !isManaging;

  /// Whether the user sees the staff view of this class, not the student view.
  bool get isStaff => isConducting || isManaging;

  /// Check if this is a gents class
  bool get isGents => gender == 1;

  /// Check if this is a ladies class
  bool get isLadies => gender == 2;

  /// Get formatted location or default
  String get displayLocation => location ?? 'Online';

  /// Get formatted format (Online/Offline)
  String get displayFormat => format ?? 'Online';
}

@freezed
sealed class ClassJoinResponse with _$ClassJoinResponse {
  const factory ClassJoinResponse({
    required bool success,
    required String message,
    int? classId,
    String? className,
  }) = _ClassJoinResponse;

  factory ClassJoinResponse.fromJson(Map<String, dynamic> json) =>
      _$ClassJoinResponseFromJson(json);
}
