import 'dart:async';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/core/version/version_provider.dart';
import 'package:the_strong_rope/features/admin/models/guide_authoring.dart';
import 'package:the_strong_rope/features/admin/providers/guides_provider.dart';
import 'package:the_strong_rope/features/admin/repositories/guides_repository.dart';
import 'package:the_strong_rope/features/admin/screens/guide_editor_screen.dart';
import 'package:the_strong_rope/main.dart' show buildAppShell;

class _FakeGuides extends GuidesRepository {
  @override
  Future<List<GuideLevel>> getLevels() async => const [
    GuideLevel(id: 3, name: 'Miqdad'),
  ];

  @override
  Future<EditableGuide> getGuide(int levelId) async => const EditableGuide(
    guide: '<h1>Miqdad</h1><p>Hello</p>',
    levelName: 'Miqdad',
  );
}

class _Online extends OfflineNotifier {
  @override
  bool build() => false;
}

void main() {
  // The guide editor's own test supplies the Quill delegates itself, which
  // hid #774. This one builds the shell the app really ships (#784).
  testWidgets('the guide editor opens inside the app\'s real root widget', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const GuideEditorScreen(levelId: 3),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guidesRepositoryProvider.overrideWithValue(_FakeGuides()),
          isOfflineProvider.overrideWith(_Online.new),
          versionCheckProvider.overrideWith(
            (_) => Completer<VersionCheck>().future,
          ),
        ],
        child: buildAppShell(router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(QuillEditor), findsOneWidget);
  });
}
