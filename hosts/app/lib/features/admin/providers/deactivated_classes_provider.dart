import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deactivated_classes.dart';
import '../repositories/deactivated_classes_repository.dart';

/// The deactivated classes and the activity log.
final deactivatedClassesProvider =
    FutureProvider.autoDispose<DeactivatedClasses>(
      (ref) => DeactivatedClassesRepository().getDeactivatedClasses(),
      retry: (retryCount, error) => null,
    );

/// The active classes to choose from; loaded when the picker opens.
final deactivationCandidatesProvider =
    FutureProvider.autoDispose<List<DeactivationCandidate>>(
      (ref) => DeactivatedClassesRepository().getCandidates(),
      retry: (retryCount, error) => null,
    );

/// Retires a class: (class id, type, effective date, reason).
typedef DeactivateClass =
    Future<void> Function({
      required int classId,
      required String type,
      required String effectiveDate,
      required String reason,
    });

final deactivateClassProvider = Provider<DeactivateClass>(
  (ref) =>
      ({
        required int classId,
        required String type,
        required String effectiveDate,
        required String reason,
      }) => DeactivatedClassesRepository().deactivateClass(
        classId: classId,
        type: type,
        effectiveDate: effectiveDate,
        reason: reason,
      ),
);
