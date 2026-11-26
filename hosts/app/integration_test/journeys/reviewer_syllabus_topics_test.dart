import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/conduction_screen.dart';

/// The syllabus topic dropdowns, on the only class that has a syllabus.
///
/// This journey exists because the other four cannot reach the feature at all:
/// they run against `AYD1`, which is AMMAR, and only MIQDAD has a catalog — so
/// every one of them exercises the free-text fallback and none of them touches
/// a dropdown. `AYD2` was added to the cohort for exactly this.
///
/// Two things are checked, and they fail for different reasons:
///
///   1. **The list renders parts, not the stored string.** A topic chosen from
///      the syllabus is stored as `Topic :: Sub-topic :: detail`, and ' :: ' is
///      punctuation for a parser. If it reaches a chip, a teacher is reading
///      machine output — which is what shipped until it was caught by opening
///      the app rather than by any test.
///   2. **The form opens already split.** Parsing a stored value back into
///      three controls needs the catalog, which arrives over the network, so
///      this is the assertion that the two actually meet on a device.
///
/// **Triage a failure here as a fixture question first.** Both halves assert
/// against strings the migration writes. If the seed changed, this fails for a
/// reason that has nothing to do with the app — check
/// tsr-account `migrations/2026_09_06_reviewer_demo_cohort.sql` before the
/// Dart.
///
/// Nothing here saves. The form is read and the test ends.
///
/// See docs/specs/patrol-integration-testing/design.md
void main() {
  patrolAppTest('reviewer sees syllabus topics split into their parts',
      ($) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final conduction = ConductionScreenObject($);

    // The MIQDAD class, not the AMMAR one the other journeys use.
    await classes.miqdadClassCard.waitUntilVisible();
    await classes.miqdadClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await classes.classConductionAction.waitUntilVisible();
    await classes.classConductionAction.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // Arrival is asserted on the FAB rather than the app bar title, for the
    // reason recorded on ConductionScreenObject.addRecordButton.
    await conduction.addRecordButton.waitUntilVisible();

    // 1. The list shows the parts, joined readably.
    expect(conduction.syllabusTopicChip, findsOneWidget,
        reason: 'a syllabus topic must read as its parts, not as the value '
            'stored in class_sessions.arabic_topic');

    // The negative half matters as much as the positive one: the chip above
    // could read correctly while some other chip still leaked the separator.
    expect($(ConductionScreenObject.storedSeparator), findsNothing,
        reason: 'the stored separator is punctuation for a parser and must '
            'never appear on screen');

    // Free text from before the dropdowns existed is not reformatted at all.
    expect(conduction.legacyTopicChip, findsOneWidget,
        reason: "a teacher's own words must survive to the screen unchanged");

    // 2. The add form opens with the newest session's topic already split.
    await conduction.addRecordButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    // MIQDAD starts with Arabic, Aqaed, Ahkam and Akhlaq ticked, so Arabic's
    // controls are already there (reviewer_conduction_defaults_test.dart holds
    // that to account). Tapping the toggle now would untick it. It sits below
    // the fold on this form.
    await conduction.arabicToggle.scrollTo();

    // findsWidgets, not findsOneWidget: all four subjects start ticked, and
    // any of them the catalog covers shows its own Topic dropdown.
    expect(conduction.topicDropdown, findsWidgets,
        reason: 'MIQDAD has a catalog, so Arabic gets dropdowns rather than '
            'the free-text box');
    expect(conduction.subtopicDropdown, findsWidgets,
        reason: 'the sub-topic dropdown appears once a topic is chosen, and '
            'the prefill has already chosen one');

    expect(conduction.dropdownValue(ConductionScreenObject.syllabusTopic),
        findsWidgets,
        reason: 'the topic came back from the parse, not from a fresh form');
    expect(conduction.dropdownValue(ConductionScreenObject.syllabusSubtopic),
        findsWidgets,
        reason: 'the sub-topic is the second part of the stored value');

    await conduction.detailField.scrollTo();
    expect(conduction.detailField, findsOneWidget,
        reason: 'the optional third part survived the round trip, which is '
            'what proves the parse used the separator and not a guess');
  });
}
