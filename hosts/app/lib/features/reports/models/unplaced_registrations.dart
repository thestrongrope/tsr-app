import 'dart:convert';

// `GET /reports/registrations` (#605, #614): who has registered and is waiting
// to be placed in a class, with every detail the web registrations page shows
// them. The server shows this only to whoever the web page shows it to.
//
// Strict about the envelope, tolerant about the rows, as for the other
// reports: a body that is not this report throws, so the screen offers a retry.

/// One person waiting to be placed.
class Registrant {
  const Registrant({
    required this.name,
    required this.city,
    required this.country,
    required this.preferredLocation,
    required this.requestedClass,
    required this.status,
    required this.registeredOn,
    this.id = 0,
    this.token = 0,
    this.email = '',
    this.mobile = '',
    this.residenceLocation = '',
    this.workLocation = '',
    this.birthYear,
    this.classLevel = '',
    this.classNumber = '',
    this.profession = '',
    this.islamicStudyYears = '',
    this.interests = '',
    this.zip = '',
  });

  /// The registration to place or reject; what the place and reject calls take.
  final int id;

  /// The member's token, as the web details panel shows it.
  final int token;

  final String name;

  /// Empty when they gave none.
  final String city;
  final String country;
  final String preferredLocation;

  /// The code of the class they asked for; empty when they asked for none.
  final String requestedClass;

  /// `Pending` or `Accepted`.
  final String status;

  /// `YYYY-MM-DD`.
  final String registeredOn;

  final String email;
  final String mobile;
  final String residenceLocation;
  final String workLocation;
  final int? birthYear;
  final String classLevel;
  final String classNumber;
  final String profession;
  final String islamicStudyYears;

  /// As stored: usually a JSON list in a string; see [interestList].
  final String interests;
  final String zip;

  /// "Dubai, AE", "Dubai" or "": where they are, as far as they said.
  String get place => [city, country].where((p) => p.isNotEmpty).join(', ');

  /// Age in [now]'s year, as the web works it out; null when no birth year.
  int? ageIn(DateTime now) => birthYear == null ? null : now.year - birthYear!;

  /// The interests as separate words: the stored JSON list when it is one,
  /// else the text split on commas.
  List<String> get interestList {
    if (interests.isEmpty) return const [];
    try {
      final decoded = jsonDecode(interests);
      if (decoded is List) {
        return [
          for (final i in decoded)
            if (i.toString().trim().isNotEmpty) i.toString().trim(),
        ];
      }
    } on FormatException {
      // Not JSON: plain text, below.
    }
    return [
      for (final i in interests.split(','))
        if (i.trim().isNotEmpty) i.trim(),
    ];
  }

  factory Registrant.fromJson(Map<String, dynamic> json) => Registrant(
    id: (json['id'] as num?)?.toInt() ?? 0,
    token: (json['token'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    country: json['country'] as String? ?? '',
    preferredLocation: json['preferredLocation'] as String? ?? '',
    requestedClass: json['requestedClass'] as String? ?? '',
    status: json['status'] as String? ?? '',
    registeredOn: json['registeredOn'] as String? ?? '',
    email: json['email'] as String? ?? '',
    mobile: json['mobile'] as String? ?? '',
    residenceLocation: json['residenceLocation'] as String? ?? '',
    workLocation: json['workLocation'] as String? ?? '',
    birthYear: (json['birthYear'] as num?)?.toInt(),
    classLevel: json['classLevel'] as String? ?? '',
    classNumber: json['classNumber'] as String? ?? '',
    profession: json['profession'] as String? ?? '',
    islamicStudyYears: json['islamicStudyYears'] as String? ?? '',
    interests: json['interests'] as String? ?? '',
    zip: json['zip'] as String? ?? '',
  );
}

/// A class a waiting registrant could be placed in, with what the web page
/// shows on choosing it (`GET /registrations/{id}/classes`, #614).
class PlacementClass {
  const PlacementClass({
    required this.id,
    required this.code,
    required this.level,
    required this.teacher,
    required this.location,
    required this.students,
  });

  final int id;
  final String code;
  final String level;

  /// Empty when the class has no teacher on record.
  final String teacher;
  final String location;
  final int students;

  factory PlacementClass.fromJson(Map<String, dynamic> json) => PlacementClass(
    id: (json['id'] as num?)?.toInt() ?? 0,
    code: json['code'] as String? ?? '',
    level: json['level'] as String? ?? '',
    teacher: json['teacher'] as String? ?? '',
    location: json['location'] as String? ?? '',
    students: (json['students'] as num?)?.toInt() ?? 0,
  );

  /// Throws [FormatException] when [body] is not this answer.
  static List<PlacementClass> listFromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['classes'] is! List) {
      throw const FormatException('registration classes: unexpected response');
    }
    return [
      for (final c in body['classes'] as List)
        if (c is Map<String, dynamic>) PlacementClass.fromJson(c),
    ];
  }
}

class UnplacedRegistrations {
  const UnplacedRegistrations({
    required this.gender,
    required this.registrants,
  });

  /// 1 gents, 2 ladies: the gender the server answered for.
  final int gender;

  /// Newest first.
  final List<Registrant> registrants;

  /// Throws [FormatException] when [body] is not this report.
  factory UnplacedRegistrations.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['registrants'] is! List) {
      throw const FormatException('registrations: unexpected response');
    }
    return UnplacedRegistrations(
      gender: (body['gender'] as num?)?.toInt() ?? 1,
      registrants: [
        for (final r in body['registrants'] as List)
          if (r is Map<String, dynamic>) Registrant.fromJson(r),
      ],
    );
  }
}

/// How far back the registrations screen looks, as the web page's menu offers.
enum RegistrationPeriod {
  threeMonths('Last 3 months'),
  sixMonths('Last 6 months'),
  oneYear('Last year'),
  all('All');

  const RegistrationPeriod(this.label);

  final String label;

  /// Whether someone who registered on [registeredOn] (`YYYY-MM-DD`) falls in
  /// this period counted back from [now]. A date that cannot be read is kept
  /// rather than hidden.
  bool includes(String registeredOn, DateTime now) {
    final months = switch (this) {
      RegistrationPeriod.threeMonths => 3,
      RegistrationPeriod.sixMonths => 6,
      RegistrationPeriod.oneYear => 12,
      RegistrationPeriod.all => null,
    };
    if (months == null) return true;
    final date = DateTime.tryParse(registeredOn);
    if (date == null) return true;
    return date.isAfter(DateTime(now.year, now.month - months, now.day));
  }
}
