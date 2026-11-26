// `GET /admin/donors` (#421): the people the web's Donors page lists, with the
// columns of its download. The server shows these to Finance and the super admin
// only.
//
// Strict about the envelope, tolerant about the rows, as for the reports: a body
// that is not this answer throws, so the screen offers a retry.

/// Text as sent, or empty for anything that is not text (a missing value): one
/// odd field must not stop the whole list from loading.
String _text(Object? value) => value is String ? value : '';

class Donor {
  const Donor({
    required this.name,
    required this.email,
    required this.mobile,
    required this.city,
    required this.state,
    required this.country,
    required this.zip,
  });

  final String name;
  final String email;
  final String mobile;
  final String city;
  final String state;
  final String country;
  final String zip;

  factory Donor.fromJson(Map<String, dynamic> json) => Donor(
    name: _text(json['name']),
    email: _text(json['email']),
    mobile: _text(json['mobile']),
    city: _text(json['city']),
    state: _text(json['state']),
    country: _text(json['country']),
    zip: _text(json['zip']),
  );

  /// What the search box matches against: every column the list shows.
  List<String> get searchFields => [
    name,
    email,
    mobile,
    city,
    state,
    country,
    zip,
  ];

  /// "city, state, country zip", leaving out what is not there.
  String get place {
    final region = [city, state, country].where((p) => p.isNotEmpty).join(', ');
    return [region, zip].where((p) => p.isNotEmpty).join(' ');
  }

  static List<Donor> listFromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['donors'] is! List) {
      throw const FormatException('donors is not a list');
    }
    return [
      for (final d in json['donors'] as List<dynamic>)
        if (d is Map<String, dynamic>) Donor.fromJson(d),
    ];
  }
}
