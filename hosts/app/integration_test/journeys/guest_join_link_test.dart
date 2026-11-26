import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/patrol_app.dart';
import '../screens/login_screen.dart';

/// A join link tapped outside the app opens the app on the join screen (#795).
///
/// The widget tests prove the router and the screen; this is the check that
/// the Android intent filter, the platform and the router meet on a device.
/// The link names a code no class has, so the journey needs no data: the real
/// `GET /join/{code}` answers 404 and the screen says so. A failure where the
/// browser opened instead of the app is the manifest's intent filter (or, on
/// a release build, the domain's assetlinks.json), not the screen.
void main() {
  patrolAppTest('a join link opens the app on the join screen', ($) async {
    final login = LoginScreenObject($);

    await login.inviteButton.waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );

    await $.platform.mobile.openUrl(
      'https://account.thestrongrope.com/join/patrol-no-such-class',
    );
    await $.pumpAndSettle(timeout: const Duration(seconds: 30));

    await $(AppBar).$('Join a class').waitUntilVisible(
      timeout: const Duration(seconds: 30),
    );
    expect(
      $('We could not find this class. The link may be wrong.'),
      findsOneWidget,
    );
  });
}
