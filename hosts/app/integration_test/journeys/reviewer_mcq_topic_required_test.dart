import 'package:patrol/patrol.dart';

import '../harness/patrol_app.dart';
import '../harness/reviewer_session.dart';
import '../screens/class_list_screen.dart';
import '../screens/mcq_edit_screen.dart';
import '../screens/teacher_surface_screen.dart';

/// Regression journey for creating a class quiz: a topic comes first, and a
/// typed topic is the one that is saved.
///
/// Before the fix, the Topic field — an autocomplete once the class's existing
/// topics had loaded — kept typed text in its own controller, and the form
/// only copied it across when a suggestion was tapped. A topic that was typed
/// but not picked went out empty, and `POST /classes/{id}/mcq` answered
/// `422 topic is required` after the teacher had already written the
/// questions. Add Question was also live with no topic at all.
///
/// This journey drives the real screen against the real API:
///
/// 1. With no topic, Add Question is disabled and the form says why.
/// 2. Typing a topic that matches no suggestion enables it.
/// 3. Add Question opens a question card, which is filled in.
/// 4. Create Quiz succeeds, and the list shows the typed topic — proof that it
///    reached the database, not only that the form popped.
///
/// Step 3 also covers Add Question's scroll to the new card, which used to
/// call `Scrollable.of` from a context above the list and throw on every tap.
///
/// **Writes one quiz** to AYD1. The reset migration deletes every quiz on a
/// demo class, so the next reset — or `scripts/cleanup-demo-cohort.sh`, which
/// the runner calls on exit — removes it.
///
/// Assertions are Patrol waits or a thrown `StateError`, never `expect`: a
/// failing `expect` inside a Patrol test hangs until the watchdog without
/// reporting its reason. See the conduction journey and plan.md task 12.
void main() {
  patrolAppTest('reviewer must enter a topic before adding quiz questions', (
    $,
  ) async {
    await signInAsReviewer($);

    final classes = ClassListScreenObject($);
    final teacher = TeacherSurfaceScreenObject($);
    final quiz = McqEditScreenObject($);

    await classes.demoClassCard.waitUntilVisible();
    await classes.demoClassCard.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await teacher.mcqManageTile.scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await teacher.mcqManageTitle.waitUntilVisible();

    await quiz.newMcqButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await quiz.createCustomButton.waitUntilVisible();
    await quiz.createCustomButton.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));
    await quiz.formTitle.waitUntilVisible();

    // 1. No topic yet: the hint is the positive landmark, then the button.
    await quiz.nameField.enterText(McqEditScreenObject.quizName);
    await quiz.topicFirstHint.waitUntilVisible();
    if (quiz.addQuestionEnabled) {
      throw StateError(
        'Add Question is enabled with no topic entered; questions must wait '
        'for a topic, which the API requires.',
      );
    }

    // 2. A typed topic, not picked from the suggestions.
    await quiz.topicField.enterText(McqEditScreenObject.newTopic);
    await $.pumpAndSettle();
    await quiz.readyHint.waitUntilVisible();
    if (!quiz.addQuestionEnabled) {
      throw StateError(
        'Add Question is still disabled after typing a topic; the typed text '
        'is not reaching the form.',
      );
    }

    // 3. Add a question.
    await quiz.addQuestionButton.scrollTo().tap();
    await $.pumpAndSettle();
    await quiz.questionField.enterText(McqEditScreenObject.question);
    await quiz.correctAnswerField.enterText(McqEditScreenObject.correctAnswer);
    await $.pumpAndSettle();

    // 4. Save, then find the typed topic on the list.
    await quiz.createButton.scrollTo().tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await teacher.mcqManageTitle.waitUntilVisible();
    await quiz.savedTopic.waitUntilVisible();
  });
}
