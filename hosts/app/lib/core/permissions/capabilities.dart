import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/classes/models/class_model.dart';
import '../../features/classes/providers/classes_provider.dart';
import '../models/permissions_payload.dart';
import '../providers/permissions_provider.dart';

/// What the member's screens may show, decided in one place from the two
/// answers the app holds: what the server said they may do, and the classes
/// they were loaded with. The two can arrive at different times, so a tab
/// shows when either source says it should.
class Capabilities {
  const Capabilities({
    required this.showClassesTab,
    required this.showManageTab,
    this.payload,
    this.classes,
  });

  /// Nothing is shown until the server has answered.
  const Capabilities.none()
    : showClassesTab = false,
      showManageTab = false,
      payload = null,
      classes = null;

  /// The Classes tab: the server's `navigation.classes`, or the member already
  /// has a class in the loaded list.
  final bool showClassesTab;

  /// The Manage tab: the server's `navigation.manage`.
  final bool showManageTab;

  /// The two answers the flags above were decided from, for the
  /// `capabilities_*` extensions that decide the rest of a screen from the same
  /// pair. Null until the server has answered, and `classes` null until the
  /// list has loaded. Screens ask those extensions, not these fields.
  final PermissionsPayload? payload;
  final List<ClassModel>? classes;

  /// May the member do [permission], optionally on one class? Nothing is
  /// granted until the server has answered. Feature extensions name the
  /// questions the screens ask; screens do not call this directly.
  bool can(String permission, {int? classId, int? classGender}) =>
      payload?.can(permission, classId: classId, classGender: classGender) ??
      false;

  /// The gender a gender admin manages, else null.
  int? get genderScope => payload?.scopes.gender;

  /// See [PermissionsPayload.remindsConduction].
  bool remindsConduction({required int classId}) =>
      payload?.remindsConduction(classId: classId) ?? false;

  factory Capabilities.of({
    required PermissionsPayload? payload,
    required List<ClassModel>? classes,
  }) {
    if (payload == null) return const Capabilities.none();
    return Capabilities(
      showClassesTab: payload.showsClassesTab || (classes?.isNotEmpty ?? false),
      showManageTab: payload.showsManageTab,
      payload: payload,
      classes: classes,
    );
  }
}

final capabilitiesProvider = Provider<Capabilities>((ref) {
  final payload = ref.watch(permissionsProvider.select((s) => s.payload));
  final classes = ref.watch(classesProvider.select((s) => s.classes));
  return Capabilities.of(payload: payload, classes: classes);
});
