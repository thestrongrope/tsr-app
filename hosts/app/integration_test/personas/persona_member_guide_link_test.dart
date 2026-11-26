import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/widgets/guide_content.dart';

import '../harness/app_links.dart';
import '../harness/patrol_app.dart';
import '../harness/persona_session.dart';

/// Persona journey: a signed-in student opens a guide from a guide link (#1138).
///
/// The link is delivered by the custom scheme, as in reviewer_article_link_test:
/// the router sees the same `/guide.php?guide=<slug>` as the https link. A link
/// naming a guide that does not exist says so and lists the guides; choosing
/// one opens it. It writes nothing. Needs the member to be enrolled in an
/// active class and the local database to hold a Miqdad guide.
void main() {
  patrolAppTest('a signed-in student opens a guide from its link', ($) async {
    await signInAs($, Persona.member);

    await openAppLink($, '/guide.php?guide=miqdad');
    await $(GuideBody).waitUntilVisible(timeout: const Duration(seconds: 30));

    await openAppLink($, '/guide.php?guide=patrol-no-such-guide');
    await $(
      'That guide does not exist. Choose one of these:',
    ).waitUntilVisible(timeout: const Duration(seconds: 30));

    await $('MIQDAD').tap();
    await $(GuideBody).waitUntilVisible(timeout: const Duration(seconds: 30));
    expect(find.byType(GuideBody), findsOneWidget);
  });
}
