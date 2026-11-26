/// A child linked to the authenticated parent (#633).
class ChildClassSummary {
  final int classId;
  final String className;
  final String classCode;
  final String status;

  const ChildClassSummary({
    required this.classId,
    required this.className,
    required this.classCode,
    required this.status,
  });

  bool get isActive => status == 'A';

  factory ChildClassSummary.fromJson(Map<String, dynamic> json) {
    return ChildClassSummary(
      classId: (json['class_id'] as num?)?.toInt() ?? 0,
      className: json['class_name'] as String? ?? '',
      classCode: json['class_code'] as String? ?? '',
      status: json['status'] as String? ?? 'A',
    );
  }

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'class_name': className,
    'class_code': classCode,
    'status': status,
  };
}

class ChildModel {
  final int token;
  final String name;
  final String? firstName;
  final String? lastName;
  final int gender;
  final String relationship;
  final List<ChildClassSummary> classes;

  const ChildModel({
    required this.token,
    required this.name,
    this.firstName,
    this.lastName,
    required this.gender,
    required this.relationship,
    this.classes = const [],
  });

  int get activeClassesCount => classes.where((c) => c.isActive).length;

  String get classesSummary {
    final count = activeClassesCount;
    if (count == 0) return 'Not enrolled in any classes';
    if (count == 1) return '1 class';
    return '$count classes';
  }

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    final rawClasses = json['classes'];
    return ChildModel(
      token: (json['token'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      gender: (json['gender'] as num?)?.toInt() ?? 1,
      relationship: json['relationship'] as String? ?? 'guardian',
      classes: rawClasses is List
          ? rawClasses
              .map((c) => ChildClassSummary.fromJson(c as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'name': name,
    'first_name': firstName,
    'last_name': lastName,
    'gender': gender,
    'relationship': relationship,
    'classes': classes.map((c) => c.toJson()).toList(),
  };
}
