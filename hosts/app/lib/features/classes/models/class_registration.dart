/// Models for the class request (registration) form.
///
/// Mirrors the mobile API contract in
/// `tsr-account/web/api/mobile/routes/registration.php` — camelCase over the
/// wire, matching the existing `tsr_class.php` / `tsr_class_save.php` form.
library;

/// An interest option shown in the "Areas you can contribute to TSR" section.
class InterestOption {
  final int id;
  final String name;

  const InterestOption({required this.id, required this.name});

  factory InterestOption.fromJson(Map<String, dynamic> json) => InterestOption(
    id: (json['id'] ?? 0) as int,
    name: (json['name'] ?? '') as String,
  );
}

/// The student's saved class registration (used to pre-fill the form).
class ClassRegistration {
  final String? preferredLocation;
  final int? birthYear;
  final int? islamicStudyYears;
  final String? linkedinUrl;
  final String? residenceLocation;
  final String? workLocation;
  final String? education;
  final List<String> fieldOfStudy;
  final String? fieldOfStudyOther;
  final List<String> professionalCourses;
  final String? professionalCoursesOther;
  final String? occupationType;
  final String? fieldOfWork;
  final String? yearsExperience;
  final String? roleLevel;
  final String? otherInterests;
  final String? status;

  const ClassRegistration({
    this.preferredLocation,
    this.birthYear,
    this.islamicStudyYears,
    this.linkedinUrl,
    this.residenceLocation,
    this.workLocation,
    this.education,
    this.fieldOfStudy = const [],
    this.fieldOfStudyOther,
    this.professionalCourses = const [],
    this.professionalCoursesOther,
    this.occupationType,
    this.fieldOfWork,
    this.yearsExperience,
    this.roleLevel,
    this.otherInterests,
    this.status,
  });

  factory ClassRegistration.fromJson(Map<String, dynamic> json) =>
      ClassRegistration(
        preferredLocation: json['preferredLocation'] as String?,
        birthYear: json['birthYear'] as int?,
        islamicStudyYears: json['islamicStudyYears'] as int?,
        linkedinUrl: json['linkedinUrl'] as String?,
        residenceLocation: json['residenceLocation'] as String?,
        workLocation: json['workLocation'] as String?,
        education: json['education'] as String?,
        fieldOfStudy: List<String>.from(json['fieldOfStudy'] ?? const []),
        fieldOfStudyOther: json['fieldOfStudyOther'] as String?,
        professionalCourses: List<String>.from(
          json['professionalCourses'] ?? const [],
        ),
        professionalCoursesOther: json['professionalCoursesOther'] as String?,
        occupationType: json['occupationType'] as String?,
        fieldOfWork: json['fieldOfWork'] as String?,
        yearsExperience: json['yearsExperience'] as String?,
        roleLevel: json['roleLevel'] as String?,
        otherInterests: json['otherInterests'] as String?,
        status: json['status'] as String?,
      );
}

/// Full GET /registration response: saved registration + form options.
class ClassRegistrationFormData {
  final ClassRegistration? registration;
  final List<InterestOption> interestOptions;
  final List<int> selectedInterestIds;
  final Map<String, Map<String, String>> languages;

  const ClassRegistrationFormData({
    this.registration,
    this.interestOptions = const [],
    this.selectedInterestIds = const [],
    this.languages = const {},
  });

  factory ClassRegistrationFormData.fromJson(Map<String, dynamic> json) {
    final languagesRaw = json['languages'] as Map<String, dynamic>? ?? {};
    final languages = <String, Map<String, String>>{};
    languagesRaw.forEach((language, skills) {
      final skillMap = <String, String>{};
      if (skills is Map<String, dynamic>) {
        skills.forEach((skill, level) {
          skillMap[skill] = level?.toString() ?? '';
        });
      }
      languages[language] = skillMap;
    });

    return ClassRegistrationFormData(
      registration: json['registration'] != null
          ? ClassRegistration.fromJson(
              json['registration'] as Map<String, dynamic>,
            )
          : null,
      interestOptions: (json['interestOptions'] as List<dynamic>? ?? [])
          .map((e) => InterestOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedInterestIds: List<int>.from(
        json['selectedInterestIds'] ?? const [],
      ),
      languages: languages,
    );
  }
}
