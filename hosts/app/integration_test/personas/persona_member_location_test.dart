import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: worldwide location entry on Edit Profile (#443).
///
/// A postal code that matches fills State and City from our own copy of GeoNames
/// and locks them; a code that does not match is left as typed (State and City are
/// editable again, with a note); clearing the code frees them. The persona member is
/// saved as India / Maharashtra / Pune / 411001, a code we hold, so State and City
/// open locked. The journey changes the code to 110001 (Delhi and New Delhi, locked),
/// to 999999 (editable, values kept, a note), to 400001 (Mumbai, locked), then clears
/// the code and expects both editable.
///
/// **Needs the GeoNames data loaded** in the local database: run
/// `php tools/geonames/load.php` once in the webapp container after the geo
/// migrations. Without it the lookup finds nothing and this journey says so in
/// its failure, instead of timing out as a mystery.
///
/// Does not save: the profile is left as it was, and the runner rebuilds the
/// persona fixtures before every journey anyway.
void main() {
  patrolAppTest('a postal code fills the state and suggests a city', ($) async {
    await signInAs($, Persona.member);

    await pushRoute($, '/profile/edit');
    await $('Location details').scrollTo();

    PatrolFinder field(String label) => $(TextFormField).containing(label);
    bool enabled(String label) => $.tester
        .widget<TextField>(
          find.descendant(
            of: field(label).finder,
            matching: find.byType(TextField),
          ),
        )
        .enabled!;

    await field('POSTAL CODE').scrollTo();
    await field('POSTAL CODE').enterText('110001');

    try {
      // 500 ms debounce, then a call to our own /geo/postal. waitUntilExists,
      // not waitUntilVisible: a locked field is a disabled TextField, which
      // ignores pointers, so its text is never hit-testable.
      await $('Delhi').waitUntilExists(timeout: const Duration(seconds: 20));
    } catch (_) {
      throw StateError(
        'The postal code 110001 did not fill the state. The GeoNames tables '
        'are probably empty: run `php tools/geonames/load.php` in the webapp '
        'container (see docs/specs/location-entry/plan.md).',
      );
    }
    expect(
      $('New Delhi'),
      findsWidgets,
      reason: 'the commonest district for the code is suggested as the city',
    );
    expect(
      enabled('STATE/PROVINCE'),
      isFalse,
      reason: 'State follows a postal code we hold, so it is locked',
    );
    expect(
      enabled('CITY'),
      isFalse,
      reason: 'City follows a postal code we hold, so it is locked',
    );

    // The postal code is a helper: one that does not match is not an error. There is
    // nothing to replace what was typed, so State and City are theirs again, keeping
    // their values, and a note says so.
    await field('POSTAL CODE').enterText('999999');
    // waitUntilExists: the note sits below City, under the fold since the tabs
    // took the bottom of the screen (#561).
    await $(
      RegExp('We do not have that postal code'),
    ).waitUntilExists(timeout: const Duration(seconds: 20));
    expect(enabled('STATE/PROVINCE'), isTrue);
    expect(enabled('CITY'), isTrue);
    expect($('Delhi'), findsWidgets, reason: 'what was there stays');

    // A matching code locks them again, and clearing it frees them.
    await field('POSTAL CODE').enterText('400001');
    await $('Mumbai').waitUntilExists(timeout: const Duration(seconds: 20));
    expect(enabled('CITY'), isFalse);
    await field('POSTAL CODE').enterText('');
    await $.pumpAndSettle(timeout: const Duration(seconds: 10));
    expect(enabled('STATE/PROVINCE'), isTrue);
    expect(enabled('CITY'), isTrue);

    // The credit that CC BY 4.0 asks for, where the data shows.
    await $('Place suggestions from GeoNames (CC BY 4.0)').scrollTo();
    expect($('Place suggestions from GeoNames (CC BY 4.0)'), findsOneWidget);

    await popRoute($);
  });
}
