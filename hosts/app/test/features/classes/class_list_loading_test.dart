import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/widgets/widgets.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/class_dashboard_screen.dart';

class _FakeClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FakeClassesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  testWidgets('the classes list shows a skeleton while loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classesProvider.overrideWith(
            (ref) => _FakeClassesNotifier(const ClassesState(isLoading: true)),
          ),
        ],
        child: const MaterialApp(home: ClassDashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
