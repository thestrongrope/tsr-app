import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The platform files that claim the TSR hosts for join and MCQ links
/// (#795, #859). Nothing else on those hosts may open in the app.
void main() {
  const hosts = [
    'account.thestrongrope.com',
    'thestrongrope.com',
    'www.thestrongrope.com',
  ];

  // Articles live on the website hosts only (#1121); parent invites on the
  // account host only (#1122), and guide links too (#1138).
  const hostPrefixes = {
    'account.thestrongrope.com': ['/join/', '/mcq/', '/link/', '/guide.php'],
    'thestrongrope.com': ['/join/', '/mcq/', '/articles/'],
    'www.thestrongrope.com': ['/join/', '/mcq/', '/articles/'],
  };

  test('Android verifies each host for its own paths only', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final filters = RegExp(
      r'<intent-filter android:autoVerify="true">(.*?)</intent-filter>',
      dotAll: true,
    ).allMatches(manifest).map((m) => m.group(1)!).toList();

    expect(filters, hasLength(hosts.length));
    for (final host in hosts) {
      final filter = filters.singleWhere(
        (f) => f.contains('android:host="$host"'),
      );
      expect(filter, contains('android:scheme="https"'));
      expect(filter, contains('android.intent.category.BROWSABLE'));
      final prefixes = hostPrefixes[host]!;
      for (final prefix in prefixes) {
        expect(filter, contains('android:pathPrefix="$prefix"'));
      }
      expect(
        RegExp('pathPrefix').allMatches(filter),
        hasLength(prefixes.length),
      );
    }
    expect(manifest, contains('android:scheme="thestrongrope"'));
  });

  test('both iOS entitlement files list the hosts and keep the old ones', () {
    for (final name in ['Runner', 'Release']) {
      final plist = File('ios/Runner/$name.entitlements').readAsStringSync();
      for (final host in hosts) {
        expect(
          plist,
          contains('<string>applinks:$host</string>'),
          reason: name,
        );
      }
      expect(plist, contains('applinks:the-strong-rope.firebaseapp.com'));
      expect(plist, contains('applinks:the-strong-rope.page.link'));
    }
  });

  // The website hosts' file is served by this repo's site. The account host's
  // file (invite and guide links) is served by the PHP app in tsr-account and
  // is checked there.
  test('the website file claims join, MCQ and article links', () {
    final aasa = File(
      '../site/wwwroot/.well-known/apple-app-site-association',
    ).readAsStringSync();
    final components =
        (jsonDecode(aasa)['applinks']['details'][0]['components']
            as List<dynamic>);
    expect(components, [
      {'/': '/join/*'},
      {'/': '/mcq/*'},
      {'/': '/articles/*'},
    ]);
    expect(aasa, contains('6GBKBN5BK5.com.thestrongrope'));
  });
}
