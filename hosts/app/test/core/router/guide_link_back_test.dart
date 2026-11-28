import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/router/guide_link_entry.dart';
import 'package:the_strong_rope/core/router/route_config.dart';

/// While the app is open on another screen, a guide link opens the guide on
/// top of it, and going back returns to that screen (#1138, GUIDE-R5). The
/// operating system hands the link to the router as new route information.
void main() {
  GoRouter buildRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    onEnter: GuideLinkEntry().call,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home page')),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('Login page')),
      ),
      GoRoute(
        path: AppRoutes.guideLink,
        builder: (_, state) => Scaffold(
          appBar: AppBar(title: const Text('Guide page')),
          body: Text('slug ${state.uri.queryParameters['guide']}'),
        ),
      ),
    ],
  );

  Future<void> deliver(WidgetTester tester, String location) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': location}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a link arriving over an open screen opens on top of it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter('/home')),
    );
    await tester.pumpAndSettle();

    await deliver(tester, '/guide.php?guide=miqdad');
    expect(find.text('slug miqdad'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('a second link opens on top of the first, one back at a time', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter('/home')),
    );
    await tester.pumpAndSettle();

    await deliver(tester, '/guide.php?guide=miqdad');
    await deliver(tester, '/guide.php?guide=ammar');
    expect(find.text('slug ammar'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('slug miqdad'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
  });

  testWidgets('a link that starts the app opens the guide itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter('/guide.php?guide=miqdad')),
    );
    await tester.pumpAndSettle();

    expect(find.text('slug miqdad'), findsOneWidget);
  });

  testWidgets('a link arriving at the sign-in screen is let through', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter(AppRoutes.login)),
    );
    await tester.pumpAndSettle();

    await deliver(tester, '/guide.php?guide=miqdad');

    expect(find.text('slug miqdad'), findsOneWidget);
  });
}
