import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/geo.dart';
import '../repositories/geo_repository.dart';

final geoRepositoryProvider = Provider<GeoRepository>((ref) => GeoRepository());

/// The countries to pick from. Held for the session: the list does not change.
/// An error (offline) is handled by the form: the country field is disabled and
/// offers a retry.
final geoCountriesProvider = FutureProvider<List<GeoCountry>>((ref) {
  return ref.watch(geoRepositoryProvider).countries();
});
