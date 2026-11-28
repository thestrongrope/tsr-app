import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/core/widgets/bottom_nav_scaffold.dart';
import 'package:the_strong_rope/core/widgets/glass_bottom_nav_bar.dart';
import 'package:the_strong_rope/core/widgets/tab_bar_inset.dart';
import 'package:the_strong_rope/features/about/screens/about_screen.dart';
import 'package:the_strong_rope/features/admin/providers/syllabus_admin_provider.dart';
import 'package:the_strong_rope/features/admin/screens/syllabus_admin_screen.dart';
import 'package:the_strong_rope/features/classes/models/syllabus_model.dart';
import 'package:the_strong_rope/features/classes/screens/guide_translate_screen.dart';
import 'package:the_strong_rope/features/about/screens/accreditation_screen.dart';
import 'package:the_strong_rope/features/about/screens/contact_screen.dart';
import 'package:the_strong_rope/features/auth/providers/auth_provider.dart';
import 'package:the_strong_rope/features/notifications/providers/user_notifications_provider.dart';
import 'package:the_strong_rope/features/profile/presentation/me_screen.dart';

class _Guest extends PermissionsNotifier {
  _Guest() {
    state = PermissionsState(
      payload: PermissionsPayload(
        version: 4,
        permissions: const [],
        scopes: const PermissionScopes(),
        issuedAt: '',
      ),
    );
  }
}

/// A phone with a home-indicator inset, so the tests prove the inset is used.
void _phone(WidgetTester tester, {double height = 640}) {
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(bottom: 34);
  addTearDown(tester.view.reset);
}

/// [page] as the only screen of the Home tab, inside the real tab scaffold.
Future<void> _pumpInShell(
  WidgetTester tester,
  Widget page, {
  List<Override> overrides = const [],
  double height = 640,
}) async {
  _phone(tester, height: height);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            BottomNavScaffold(navigationShell: shell),
        branches: [
          for (final name in ['home', 'library', 'me'])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/$name',
                  builder: (context, state) =>
                      name == 'home' ? page : const SizedBox(),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unreadNotificationCountProvider.overrideWithValue(0),
        currentUserProvider.overrideWithValue(null),
        permissionsProvider.overrideWith((ref) => _Guest()),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

double _barTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(GlassBottomNavBar)).dy;

/// Scrolls the page's first scroll view to its end, then returns how far the
/// lowest piece of text on the page is below the bar's top (<= 0 is clear).
Future<double> _overlapAtEnd(WidgetTester tester) async {
  final position = tester.state<ScrollableState>(find.byType(Scrollable).first);
  position.position.jumpTo(position.position.maxScrollExtent);
  await tester.pump(const Duration(seconds: 1));

  var lowest = 0.0;
  for (final element
      in find
          .descendant(
            of: find.byType(Scaffold).first,
            matching: find.byType(Text),
            skipOffstage: true,
          )
          .evaluate()) {
    if (find
        .descendant(
          of: find.byType(GlassBottomNavBar),
          matching: find.byWidget(element.widget),
        )
        .evaluate()
        .isNotEmpty) {
      continue;
    }
    final box = element.renderObject! as RenderBox;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    if (bottom > lowest) lowest = bottom;
  }
  return lowest - _barTop(tester);
}

List<Widget> _rows(int n) => [
  for (var i = 0; i < n; i++)
    Padding(padding: const EdgeInsets.all(12), child: Text('row $i')),
];

void main() {
  group('the page scrolls behind the bar and still ends above it (#1022)', () {
    testWidgets('a ListView with its own padding', (tester) async {
      await _pumpInShell(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ListView(
              padding: withTabBarInset(context, const EdgeInsets.all(16)),
              children: _rows(40),
            ),
          ),
        ),
      );
      expect(await _overlapAtEnd(tester), lessThanOrEqualTo(0));
    });

    testWidgets('a ListView with no padding of its own', (tester) async {
      await _pumpInShell(tester, Scaffold(body: ListView(children: _rows(40))));
      expect(await _overlapAtEnd(tester), lessThanOrEqualTo(0));
    });

    testWidgets('a SingleChildScrollView', (tester) async {
      await _pumpInShell(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => SingleChildScrollView(
              padding: withTabBarInset(context),
              child: Column(children: _rows(40)),
            ),
          ),
        ),
      );
      expect(await _overlapAtEnd(tester), lessThanOrEqualTo(0));
    });

    testWidgets('a CustomScrollView with the inset sliver', (tester) async {
      await _pumpInShell(
        tester,
        Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverList.list(children: _rows(40)),
              const TabBarInsetSliver(),
            ],
          ),
        ),
      );
      expect(await _overlapAtEnd(tester), lessThanOrEqualTo(0));
    });

    testWidgets('the page really runs behind the bar', (tester) async {
      await _pumpInShell(tester, Scaffold(body: ListView(children: _rows(40))));
      final body = tester.getBottomLeft(find.byType(ListView)).dy;
      expect(body, 640, reason: 'the page is as tall as the screen');
      expect(_barTop(tester), lessThan(body));
    });

    for (final entry in <String, Widget>{
      'Me': const MeScreen(),
      'About': const AboutScreen(),
      'Accreditation': const AccreditationScreen(),
      'Contact': const ContactScreen(),
    }.entries) {
      testWidgets('${entry.key} screen', (tester) async {
        await _pumpInShell(tester, entry.value);
        expect(await _overlapAtEnd(tester), lessThanOrEqualTo(0));
      });
    }
  });

  testWidgets('the bar is the same size and place on a short page', (
    tester,
  ) async {
    await _pumpInShell(tester, Scaffold(body: ListView(children: _rows(60))));
    final long = tester.getRect(find.byType(GlassBottomNavBar));

    await _pumpInShell(tester, const Scaffold(body: Text('short')));
    final short = tester.getRect(find.byType(GlassBottomNavBar));

    expect(short, long);
  });

  group('the blur', () {
    Future<void> pumpBar(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: GlassBottomNavBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                GlassNavDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                GlassNavDestination(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: 'Me',
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filters = find.descendant(
      of: find.byType(GlassBottomNavBar),
      matching: find.byType(BackdropFilter),
    );

    testWidgets('is one backdrop filter, clipped to the capsule', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(filters, findsOneWidget);
      expect(
        find.ancestor(of: filters, matching: find.byType(ClipRRect)),
        findsWidgets,
      );
    });

    testWidgets('gives way to a solid bar under high contrast', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpBar(tester);
      expect(filters, findsNothing);
    });

    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    test('labels keep 4.5:1 over the lightest and the darkest content', () {
      const white = Color(0xFFFFFFFF);
      const black = Color(0xFF000000);
      // Blur and saturation leave white, black and greys as they are, so the
      // capsule's lowest tint over each is the worst case.
      for (final tint in [
        GlassBottomNavBar.surfaceTopOpacity,
        GlassBottomNavBar.surfaceBottomOpacity,
        GlassBottomNavBar.solidSurfaceOpacity,
      ]) {
        for (final behind in [white, black]) {
          final pane = Color.alphaBlend(white.withValues(alpha: tint), behind);
          expect(
            contrast(GlassBottomNavBar.unselectedInk, pane),
            greaterThanOrEqualTo(4.5),
            reason: 'tint $tint over $behind',
          );
        }
      }
    });
  });

  group('a page\'s own floating button and sheets', () {
    Widget fabPage({required bool lifted}) {
      const fab = FloatingActionButton(
        key: Key('fab'),
        onPressed: null,
        child: Icon(Icons.add),
      );
      return Scaffold(
        body: const SizedBox.expand(),
        floatingActionButton: lifted ? const TabBarFabLift(child: fab) : fab,
      );
    }

    testWidgets('without the lift the button sits under the bar', (
      tester,
    ) async {
      await _pumpInShell(tester, fabPage(lifted: false));
      final fab = tester.getRect(find.byKey(const Key('fab')));
      final bar = tester.getRect(find.byType(GlassBottomNavBar));
      expect(fab.overlaps(bar), isTrue);
    });

    testWidgets('TabBarFabLift puts the button above the bar', (tester) async {
      await _pumpInShell(tester, fabPage(lifted: true));
      final fab = tester.getRect(find.byKey(const Key('fab')));
      final bar = tester.getRect(find.byType(GlassBottomNavBar));
      expect(fab.overlaps(bar), isFalse);
      expect(fab.bottom, lessThanOrEqualTo(bar.top));
      expect(find.byKey(const Key('fab')).hitTestable(), findsOneWidget);
    });

    testWidgets('the syllabus Add Item sheet shows its validation message', (
      tester,
    ) async {
      await _pumpInShell(
        tester,
        const SyllabusAdminScreen(),
        // Tall, so the whole sheet fits on screen.
        height: 1800,
        overrides: [
          syllabusLevelsProvider.overrideWith(
            (ref) async => [
              const ClassLevel(id: 1, code: 'L1', name: 'Level 1'),
            ],
          ),
          syllabusItemsProvider.overrideWith((ref) async => {}),
        ],
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Add Item'));
      await tester.pump(const Duration(seconds: 1));
      // Press Save directly: the sheet's own scrolling is not under test.
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Add Item'),
          )
          .onPressed!();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Subject name is required').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('the translated guide web view ends above the bar', (
      tester,
    ) async {
      await _pumpInShell(
        tester,
        GuideTranslateScreen(
          guideUrl: Uri.parse('https://account.example/guide.php'),
          englishHtml: '<p>x</p>',
          launch: (_) async => true,
          webViewBuilder: (url, handlers) =>
              const SizedBox.expand(key: Key('web')),
        ),
      );
      final web = tester.getRect(find.byKey(const Key('web')));
      expect(web.bottom, lessThanOrEqualTo(_barTop(tester)));
    });
  });
}
