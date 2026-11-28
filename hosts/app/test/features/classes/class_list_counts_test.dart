import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/providers.dart';
import 'package:the_strong_rope/features/classes/screens/class_dashboard_screen.dart';

import '../../support/content_width.dart';

class _FakeClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FakeClassesNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

ClassModel _class(
  int id,
  String code, {
  required int level,
  required String levelName,
  String role = 'managing',
  String? city,
  String? country,
  List<String> tags = const [],
  int? students,
}) => ClassModel(
  id: id,
  code: code,
  name: 'Name $code',
  level: level,
  levelName: levelName,
  gender: 1,
  status: 'A',
  role: role,
  city: city,
  country: country,
  tags: tags,
  studentCount: students,
);

/// The class list's search over city, country and tags (#690), the student
/// count on a managed class and the per-level totals above Managing.
void main() {
  final managed = [
    _class(
      1,
      'MUM1',
      level: 3,
      levelName: 'MIQDAD',
      city: 'Mumbai',
      country: 'India',
      tags: ['Mumbra'],
      students: 12,
    ),
    _class(
      2,
      'MUM2',
      level: 3,
      levelName: 'MIQDAD',
      city: 'Mumbai',
      country: 'India',
      students: 8,
    ),
    _class(
      3,
      'DXB1',
      level: 4,
      levelName: 'AMMAR',
      city: 'Dubai',
      country: 'UAE',
      tags: ['Online'],
      students: 1,
    ),
  ];

  Future<void> pump(WidgetTester tester, List<ClassModel> classes) async {
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

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  for (final size in [tabletLandscape, tabletPortrait]) {
    testWidgets('on a $size tablet the list is capped and centred', (
      tester,
    ) async {
      await pump(tester, managed);
      setWindow(tester, size);
      await tester.pumpAndSettle();

      expectContentCapped(tester);
    });
  }

  testWidgets('a managed class shows its students and tags; totals per level', (
    tester,
  ) async {
    await pump(tester, managed);

    expect(find.text('12 students'), findsOneWidget);
    expect(find.text('1 student'), findsOneWidget);
    expect(find.text('Mumbra'), findsOneWidget);
    expect(find.text('MIQDAD: 2 classes, 20 students'), findsOneWidget);
    expect(find.text('AMMAR: 1 class, 1 student'), findsOneWidget);
  });

  testWidgets('search matches city, country and tags, any case', (
    tester,
  ) async {
    await pump(tester, managed);

    await search(tester, 'MUMBAI');
    expect(find.text('MUM1'), findsOneWidget);
    expect(find.text('MUM2'), findsOneWidget);
    expect(find.text('DXB1'), findsNothing);

    await search(tester, 'uae');
    expect(find.text('DXB1'), findsOneWidget);
    expect(find.text('MUM1'), findsNothing);

    await search(tester, 'mumbra');
    expect(find.text('MUM1'), findsOneWidget);
    expect(find.text('MUM2'), findsNothing);
  });

  testWidgets('totals are recounted from the classes that match', (
    tester,
  ) async {
    await pump(tester, managed);

    await search(tester, 'mumbra');
    expect(find.text('MIQDAD: 1 class, 12 students'), findsOneWidget);
    expect(find.text('AMMAR: 1 class, 1 student'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('MIQDAD: 2 classes, 20 students'), findsOneWidget);
    expect(find.text('AMMAR: 1 class, 1 student'), findsOneWidget);
  });

  testWidgets('no match says so and shows no totals', (tester) async {
    await pump(tester, managed);

    await search(tester, 'zzzz');
    expect(find.text('No classes match your search'), findsOneWidget);
    expect(find.textContaining('classes,'), findsNothing);
    expect(find.textContaining('class,'), findsNothing);
  });

  testWidgets('without a managed class there are no counts or totals', (
    tester,
  ) async {
    await pump(tester, [
      _class(9, 'STU1', level: 3, levelName: 'MIQDAD', role: 'attending'),
    ]);

    expect(find.text('Managing'), findsNothing);
    expect(find.textContaining('student'), findsNothing);
    expect(find.textContaining('class,'), findsNothing);
  });
}
