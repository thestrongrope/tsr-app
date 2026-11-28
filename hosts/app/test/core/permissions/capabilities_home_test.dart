import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/permissions/capabilities.dart';
import 'package:the_strong_rope/core/permissions/capabilities_home.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:the_strong_rope/features/home/presentation/widgets/my_classes_widget.dart';

ClassModel _class(int id, {String? role}) => ClassModel(
  id: id,
  code: 'C$id',
  name: 'Class $id',
  level: 1,
  gender: 1,
  status: 'active',
  role: role,
);

PermissionsPayload _payload({
  List<String> permissions = const [],
  PermissionScopes scopes = const PermissionScopes(),
  bool? navigationClasses,
}) => PermissionsPayload(
  version: 5,
  permissions: permissions,
  scopes: scopes,
  issuedAt: '',
  revision: '0123456789abcdef',
  navigation: navigationClasses == null
      ? null
      : PermissionsNavigation(classes: navigationClasses, manage: false),
);

Capabilities _caps(PermissionsPayload? payload, List<ClassModel>? classes) =>
    Capabilities.of(payload: payload, classes: classes);

void main() {
  group('My Classes section: one rule over the list and the payload', () {
    final enrolled = _payload(scopes: const PermissionScopes(enrolled: [1]));
    final notEnrolled = _payload();

    test('a loaded class shows it, whatever the payload says', () {
      final caps = _caps(notEnrolled, [_class(1)]);
      expect(caps.showMyClasses(classesLoading: false), isTrue);
      expect(caps.showMyClasses(classesLoading: true), isTrue);
    });

    test('enrolled with an empty list settled shows the empty card', () {
      final caps = _caps(enrolled, const []);
      expect(caps.showMyClasses(classesLoading: false), isTrue);
    });

    test('enrolled while the list loads shows nothing yet', () {
      final caps = _caps(enrolled, const []);
      expect(caps.showMyClasses(classesLoading: true), isFalse);
    });

    test('not enrolled with an empty list shows nothing', () {
      final caps = _caps(notEnrolled, const []);
      expect(caps.showMyClasses(classesLoading: false), isFalse);
    });

    test('nothing shows before the server has answered', () {
      final caps = _caps(null, [_class(1)]);
      expect(caps.showMyClasses(classesLoading: false), isFalse);
    });
  });

  group('teaching shortcuts: conducting in the list AND allowed', () {
    const permission = 'sessions:create';

    test('conducting a class the grant covers is offered', () {
      final caps = _caps(
        _payload(
          permissions: const ['sessions:create:taught'],
          scopes: const PermissionScopes(taught: [1]),
        ),
        [_class(1, role: 'conducting')],
      );
      expect(caps.teachingClasses(permission).map((c) => c.id), [1]);
    });

    test('the list says conducting but the payload has no grant', () {
      final caps = _caps(_payload(), [_class(1, role: 'conducting')]);
      expect(caps.teachingClasses(permission), isEmpty);
    });

    test('the grant covers the class but the list says attending', () {
      final caps = _caps(
        _payload(
          permissions: const ['sessions:create:taught'],
          scopes: const PermissionScopes(taught: [1]),
        ),
        [_class(1, role: 'attending')],
      );
      expect(caps.teachingClasses(permission), isEmpty);
    });

    test('only the class both sources agree on is offered', () {
      final caps = _caps(
        _payload(
          permissions: const ['sessions:create:taught'],
          scopes: const PermissionScopes(taught: [2]),
        ),
        [_class(1, role: 'conducting'), _class(2, role: 'conducting')],
      );
      expect(caps.teachingClasses(permission).map((c) => c.id), [2]);
    });

    test('no payload, no shortcut', () {
      final caps = _caps(null, [_class(1, role: 'conducting')]);
      expect(caps.teachingClasses(permission), isEmpty);
    });
  });

  group('remembered class visits', () {
    final payload = _payload(
      permissions: const ['sessions:create:taught'],
      scopes: const PermissionScopes(taught: [1]),
    );

    test('a class missing from the list is dropped', () {
      expect(_caps(payload, [_class(2)]).classForJumpBack(1), isNull);
    });

    test('a class in the list without the permission is dropped', () {
      final caps = _caps(payload, [_class(1), _class(2)]);
      expect(caps.classForJumpBack(1, permission: 'sessions:create'), isNotNull);
      expect(caps.classForJumpBack(2, permission: 'sessions:create'), isNull);
      expect(caps.classForJumpBack(2), isNotNull);
    });
  });

  group('Classes links on Home follow the Classes tab', () {
    for (final (payload, classes, shown) in [
      (_payload(navigationClasses: true), const <ClassModel>[], true),
      (_payload(navigationClasses: false), const <ClassModel>[], false),
      (_payload(navigationClasses: false), [_class(1)], true),
    ]) {
      test('navigation ${payload.navigation?.classes}, '
          '${classes.length} classes -> $shown', () {
        final caps = _caps(payload, classes);
        expect(caps.showClassesLinks, shown);
        expect(caps.showClassesLinks, caps.showClassesTab);
      });
    }
  });

  group('MyClassesWidget links', () {
    Future<void> pump(
      WidgetTester tester,
      PermissionsPayload? payload,
      List<ClassModel> classes,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            permissionsProvider.overrideWith((ref) => _Permissions(payload)),
            classesProvider.overrideWith((ref) => _Classes(classes)),
          ],
          child: const MaterialApp(home: Scaffold(body: MyClassesWidget())),
        ),
      );
      await tester.pump();
    }

    testWidgets('the empty card links only when the Classes tab exists', (
      tester,
    ) async {
      await pump(tester, _payload(navigationClasses: true), const []);
      expect(find.text('See classes'), findsOneWidget);

      await pump(tester, _payload(navigationClasses: false), const []);
      expect(find.text('See classes'), findsNothing);
    });

    testWidgets('View all follows the same rule as See classes', (
      tester,
    ) async {
      final three = [_class(1), _class(2), _class(3)];
      await pump(tester, _payload(navigationClasses: true), three);
      expect(find.text('View all'), findsOneWidget);

      await pump(tester, null, three);
      expect(find.text('View all'), findsNothing);
    });
  });
}

class _Permissions extends PermissionsNotifier {
  _Permissions(PermissionsPayload? payload) {
    state = PermissionsState(payload: payload);
  }
}

class _Classes extends StateNotifier<ClassesState> implements ClassesNotifier {
  _Classes(List<ClassModel> classes) : super(ClassesState(classes: classes));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
