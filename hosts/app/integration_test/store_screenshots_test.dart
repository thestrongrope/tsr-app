// Drives the guest-reachable screens and pauses on each one so the host can
// capture it with `xcrun simctl io screenshot`.
//
// Deliberately not under journeys/ -- it asserts almost nothing and must not
// join the suite that scripts/patrol-android.sh globs. patrol_cli insists on a
// _test.dart suffix, which is why it carries one despite not being a test.
//
// Guest screens only. Apple's Guideline 2.3.9 wants fictional data in
// screenshots, and these four carry no member data by construction.
//
// Synchronisation is by marker file, not by print: Dart stdout from inside the
// test does not reach patrol_cli's own stdout, so the host cannot watch for it.
// The simulator's tmp directory is an ordinary host directory, reachable via
// `xcrun simctl get_app_container <udid> <bundle id> data`, so a file written
// here shows up there immediately.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/latest_articles.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/latest_videos.dart';

import 'harness/patrol_app.dart';
import 'harness/persona_session.dart';
import 'screens/login_screen.dart';

/// Long enough that the host always wins the race, short enough that five
/// screens still finish inside one patrol invocation.
const _dwell = Duration(seconds: 8);

/// Lets thumbnails finish loading before the screen is held for the camera.
const _imagesLoad = Duration(seconds: 2);

const _settle = Duration(seconds: 30);

Future<void> _capture(PatrolIntegrationTester $, String name) async {
  await $.pumpAndSettle();
  await Future<void>.delayed(_imagesLoad);
  File('${Directory.systemTemp.path}/shot-$name').writeAsStringSync('ready');
  await Future<void>.delayed(_dwell);
}

void main() {
  patrolAppTest('capture the App Store screenshot set', ($) async {
    final login = LoginScreenObject($);

    // The app opens on Home as a guest (#555); its invitation opens sign-in,
    // and going back returns to Home.
    await login.inviteButton.waitUntilVisible(timeout: _settle);
    await login.inviteButton.tap();
    await $.pumpAndSettle(timeout: _settle);
    await _capture($, '05-signin');

    await popRoute($);
    await _capture($, '01-home');

    // The section headers' 'View all' buttons go straight to the lists. There
    // are two of them -- Latest Articles and Latest Videos -- hence the
    // scoping.
    await $(LatestArticles).$('View all').tap();
    await $.pumpAndSettle(timeout: _settle);
    await _capture($, '02-articles');

    // 'View all' lands on AllArticlesScreen, whose rows are a private
    // _ArticleListTile wrapping a Card -- so the Card is the only public
    // handle on a row.
    await $(Card).at(0).waitUntilVisible();
    await $(Card).at(0).tap();
    await $.pumpAndSettle(timeout: _settle);
    await _capture($, '03-article');

    // iOS has no system back button, so this pops through the AppBar's. Not
    // BackButton: TsrArticleDetailScreen supplies its own `leading` IconButton,
    // so Flutter never inserts the stock one.
    await $(Icons.arrow_back).tap();
    await $.pumpAndSettle(timeout: _settle);
    await $(Icons.arrow_back).tap();
    await $.pumpAndSettle(timeout: _settle);

    await $(LatestVideos).$('View all').tap();
    await $.pumpAndSettle(timeout: _settle);
    await _capture($, '04-videos');

    // Back to Home, then the Library tab, where every TSR publication opens in
    // the app (#554).
    // Through the router rather than the AppBar's icon: iOS draws a different
    // back icon from Android's.
    await popRoute($);
    await openTab($, 'Library');
    await $.pumpAndSettle(timeout: _settle);
    await _capture($, '06-library');
  });
}
