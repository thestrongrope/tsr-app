import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart' show StateNotifier;
import 'package:the_strong_rope/core/network/api_client.dart';
import 'package:the_strong_rope/core/widgets/app_surface_card.dart';
import 'package:the_strong_rope/core/widgets/skeleton_box.dart';
import 'package:the_strong_rope/features/classes/models/class_manage.dart';
import 'package:the_strong_rope/features/classes/providers/class_manage_provider.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_manage_repository.dart';
import 'package:the_strong_rope/features/classes/screens/class_manage_screen.dart';

Map<String, dynamic> _payload() => {
  'class': {
    'id': 27,
    'code': 'AY-7',
    'name': 'Sulsi',
    'levelId': 4,
    'levelName': 'AMMAR',
    'gender': 1,
    'genderName': 'Male',
    'languageId': 1,
    'format': 'Offline',
    'city': 'New Delhi',
    'country': 'India',
    'teacher': 12757,
    'teacherName': 'A Teacher',
  },
  'tags': <dynamic>[],
  'schedules': [
    {
      'id': 387,
      'day': 6,
      'hour': 19,
      'minute': 0,
      'timezone': 'Asia/Kolkata',
      'topics': <dynamic>[],
    },
  ],
  'lookups': {
    'languages': [
      {'id': 1, 'name': 'English'},
    ],
    'tags': <dynamic>[],
    'topics': <dynamic>[],
    'timezones': [
      {'timezone': 'Asia/Kolkata', 'label': '(UTC+05:30) Kolkata'},
    ],
  },
  'can': {
    'update': true,
    'enrol': true,
    'setClassAdmin': false,
    'transfer': false,
  },
  'students': <dynamic>[],
  'removedStudents': <dynamic>[],
  'mcqStudents': <dynamic>[],
};

class _ManageRepository extends ClassManageRepository {
  _ManageRepository({this.load, this.failSave = false});

  final Future<ClassManagePayload> Function()? load;
  bool failSave;
  int loads = 0;
  int saves = 0;

  @override
  Future<ClassManagePayload> getManage(int classId) {
    loads++;
    return load?.call() ??
        Future.value(ClassManagePayload.fromJson(_payload()));
  }

  @override
  Future<ClassManagePayload> save(int classId, ClassDraft draft) async {
    saves++;
    if (failSave) throw const ApiException('Could not reach the server', 500);
    return ClassManagePayload.fromJson(_payload());
  }
}

class _FixedClassesNotifier extends StateNotifier<ClassesState>
    implements ClassesNotifier {
  _FixedClassesNotifier() : super(const ClassesState());

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(_ManageRepository repository, {int initialTab = 0}) {
  final List<Override> overrides = [
    classManageRepositoryProvider.overrideWithValue(repository),
    classesProvider.overrideWith((ref) => _FixedClassesNotifier()),
  ];
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: ClassManageScreen(classId: 27, initialTab: initialTab),
      ),
    ),
  );
}

void main() {
  testWidgets('shows a skeleton while the class loads', (tester) async {
    final pending = Completer<ClassManagePayload>();
    await tester.pumpWidget(
      _host(_ManageRepository(load: () => pending.future)),
    );
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failed load shows a message and Retry', (tester) async {
    final repository = _ManageRepository(
      load: () async =>
          throw const ApiException('Could not reach the server', 500),
    );
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('Something went wrong on our side'), findsOneWidget);
    expect(find.text('Could not reach the server'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.loads, 2);
  });

  testWidgets('details tab groups its fields on shared surface cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(_ManageRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(AppSurfaceCard), findsWidgets);
    expect(find.text('Class details'), findsOneWidget);
    expect(find.text('Teacher'), findsWidgets);
    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('schedule tab shows the slot on a shared surface card', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_ManageRepository(), initialTab: 1));
    await tester.pumpAndSettle();

    expect(find.byType(AppSurfaceCard), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);
    expect(find.text('Add a day'), findsOneWidget);
  });

  testWidgets('saving a change confirms it was saved', (tester) async {
    final repository = _ManageRepository();
    await tester.pumpWidget(_host(repository, initialTab: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository.saves, 1);
    expect(find.text('Class saved'), findsOneWidget);
  });

  testWidgets('a change that cannot be saved says so and keeps the edit', (
    tester,
  ) async {
    final repository = _ManageRepository(failSave: true);
    await tester.pumpWidget(_host(repository, initialTab: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Not saved'), findsOneWidget);
    expect(find.textContaining('Could not reach the server'), findsNothing);
    expect(find.textContaining('try again in a moment.'), findsOneWidget);
    expect(find.textContaining('Your changes are kept'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);
    expect(find.byType(AppSurfaceCard), findsNWidgets(2));
  });
}
