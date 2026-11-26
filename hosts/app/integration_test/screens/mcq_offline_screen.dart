import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

/// Finders for the offline-answers screen behind a published MCQ's Offline
/// action (#409).
///
/// Finders only, no assertions -- see [LoginScreenObject] for why.
class McqOfflineScreenObject {
  const McqOfflineScreenObject(this.$);

  final PatrolIntegrationTester $;

  // --- MCQ Management list --------------------------------------------------

  /// The first published quiz's action. Seeded demo quizzes are published.
  PatrolFinder get offlineAction => $('Offline');

  // --- Student picker -------------------------------------------------------

  PatrolFinder get showAllSwitch => $(SwitchListTile);
  PatrolFinder get firstStudent => $(CheckboxListTile);
  PatrolFinder get recordButton => $(RegExp(r'^Record answers \(1\)$'));

  // --- Question stepper -----------------------------------------------------

  PatrolFinder get firstQuestionTitle => $(AppBar).$(RegExp(r'^Question 1 of'));
  PatrolFinder get whoAnswered => $('Who answered correctly?');
}
