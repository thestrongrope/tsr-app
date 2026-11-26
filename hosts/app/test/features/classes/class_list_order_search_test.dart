import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/class_dashboard_screen.dart';

class _FakeClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FakeClassesNotifier(super.state);

  /// The screen asks to load classes on open; the state is already set.
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

ClassModel _class(
  int id,
  String code,
  String name, {
  String? role,
  String? teacher,
}) => ClassModel(
  id: id,
  code: code,
  name: name,
  level: 3,
  levelName: 'MIQDAD',
  gender: 1,
  status: 'A',
  teacherName: teacher,
  role: role,
);

/// The class list: its order, and finding a class by typing (a super admin
/// manages hundreds).
void main() {
  final classes = [
    _class(1, 'MGR1', 'Managed Alpha', role: 'managing', teacher: 'Zaid'),
    _class(2, 'TCH1', 'Taught Bravo', role: 'conducting', teacher: 'Me'),
    _class(3, 'STU1', 'Studied Charlie', role: 'attending', teacher: 'Hamza'),
    _class(4, 'STU2', 'Studied Delta', role: 'attending', teacher: 'Ammar'),
  ];

  Future<void> pump(WidgetTester tester) async {
    // The list is lazy, so a tall screen builds every row for the finders.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classesProvider.overrideWith(
            (ref) => _FakeClassesNotifier(ClassesState(classes: classes)),
          ),
        ],
        child: const MaterialApp(home: ClassDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  testWidgets('Attending comes first, then Conducting, then Managing', (
    tester,
  ) async {
    await pump(tester);

    expect(top(tester, 'Attending'), lessThan(top(tester, 'Conducting')));
    expect(top(tester, 'Conducting'), lessThan(top(tester, 'Managing')));
  });

  testWidgets('typing narrows the list by code, name, teacher or level', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('MGR1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'studied');
    await tester.pumpAndSettle();
    expect(find.text('STU1'), findsOneWidget);
    expect(find.text('STU2'), findsOneWidget);
    expect(find.text('MGR1'), findsNothing);
    expect(find.text('Managing'), findsNothing, reason: 'empty groups go');

    await tester.enterText(find.byType(TextField), 'ZAID');
    await tester.pumpAndSettle();
    expect(find.text('MGR1'), findsOneWidget, reason: 'teacher, any case');
    expect(find.text('STU1'), findsNothing);

    await tester.enterText(find.byType(TextField), 'stu2');
    await tester.pumpAndSettle();
    expect(find.text('STU2'), findsOneWidget, reason: 'by code');
    expect(find.text('STU1'), findsNothing);
  });

  testWidgets('no match says so, and clearing brings every class back', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No classes match your search'), findsOneWidget);
    expect(find.text('Attending'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No classes match your search'), findsNothing);
    expect(find.text('Attending'), findsOneWidget);
    expect(find.text('Conducting'), findsOneWidget);
    expect(find.text('Managing'), findsOneWidget);
  });
}
