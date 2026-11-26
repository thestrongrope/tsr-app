import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/permissions/capabilities.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';

const _aClass = ClassModel(
  id: 1,
  code: 'C1',
  name: 'Alpha',
  level: 1,
  gender: 1,
  status: 'active',
);

PermissionsPayload _v5({required bool classes, required bool manage}) =>
    PermissionsPayload(
      version: 5,
      permissions: const [],
      issuedAt: '',
      revision: '0123456789abcdef',
      navigation: PermissionsNavigation(classes: classes, manage: manage),
    );

class _Permissions extends PermissionsNotifier {
  _Permissions(PermissionsPayload? payload) {
    state = PermissionsState(payload: payload);
  }
}

class _Classes extends StateNotifier<ClassesState> implements ClassesNotifier {
  _Classes(List<ClassModel>? classes) : super(ClassesState(classes: classes));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Classes tab: server navigation x loaded list', () {
    const table = [
      // navigation.classes, list, shown
      (true, <ClassModel>[], true),
      (true, [_aClass], true),
      (true, null, true),
      (false, [_aClass], true),
      (false, <ClassModel>[], false),
      (false, null, false),
    ];
    for (final (navigation, list, shown) in table) {
      test('navigation $navigation, list '
          '${list == null ? 'not loaded' : list.length} -> $shown', () {
        final capabilities = Capabilities.of(
          payload: _v5(classes: navigation, manage: false),
          classes: list,
        );
        expect(capabilities.showClassesTab, shown);
      });
    }

    test('a v4 copy with a class in scope shows it before the list loads', () {
      final capabilities = Capabilities.of(
        payload: const PermissionsPayload(
          version: 4,
          permissions: ['classes:read:enrolled'],
          scopes: PermissionScopes(enrolled: [412]),
          issuedAt: '',
        ),
        classes: null,
      );
      expect(capabilities.showClassesTab, isTrue);
    });
  });

  group('Manage tab', () {
    test('follows navigation.manage, whatever the class list holds', () {
      expect(
        Capabilities.of(
          payload: _v5(classes: false, manage: true),
          classes: const [_aClass],
        ).showManageTab,
        isTrue,
      );
      expect(
        Capabilities.of(
          payload: _v5(classes: true, manage: false),
          classes: const [_aClass],
        ).showManageTab,
        isFalse,
      );
    });

    test('a v4 copy computes it from its permissions', () {
      final capabilities = Capabilities.of(
        payload: const PermissionsPayload(
          version: 4,
          permissions: ['reports:read:gender'],
          issuedAt: '',
        ),
        classes: null,
      );
      expect(capabilities.showManageTab, isTrue);
    });
  });

  test('the provider combines the permissions and the class list', () async {
    final container = ProviderContainer(
      overrides: [
        permissionsProvider.overrideWith(
          (ref) => _Permissions(_v5(classes: false, manage: true)),
        ),
        classesProvider.overrideWith((ref) => _Classes(const [_aClass])),
      ],
    );
    addTearDown(container.dispose);

    final capabilities = container.read(capabilitiesProvider);

    expect(capabilities.showClassesTab, isTrue);
    expect(capabilities.showManageTab, isTrue);
  });

  test('no answer from the server shows neither tab, even with classes', () {
    final capabilities = Capabilities.of(
      payload: null,
      classes: const [_aClass],
    );
    expect(capabilities.showClassesTab, isFalse);
    expect(capabilities.showManageTab, isFalse);
  });
}
