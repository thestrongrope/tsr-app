/// A class that a linked child is or was enrolled in (#633).
///
/// Intentionally excludes meeting links (`classes.link`) for privacy and
/// gender-segregation compliance.
class ChildClassModel {
  final int classId;
  final String className;
  final String classCode;
  final int gender;
  final String teacherName;
  final String startedOn;
  final String enrolmentStatus;

  const ChildClassModel({
    required this.classId,
    required this.className,
    required this.classCode,
    required this.gender,
    required this.teacherName,
    required this.startedOn,
    required this.enrolmentStatus,
  });

  bool get isActive => enrolmentStatus == 'A';

  factory ChildClassModel.fromJson(Map<String, dynamic> json) {
    return ChildClassModel(
      classId: (json['class_id'] as num?)?.toInt() ?? 0,
      className: json['class_name'] as String? ?? '',
      classCode: json['class_code'] as String? ?? '',
      gender: (json['gender'] as num?)?.toInt() ?? 1,
      teacherName: json['teacher_name'] as String? ?? '',
      startedOn: json['started_on'] as String? ?? '',
      enrolmentStatus: json['enrolment_status'] as String? ?? 'A',
    );
  }

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'class_name': className,
    'class_code': classCode,
    'gender': gender,
    'teacher_name': teacherName,
    'started_on': startedOn,
    'enrolment_status': enrolmentStatus,
  };
}
