// Worldwide location entry (#443): the shapes the /geo routes answer with.
// The data is GeoNames' (CC BY 4.0), held on our own server.

class GeoCountry {
  final String code;
  final String name;

  /// Whether we hold postal codes for the country. When false, the city
  /// search is the only way to fill the place in.
  final bool hasPostalCodes;

  const GeoCountry({
    required this.code,
    required this.name,
    required this.hasPostalCodes,
  });

  factory GeoCountry.fromJson(Map<String, dynamic> json) => GeoCountry(
    code: json['code'] as String,
    name: json['name'] as String? ?? '',
    hasPostalCodes: json['hasPostalCodes'] == true,
  );
}

/// What a postal code says: the state reliably, the city only approximately.
class GeoPostalResult {
  final String? city;
  final String? state;

  const GeoPostalResult({this.city, this.state});
}

class GeoCity {
  final String name;
  final String? state;

  const GeoCity({required this.name, this.state});

  factory GeoCity.fromJson(Map<String, dynamic> json) => GeoCity(
    name: json['name'] as String? ?? '',
    state: json['state'] as String?,
  );
}
