import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/features/profile/models/geo.dart';
import 'package:the_strong_rope/features/profile/providers/profile_completion_provider.dart';

void main() {
  const india = GeoCountry(code: 'IN', name: 'India', hasPostalCodes: true);
  const tanzania = GeoCountry(
    code: 'TZ',
    name: 'Tanzania',
    hasPostalCodes: false,
  );

  test('a ZIP is required, as it always has been', () {
    expect(zipIsRequired(india), isTrue);
  });

  test('a country we cannot identify still needs one', () {
    expect(zipIsRequired(null), isTrue);
  });

  test(
    'except where the form hides the field: a country with no postal codes',
    () {
      expect(zipIsRequired(tanzania), isFalse);
    },
  );

  test(
    'a problem the location fields report is kept for the submit to read',
    () {
      final notifier = ProfileCompletionNotifier(ApiClient());
      expect(notifier.locationProblem, isNull);
      notifier.setLocationProblem('Choose your country from the list');
      expect(notifier.locationProblem, 'Choose your country from the list');
      notifier.setLocationProblem(null);
      expect(notifier.locationProblem, isNull);
    },
  );
}
