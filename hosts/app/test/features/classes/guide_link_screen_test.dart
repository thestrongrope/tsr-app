import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/constants/app_constants.dart';
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/router/route_config.dart';
import 'package:the_strong_rope/features/classes/models/class_guide.dart';
import 'package:the_strong_rope/features/classes/providers/class_guide_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_guide_repository.dart';
import 'package:the_strong_rope/features/classes/screens/guide_link_screen.dart';

const _guide = ClassGuide(
  guide: '<h1>Miqdad</h1><p>Read the syllabus first.</p>',
  shareUrl: 'https://account.example/guide.php?guide=miqdad',
  levelName: 'MIQDAD',
);

class _FakeRepository extends ClassGuideRepository {
  /// What each call to getGuideBySlug does: return a guide or throw.
  Object guide = _guide;
  int guideCalls = 0;
  int listCalls = 0;
  final List<GuideSummary> guides = const [
    GuideSummary(slug: 'abuzar', name: 'Abuzar'),
    GuideSummary(slug: 'miqdad', name: 'Miqdad'),
  ];
  Object? firstError;

  @override
  Future<ClassGuide> getGuideBySlug(String slug) async {
    guideCalls++;
    final error = firstError;
    if (error != null && guideCalls == 1) throw error;
    final next = guide;
    if (next is Exception) throw next;
    return next as ClassGuide;
  }

  @override
  Future<List<GuideSummary>> getGuides() async {
    listCalls++;
    return guides;
  }
}

/// A guide link opens that level's guide in the app (#1138): the guide shows,
/// an unknown guide says so and lists the guides, an offline device can try
/// again, and someone who is not a student or teacher sees none of it.
void main() {
  late _FakeRepository repo;

  Future<void> pumpLink(WidgetTester tester, String location) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: AppRoutes.guideLink,
          builder: (_, state) => GuideLinkScreen(
            slug: state.uri.queryParameters['guide'],
            launch: (_) async => true,
            share: (_) async {},
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [classGuideRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => repo = _FakeRepository());

  testWidgets('shows the guide the link names', (tester) async {
    await pumpLink(tester, '/guide.php?guide=miqdad');

    expect(
      find.textContaining('Read the syllabus', findRichText: true),
      findsOneWidget,
    );
    expect(repo.listCalls, 0);
  });

  testWidgets('a guide that does not exist is said so, with the list', (
    tester,
  ) async {
    repo.guide = ApiException('Guide not found', 404);
    await pumpLink(tester, '/guide.php?guide=nobody');

    expect(find.textContaining('does not exist'), findsOneWidget);
    expect(find.text('Abuzar'), findsOneWidget);
    expect(find.text('Miqdad'), findsOneWidget);
  });

  testWidgets('a link naming no guide is treated as an unknown guide', (
    tester,
  ) async {
    await pumpLink(tester, '/guide.php');

    expect(find.textContaining('does not exist'), findsOneWidget);
    expect(find.text('Miqdad'), findsOneWidget);
    expect(repo.guideCalls, 0);
  });

  testWidgets('choosing a guide from the list opens it', (tester) async {
    repo.guide = ApiException('Guide not found', 404);
    await pumpLink(tester, '/guide.php?guide=nobody');
    repo.guide = _guide;

    await tester.tap(find.text('Miqdad'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Read the syllabus', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('offline: says so and Retry loads the guide', (tester) async {
    repo.firstError = ApiException('offline', 0);
    await pumpLink(tester, '/guide.php?guide=miqdad');

    expect(find.text(AppConstants.networkErrorMessage), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Read the syllabus', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('someone who is not a student or teacher sees none of it', (
    tester,
  ) async {
    repo.guide = ApiException('Guides are for students and teachers', 403);
    await pumpLink(tester, '/guide.php?guide=miqdad');

    expect(find.text('Guides are for students and teachers.'), findsOneWidget);
    expect(
      find.textContaining('Read the syllabus', findRichText: true),
      findsNothing,
    );
    expect(repo.listCalls, 0);
  });
}
