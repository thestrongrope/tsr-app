import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/about/models/contact_links.dart';
import 'package:the_strong_rope/features/about/screens/about_screen.dart';
import 'package:the_strong_rope/features/about/screens/accreditation_screen.dart';
import 'package:the_strong_rope/features/about/screens/contact_screen.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';
import 'package:the_strong_rope/features/profile/presentation/me_screen.dart';

void main() {
  group('About routes', () {
    test('new pages are public', () {
      for (final route in [
        AppRoutes.about,
        AppRoutes.accreditation,
        AppRoutes.contact,
      ]) {
        expect(AppRoutes.isPublicRoute(route), isTrue, reason: route);
      }
    });
  });

  group('Me tab entries', () {
    testWidgets('About, Accreditation and Contact open their screens', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MeScreen()),
          GoRoute(
            path: AppRoutes.about,
            builder: (_, _) => const AboutScreen(),
          ),
          GoRoute(
            path: AppRoutes.accreditation,
            builder: (_, _) => const AccreditationScreen(),
          ),
          GoRoute(
            path: AppRoutes.contact,
            builder: (_, _) => const ContactScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            unreadNotificationCountProvider.overrideWithValue(0),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      const expectations = {
        'About': 'About Us',
        'Accreditation': 'Our Accreditation',
        'Contact': 'Contact & Socials',
      };
      for (final entry in expectations.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
        router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
    });
  });

  group('AboutScreen', () {
    testWidgets('renders Who we are and What we do', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

      expect(find.text('The Strong Rope'), findsOneWidget);
      expect(find.text('Who we are'), findsOneWidget);
      expect(find.text('What we do'), findsOneWidget);
      expect(
        find.text('A cultural, religious, and social organization'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Connect with us'), 300);
      expect(find.text('Connect with us'), findsOneWidget);
    });
  });

  group('AccreditationScreen', () {
    testWidgets('renders endorsements and letter cards', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AccreditationScreen()));

      expect(find.text('Our Accreditation'), findsOneWidget);
      expect(find.text('Endorsements'), findsOneWidget);
      expect(find.textContaining('Zeeshan Haider Zaidi'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Authority letters'), 300);
      expect(find.text('Authority letters'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Authority letter — English'),
        300,
      );
      expect(find.text('Authority letter — English'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Authority letter — Farsi'),
        300,
      );
      expect(find.text('Authority letter — Farsi'), findsOneWidget);
    });
  });

  group('ContactScreen', () {
    testWidgets('lists all seven channels', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContactScreen()));

      for (final link in contactLinks) {
        expect(find.text(link.label), findsOneWidget);
      }
      expect(contactLinks, hasLength(7));
    });

    testWidgets('tapping WhatsApp opens the wa.me link', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ContactScreen(
            launch: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.text('WhatsApp'));
      await tester.pump();

      expect(opened, [Uri.parse('https://wa.me/918070151412')]);
    });

    testWidgets('failed open shows an error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ContactScreen(launch: (_) async => false)),
      );

      await tester.tap(find.text('Telegram'));
      await tester.pump();

      expect(find.text("Couldn't open Telegram."), findsOneWidget);
    });
  });
}
