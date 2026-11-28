import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/core/widgets/offline_banner.dart';

void main() {
  late StreamController<List<ConnectivityResult>> controller;

  setUp(() => controller = StreamController<List<ConnectivityResult>>());
  tearDown(() => controller.close());

  Future<void> pumpBanner(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStreamProvider.overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(
          home: OfflineBanner(child: Scaffold(body: Text('content'))),
        ),
      ),
    );
  }

  Future<void> emit(
    WidgetTester tester,
    List<ConnectivityResult> results,
  ) async {
    controller.add(results);
    await tester.pump();
  }

  final banner = find.text(OfflineBanner.message);
  const none = [ConnectivityResult.none];

  testWidgets('nothing is shown before the first result', (tester) async {
    await pumpBanner(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(banner, findsNothing);
  });

  testWidgets('offline for under two seconds shows nothing', (tester) async {
    await pumpBanner(tester);
    await emit(tester, none);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(banner, findsNothing);
    await emit(tester, [ConnectivityResult.wifi]);
    await tester.pump(const Duration(seconds: 5));
    expect(banner, findsNothing);
  });

  testWidgets('offline for two seconds shows the banner', (tester) async {
    await pumpBanner(tester);
    await emit(tester, none);
    await tester.pump(offlineBannerDelay);
    expect(banner, findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('coming back online hides it at once', (tester) async {
    await pumpBanner(tester);
    await emit(tester, none);
    await tester.pump(offlineBannerDelay);
    expect(banner, findsOneWidget);
    await emit(tester, [ConnectivityResult.mobile]);
    expect(banner, findsNothing);
  });

  testWidgets('an empty list counts as offline', (tester) async {
    await pumpBanner(tester);
    await emit(tester, const []);
    await tester.pump(offlineBannerDelay);
    expect(banner, findsOneWidget);
  });

  testWidgets('none alongside another network is online', (tester) async {
    await pumpBanner(tester);
    await emit(tester, [ConnectivityResult.none, ConnectivityResult.wifi]);
    await tester.pump(const Duration(seconds: 5));
    expect(banner, findsNothing);
  });

  testWidgets('the banner is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpBanner(tester);
    await emit(tester, none);
    await tester.pump(offlineBannerDelay);
    expect(
      tester.getSemantics(banner),
      matchesSemantics(label: OfflineBanner.message, isLiveRegion: true),
    );
    handle.dispose();
  });
}
