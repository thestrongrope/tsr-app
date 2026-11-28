import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/search/models/search_result.dart';
import 'package:the_strong_rope/features/search/providers/search_provider.dart';

// A video or publication result opens outside the app (#666); when the phone
// cannot open it, say so instead of doing nothing.

const _video = SearchResult(
  kind: SearchKind.video,
  id: 1,
  title: 'A talk',
  subtitle: '',
  target: 'https://example.invalid/talk',
);

Future<void> _tap(
  WidgetTester tester,
  Future<bool> Function(Uri) launcher,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [externalLauncherProvider.overrideWithValue(launcher)],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => ref.read(searchOpenProvider)(context, _video),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a link that opens says nothing', (tester) async {
    Uri? opened;
    await _tap(tester, (uri) async {
      opened = uri;
      return true;
    });

    expect(opened, Uri.parse('https://example.invalid/talk'));
    expect(find.text('Could not open that link'), findsNothing);
  });

  testWidgets('a link the phone refuses is reported', (tester) async {
    await _tap(tester, (_) async => false);

    expect(find.text('Could not open that link'), findsOneWidget);
  });

  testWidgets('a platform error is reported too', (tester) async {
    await _tap(tester, (_) async => throw PlatformException(code: 'x'));

    expect(find.text('Could not open that link'), findsOneWidget);
  });
}
