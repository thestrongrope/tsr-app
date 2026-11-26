// `GET /students/{token}` and `GET /subscribers/{token}` (#557): the cards that
// global search opens for a person. They carry no contact details (#316).
//
// Strict about the envelope, tolerant about the rows, as for the reports: a
// body that is not a card throws, so the screen offers a retry.

/// One class a student is in that the viewer may see.
class StudentCardClass {
  const StudentCardClass({
    required this.id,
    required this.code,
    required this.level,
  });

  final int id;
  final String code;
  final String level;

  factory StudentCardClass.fromJson(Map<String, dynamic> json) =>
      StudentCardClass(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code'] as String? ?? '',
        level: json['level'] as String? ?? '',
      );
}

/// A member in a class, with only the classes the viewer reaches.
class StudentCard {
  const StudentCard({
    required this.token,
    required this.name,
    required this.gender,
    required this.classes,
  });

  final int token;
  final String name;

  /// 1 gents, 2 ladies; null when not recorded.
  final int? gender;
  final List<StudentCardClass> classes;

  /// Throws [FormatException] when [body] is not a student card.
  factory StudentCard.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> ||
        body['token'] is! num ||
        body['classes'] is! List) {
      throw const FormatException('student card: unexpected response');
    }
    return StudentCard(
      token: (body['token'] as num).toInt(),
      name: body['name'] as String? ?? '',
      gender: (body['gender'] as num?)?.toInt(),
      classes: [
        for (final c in body['classes'] as List)
          if (c is Map<String, dynamic>) StudentCardClass.fromJson(c),
      ],
    );
  }
}

/// A registered person who is not in a class; the super admin's to see.
class SubscriberCard {
  const SubscriberCard({
    required this.token,
    required this.name,
    required this.gender,
    required this.registeredOn,
    required this.requestedClass,
  });

  final int token;
  final String name;
  final int? gender;

  /// `YYYY-MM-DD` of their latest registration; null when they have none.
  final String? registeredOn;

  /// The code of the class they asked for; null when they asked for none.
  final String? requestedClass;

  /// Throws [FormatException] when [body] is not a subscriber card.
  factory SubscriberCard.fromJson(dynamic body) {
    if (body is! Map<String, dynamic> || body['token'] is! num) {
      throw const FormatException('subscriber card: unexpected response');
    }
    return SubscriberCard(
      token: (body['token'] as num).toInt(),
      name: body['name'] as String? ?? '',
      gender: (body['gender'] as num?)?.toInt(),
      registeredOn: body['registeredOn'] as String?,
      requestedClass: body['requestedClass'] as String?,
    );
  }
}
