import 'package:freezed_annotation/freezed_annotation.dart';

part 'class_session.freezed.dart';

@freezed
sealed class ClassSession with _$ClassSession {
  const ClassSession._();

  const factory ClassSession({
    required int id,
    required DateTime conductedOn,
    required bool conducted,
    int? duration,
    int? attendance,
    @Default(false) bool arabicConducted,
    @Default(false) bool aqaedConducted,
    @Default(false) bool ahkamConducted,
    @Default(false) bool akhlaqConducted,
    String? nonConductionReason,
  }) = _ClassSession;

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json['id'] as int,
      conductedOn: DateTime.parse(json['conductedOn'].toString()),
      conducted: json['conducted'] == 1 || json['conducted'] == true,
      duration: json['duration'] as int?,
      attendance: json['attendance'] as int?,
      arabicConducted:
          json['arabicConducted'] == 1 || json['arabicConducted'] == true,
      aqaedConducted:
          json['aqaedConducted'] == 1 || json['aqaedConducted'] == true,
      ahkamConducted:
          json['ahkamConducted'] == 1 || json['ahkamConducted'] == true,
      akhlaqConducted:
          json['akhlaqConducted'] == 1 || json['akhlaqConducted'] == true,
      nonConductionReason: json['nonConductionReason'] as String?,
    );
  }

  /// Get list of topics covered in this session
  List<String> get topicsCovered {
    final topics = <String>[];
    if (arabicConducted) topics.add('Arabic');
    if (aqaedConducted) topics.add('Aqaed');
    if (ahkamConducted) topics.add('Ahkam');
    if (akhlaqConducted) topics.add('Akhlaq');
    return topics;
  }

  /// Formatted duration string
  String get durationFormatted {
    if (duration == null) return 'N/A';
    if (duration! < 60) return '$duration min';
    final hours = duration! ~/ 60;
    final mins = duration! % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

@freezed
sealed class StudentAttendance with _$StudentAttendance {
  const StudentAttendance._();

  const factory StudentAttendance({
    required int sessionId,
    required DateTime conductedOn,
    required bool present,
    @Default(0) int recitation,
  }) = _StudentAttendance;

  factory StudentAttendance.fromJson(Map<String, dynamic> json) {
    return StudentAttendance(
      sessionId: json['sessionId'] as int,
      conductedOn: DateTime.parse(json['conductedOn'].toString()),
      present: json['present'] == 1 || json['present'] == true,
      recitation: json['recitation'] as int? ?? 0,
    );
  }
}
