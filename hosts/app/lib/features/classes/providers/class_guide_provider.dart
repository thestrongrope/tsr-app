import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/class_guide.dart';
import '../repositories/class_guide_repository.dart';

final classGuideRepositoryProvider = Provider<ClassGuideRepository>((ref) {
  return ClassGuideRepository();
});

/// The guide for one class's level. Not kept once the screen closes, so each
/// visit shows the web's current text.
final classGuideProvider = FutureProvider.autoDispose.family<ClassGuide, int>(
  (ref, classId) {
    return ref.watch(classGuideRepositoryProvider).getGuide(classId);
  },
  // A failed load shows at once with a Retry button, not after silent retries.
  retry: (_, _) => null,
);

/// The guide a guide link names, by slug (#1138). Same rules as above.
final guideBySlugProvider = FutureProvider.autoDispose
    .family<ClassGuide, String>((ref, slug) {
      return ref.watch(classGuideRepositoryProvider).getGuideBySlug(slug);
    }, retry: (_, _) => null);

/// The guides that can be opened, listed when a link names none that exists.
final readableGuidesProvider = FutureProvider.autoDispose<List<GuideSummary>>((
  ref,
) {
  return ref.watch(classGuideRepositoryProvider).getGuides();
}, retry: (_, _) => null);
