import 'package:flutter/material.dart';
import 'package:patrol/patrol.dart';

/// Finders for MCQ Management's list, and the New Quiz form reached through
/// New MCQ, then the Standard MCQs library's custom-MCQ action.
///
/// Finders only, no assertions — see [LoginScreenObject] for why.
///
/// **The topic must be one no seeded quiz uses.** The demo cohort seeds AYD1
/// with quizzes on `Tawheed` and `Salaah`, so the Topic field opens as an
/// autocomplete with suggestions — the state in which a typed topic used to be
/// dropped unless a suggestion was tapped. A new topic never matches a
/// suggestion, so the journey types it and cannot pick it.
class McqEditScreenObject {
  const McqEditScreenObject(this.$);

  final PatrolIntegrationTester $;

  /// Written by the journey; the reset migration deletes every quiz on a demo
  /// class, so it is gone after the next reset.
  static const quizName = 'Patrol topic journey quiz';
  static const newTopic = 'Patrol Journey Topic';
  static const question = 'Who is the 7th Imam?';
  static const correctAnswer = 'Imam Musa e Kazim (as)';

  // --- MCQ Management list --------------------------------------------------

  /// Opens the Standard MCQs library, the default way to start an MCQ.
  PatrolFinder get newMcqButton => $(FloatingActionButton).$('New MCQ');

  /// In the library: the secondary link, or the primary button when the
  /// library is empty. Both carry this key; it opens the custom form.
  PatrolFinder get createCustomButton => $(const ValueKey('create_custom_mcq'));

  /// The list prints a quiz's topic under its name, so this appearing proves
  /// the topic reached the database, not merely that the form popped.
  PatrolFinder get savedTopic => $(newTopic);

  // --- New Quiz form --------------------------------------------------------

  PatrolFinder get formTitle => $(AppBar).$('New Quiz');
  PatrolFinder get nameField => $(TextFormField).containing('Quiz Name *');
  PatrolFinder get topicField => $(TextFormField).containing('Topic *');
  PatrolFinder get addQuestionButton =>
      $(OutlinedButton).containing('Add Question');
  PatrolFinder get questionField => $(TextFormField).containing('Question *');
  PatrolFinder get correctAnswerField =>
      $(TextFormField).containing('Correct Answer *');
  PatrolFinder get createButton => $(FilledButton).containing('Create Quiz');

  /// The empty-questions card, in its two states.
  PatrolFinder get topicFirstHint =>
      $('Enter a topic above to start adding questions.');
  PatrolFinder get readyHint =>
      $('No questions yet. Tap "Add Question" to get started.');

  bool get addQuestionEnabled =>
      $.tester.widget<OutlinedButton>(addQuestionButton.finder).onPressed !=
      null;
}
