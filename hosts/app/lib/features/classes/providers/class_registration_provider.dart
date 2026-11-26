import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_registration.dart';
import '../repositories/class_registration_repository.dart';

// ============ Repository Provider ============

final classRegistrationRepositoryProvider =
    Provider<ClassRegistrationRepository>((ref) {
      return ClassRegistrationRepository();
    });

// ============ Form Data Provider ============

/// Loads the user's existing registration + form options (auto-dispose).
final classRegistrationFormProvider =
    FutureProvider.autoDispose<ClassRegistrationFormData>((ref) {
      final repo = ref.watch(classRegistrationRepositoryProvider);
      return repo.getFormData();
    }, retry: (_, _) => null);
