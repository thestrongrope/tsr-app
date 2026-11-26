import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../screens/login_screen.dart';
import '../screens/publications_screen.dart';

/// A guest, straight in without signing in (#555), finds the publications in
/// the Library tab (#561), filters by language, and searches (#549).
///
/// No sign-in and no local data: the list comes live from thestrongrope.com,
/// which is the point — the widget tests feed the screen a fake list, and this
/// is the check that the real website's payload and the real tabs meet on a
/// device. A failure that names the network is a website question before it is
/// an app one.
///
/// Opening a publication is not tapped here. It hands the PDF to the phone's
/// browser, and waiting on the browser made the journey hang. The tap gets a
/// step when the app has its own viewer.
///
/// See docs/specs/mobile-publications/plan.md
void main() {
  patrolAppTest('guest opens a publication from the Library tab', ($) async {
    final login = LoginScreenObject($);
    final pubs = PublicationsScreenObject($);

    // The app opens on Home as a guest, inviting sign-in rather than asking.
    await login.inviteButton.waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );

    // In the Library tab, next to Articles and Videos, and open to a guest.
    await pubs.libraryTab.tap();
    await pubs.libraryItem.waitUntilVisible();
    await pubs.libraryItem.tap();
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await pubs.title.waitUntilVisible();
    expect(pubs.loadError, findsNothing,
        reason: 'the live list must load; a failure here names the website');

    // "All" plus the languages present, English among them.
    await pubs.allChip.waitUntilVisible();
    expect(pubs.englishChip, findsOneWidget);
    expect(pubs.cards, findsWidgets);

    // Choosing a language shows only it.
    await pubs.hindiChip.tap();
    await $.pumpAndSettle();
    expect(pubs.detailsIn('Hindi'), findsWidgets);
    expect(pubs.detailsIn('English'), findsNothing,
        reason: 'a language filter must hide every other language');

    // All shows every language again.
    await pubs.allChip.tap();
    await $.pumpAndSettle();
    expect(pubs.detailsIn('English'), findsWidgets);

    // Search narrows the list, and clearing it brings every one back.
    await pubs.searchField.enterText('zzzqqq');
    await $.pumpAndSettle();
    expect(pubs.noMatch, findsOneWidget);
    expect(pubs.cards, findsNothing);

    await pubs.clearSearch.tap();
    await $.pumpAndSettle();
    expect(pubs.cards, findsWidgets);
  });
}
