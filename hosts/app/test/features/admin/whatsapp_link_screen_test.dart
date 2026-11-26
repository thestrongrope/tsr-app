import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/services/secure_screen.dart';
import 'package:the_strong_rope/features/admin/models/whatsapp_link.dart';
import 'package:the_strong_rope/features/admin/providers/whatsapp_link_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/whatsapp_link_repository.dart';
import 'package:the_strong_rope/features/admin/screens/whatsapp_link_screen.dart';
import 'package:the_strong_rope/features/admin/widgets/whatsapp_link_card.dart';

// Made-up strings, not real QR codes.
const _codeA = 'FAKE-CODE-A';
const _codeB = 'FAKE-CODE-B';

class _Permissions extends PermissionsNotifier {
  _Permissions(List<String> permissions) {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: permissions,
        scopes: const PermissionScopes(gender: 1),
        issuedAt: '',
      ),
    );
  }
}

/// The server, as the screen sees it. What it answers is set per test; every
/// call is counted.
class _FakeLink implements WhatsappLinkRepository {
  WhatsappLinkStatus status = const WhatsappLinkStatus(
    state: WhatsappLinkState.connected,
  );
  WhatsappLinkQr qr = const WhatsappLinkQr(
    code: _codeA,
    ageSeconds: 12,
    validSeconds: 60,
  );
  Object? statusError;
  Object? changeError;
  int statusCalls = 0;
  int qrCalls = 0;
  int relinks = 0;
  int logouts = 0;

  @override
  Future<WhatsappLinkStatus> getStatus() async {
    statusCalls++;
    if (statusError != null) throw statusError!;
    return status;
  }

  @override
  Future<WhatsappLinkQr> getQr() async {
    qrCalls++;
    return qr;
  }

  @override
  Future<void> relink() async {
    relinks++;
    if (changeError != null) throw changeError!;
  }

  @override
  Future<void> logout() async {
    logouts++;
    if (changeError != null) throw changeError!;
  }
}

Widget _wrap(
  _FakeLink link, {
  Widget home = const WhatsappLinkScreen(),
  List<String> permissions = const ['whatsapp:manage:all'],
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    permissionsProvider.overrideWith((ref) => _Permissions(permissions)),
    whatsappLinkRepositoryProvider.overrideWithValue(link),
  ],
  child: MaterialApp(home: home),
);

Future<void> _tall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Closes the screen so its timer is cancelled before the test ends.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

Future<void> _open(WidgetTester tester, _FakeLink link) async {
  await _tall(tester);
  await tester.pumpWidget(_wrap(link));
  await tester.pump();
}

const _waiting = WhatsappLinkStatus(state: WhatsappLinkState.waiting);

void main() {
  secureScreenTests();
  testWidgets('connected shows the state and both controls, no code', (
    tester,
  ) async {
    final link = _FakeLink();
    await _open(tester, link);

    expect(find.text('Connected'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Re-link WhatsApp'), findsOneWidget);
    expect(find.text('Log out of WhatsApp'), findsOneWidget);
    expect(link.qrCalls, 0);
    await _close(tester);
  });

  testWidgets('offline says reminders will not be delivered', (tester) async {
    final link = _FakeLink()
      ..status = const WhatsappLinkStatus(state: WhatsappLinkState.offline);
    await _open(tester, link);

    expect(find.text('Offline'), findsOneWidget);
    expect(find.textContaining('not being delivered'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await _close(tester);
  });

  testWidgets('waiting shows the code, its age as it grows, and the notice', (
    tester,
  ) async {
    final link = _FakeLink()..status = _waiting;
    await _open(tester, link);

    expect(find.text('Waiting for a scan'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Code made 12 s ago'), findsOneWidget);
    expect(find.textContaining('from a different phone'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Code made 14 s ago'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a code that changes is redrawn at the next poll', (
    tester,
  ) async {
    final link = _FakeLink()..status = _waiting;
    await _open(tester, link);
    expect(find.byType(QrImageView), findsOneWidget);

    link.qr = const WhatsappLinkQr(
      code: _codeB,
      ageSeconds: 1,
      validSeconds: 60,
    );
    await tester.pump(const Duration(seconds: whatsappLinkPollSeconds));
    await tester.pump();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Code made 1 s ago'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a code the server withheld as stale is not drawn', (
    tester,
  ) async {
    final link = _FakeLink()
      ..status = _waiting
      ..qr = const WhatsappLinkQr(code: null, ageSeconds: 70, validSeconds: 60);
    await _open(tester, link);

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('expired'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('a code ages out on screen between polls', (tester) async {
    final link = _FakeLink()
      ..status = _waiting
      ..qr = const WhatsappLinkQr(
        code: _codeA,
        ageSeconds: 58,
        validSeconds: 60,
      );
    await _open(tester, link);
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('expired'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('no code yet says so', (tester) async {
    final link = _FakeLink()
      ..status = _waiting
      ..qr = const WhatsappLinkQr(
        code: null,
        ageSeconds: null,
        validSeconds: 60,
      );
    await _open(tester, link);

    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.textContaining('Waiting for WhatsApp to make a code'),
      findsOne,
    );
    await _close(tester);
  });

  testWidgets(
    'an unreachable service is said, retried, and never shows a code',
    (tester) async {
      final link = _FakeLink()
        ..status = _waiting
        ..statusError = ApiException(
          'The reminder service cannot be reached.',
          503,
        );
      await _open(tester, link);

      expect(find.text('The reminder service cannot be reached.'), findsOne);
      expect(find.textContaining('Trying again'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);

      link.statusError = null;
      await tester.pump(const Duration(seconds: whatsappLinkPollSeconds));
      await tester.pump();

      expect(
        find.text('The reminder service cannot be reached.'),
        findsNothing,
      );
      expect(find.byType(QrImageView), findsOneWidget);
      await _close(tester);
    },
  );

  testWidgets('a refused refresh drops the code that was showing', (
    tester,
  ) async {
    final link = _FakeLink()..status = _waiting;
    await _open(tester, link);
    expect(find.byType(QrImageView), findsOneWidget);

    link.statusError = ApiException('Too many requests.', 429);
    await tester.pump(const Duration(seconds: whatsappLinkPollSeconds));
    await tester.pump();

    expect(find.byType(QrImageView), findsNothing);
    await _close(tester);
  });

  testWidgets('re-link confirms with the warning; cancel does nothing', (
    tester,
  ) async {
    final link = _FakeLink();
    await _open(tester, link);

    await tester.tap(find.text('Re-link WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Every scheduled reminder'), findsOneWidget);
    expect(find.textContaining('gents and ladies'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(link.relinks, 0);
    await _close(tester);
  });

  testWidgets('confirming re-link calls it and polls for the new code', (
    tester,
  ) async {
    final link = _FakeLink();
    await _open(tester, link);
    final polls = link.statusCalls;

    await tester.tap(find.text('Re-link WhatsApp'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Re-link'));
    await tester.pumpAndSettle();

    expect(link.relinks, 1);
    expect(link.statusCalls, polls + 1);
    expect(find.textContaining('A new code will appear'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('logout confirms, calls it, and says reminders will not send', (
    tester,
  ) async {
    final link = _FakeLink();
    await _open(tester, link);

    await tester.tap(find.text('Log out of WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Every scheduled reminder'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(link.logouts, 1);
    expect(find.textContaining('Reminders will not send until'), findsOne);
    await _close(tester);
  });

  testWidgets('a failed change says so and keeps the previous state', (
    tester,
  ) async {
    final link = _FakeLink()
      ..changeError = ApiException(
        'Re-link failed. The link is unchanged.',
        502,
      );
    await _open(tester, link);

    await tester.tap(find.text('Re-link WhatsApp'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Re-link'));
    await tester.pumpAndSettle();

    expect(find.text('Re-link failed. The link is unchanged.'), findsOne);
    expect(find.text('Connected'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('leaving the foreground drops the code and stops polling', (
    tester,
  ) async {
    final link = _FakeLink()..status = _waiting;
    await _open(tester, link);
    expect(find.byType(QrImageView), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final calls = link.statusCalls;
    expect(find.byType(QrImageView), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    expect(link.statusCalls, calls);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(link.statusCalls, calls + 1);
    expect(find.byType(QrImageView), findsOneWidget);
    await _close(tester);
  });

  testWidgets('closing the screen stops polling', (tester) async {
    final link = _FakeLink()..status = _waiting;
    await _open(tester, link);
    await _close(tester);
    final calls = link.statusCalls;

    await tester.pump(const Duration(seconds: 10));

    expect(link.statusCalls, calls);
  });

  testWidgets('without whatsapp:manage there is nothing to ask or press', (
    tester,
  ) async {
    final link = _FakeLink();
    await _tall(tester);
    await tester.pumpWidget(_wrap(link, permissions: const []));
    await tester.pump(const Duration(seconds: 5));

    expect(link.statusCalls, 0);
    expect(find.text('Re-link WhatsApp'), findsNothing);
    expect(find.text('Log out of WhatsApp'), findsNothing);
    await _close(tester);
  });

  group('the reminders screen card', () {
    testWidgets('connected says linked, with no warning', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(
        _wrap(_FakeLink(), home: const Scaffold(body: WhatsappLinkCard())),
      );
      await tester.pumpAndSettle();

      expect(find.text('WhatsApp is linked.'), findsOneWidget);
      expect(find.textContaining('will not be delivered'), findsNothing);
    });

    testWidgets('not connected warns that reminders will not be delivered', (
      tester,
    ) async {
      final link = _FakeLink()
        ..status = const WhatsappLinkStatus(state: WhatsappLinkState.offline);
      await _tall(tester);
      await tester.pumpWidget(
        _wrap(link, home: const Scaffold(body: WhatsappLinkCard())),
      );
      await tester.pumpAndSettle();

      expect(find.text('WhatsApp is not linked.'), findsOneWidget);
      expect(find.textContaining('will not be delivered'), findsOneWidget);
    });

    testWidgets('opens the link screen', (tester) async {
      final link = _FakeLink();
      await _tall(tester);
      await tester.pumpWidget(
        _wrap(link, home: const Scaffold(body: WhatsappLinkCard())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('WhatsApp is linked.'));
      await tester.pump();
      await tester.pump();

      expect(find.text('WhatsApp link'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('is hidden without whatsapp:manage and asks nothing', (
      tester,
    ) async {
      final link = _FakeLink();
      await _tall(tester);
      await tester.pumpWidget(
        _wrap(
          link,
          permissions: const [],
          home: const Scaffold(body: WhatsappLinkCard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(link.statusCalls, 0);
    });
  });

  test('the QR code is held in memory only and never logged', () {
    // The code must not reach storage, a cache, a provider or a log line.
    final sources = [
      'lib/features/admin/screens/whatsapp_link_screen.dart',
      'lib/features/admin/models/whatsapp_link.dart',
      'lib/features/admin/repositories/whatsapp_link_repository.dart',
      'lib/features/admin/providers/whatsapp_link_provider.dart',
    ].map((p) => File(p).readAsStringSync()).join('\n');

    for (final banned in [
      'SharedPreferences',
      'FlutterSecureStorage',
      'File(',
      'print(',
      'debugPrint',
      'dart:developer',
    ]) {
      expect(sources.contains(banned), isFalse, reason: banned);
    }
    // No provider carries the QR; the only provider is the status.
    expect(
      File(
        'lib/features/admin/providers/whatsapp_link_provider.dart',
      ).readAsStringSync().contains('Qr'),
      isFalse,
    );
    expect(
      const WhatsappLinkQr(
        code: _codeA,
        ageSeconds: 1,
        validSeconds: 60,
      ).toString().contains(_codeA),
      isFalse,
    );
  });
}

void secureScreenTests() {
  const channel = MethodChannel('com.thestrongrope/secure_screen');

  group('secure screen (FLAG_SECURE)', () {
    final calls = <String>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('enabled while the code screen shows, disabled on close', (
      tester,
    ) async {
      final link = _FakeLink()..status = _waiting;
      await _open(tester, link);
      await tester.pump();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(calls, ['enable']);

      await _close(tester);
      expect(calls, ['enable', 'disable']);
    });

    testWidgets('never enabled for someone without access', (tester) async {
      await _tall(tester);
      await tester.pumpWidget(_wrap(_FakeLink(), permissions: const []));
      await tester.pump();
      await _close(tester);

      expect(calls, isNot(contains('enable')));
    });

    test('neither call throws when no handler exists', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await SecureScreen.enable();
      await SecureScreen.disable();
    });

    test('neither call throws when the platform refuses', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'nope');
          });
      await SecureScreen.enable();
      await SecureScreen.disable();
    });
  });
}
