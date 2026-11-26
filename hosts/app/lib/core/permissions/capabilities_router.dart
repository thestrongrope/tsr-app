import '../../features/classes/models/class_model.dart';
import '../providers/permissions_provider.dart';
import 'capabilities.dart';

/// What the router asks, so a guard and the screen it protects answer from the
/// same facts.
extension CapabilitiesRouter on Capabilities {
  /// May the member open the Manage hub? The same fact as the Manage tab.
  bool get allowsAdminHub => showManageTab;

  /// May the member open a screen that needs [permission] on class [classId]?
  ///
  /// The class's gender comes from the loaded class list [classes]. While the
  /// list is not loaded (null) the gender is unknown, so the guard accepts the
  /// permission held for either gender instead of refusing a gender admin for
  /// a list that has not arrived. Once the list is loaded, a class missing from
  /// it has no gender and only the scopes that go by class id can match.
  bool allowsClassAction(
    PermissionsState permissions,
    String permission, {
    required int classId,
    required List<ClassModel>? classes,
  }) {
    bool can(int? gender) =>
        permissions.can(permission, classId: classId, classGender: gender);
    if (classes == null) return can(1) || can(2);
    for (final cls in classes) {
      if (cls.id == classId) return can(cls.gender);
    }
    return can(null);
  }
}
