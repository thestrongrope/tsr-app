import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../screens/login_screen.dart';
import '../screens/release_notes_screen.dart';

/// A guest, signed in to nothing, sees the installed version in the Me tab and
/// opens the release notes from it (#556).
///
/// No sign-in and no demo cohort: `GET /release-notes` is public. The widget
/// tests feed the screen a fake list, and this is the check that the real
/// endpoint, the guest's Me tab and the route meet on a device. A failure that
/// names "could not be loaded" is a question for the server's
/// `web/data/app_versions.json` before it is one for the app.
void main() {
  patrolAppTest('guest opens the release notes from the Me tab', ($) async {
    final login = LoginScreenObject($);
    final notes = ReleaseNotesScreenObject($);

    await login.inviteButton.waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );

    // The Me tab invites a guest to sign in, and still shows the version.
    await notes.meTab.tap();
    await notes.versionRow.waitUntilVisible();
    await notes.versionRow.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await notes.title.waitUntilVisible();
    expect(notes.loadError, findsNothing,
        reason: 'the public endpoint must answer a guest');
    expect(notes.noNotes, findsNothing,
        reason: 'the catalog carries the releases from 1.1.0 onward');
    expect(notes.cards, findsWidgets);
  });
}
