import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/guide_authoring.dart';
import '../repositories/guides_repository.dart';

final guidesRepositoryProvider = Provider<GuidesRepository>((ref) {
  return GuidesRepository();
});

// A failed load shows at once with a Retry button, not after silent retries.

final guideLevelsProvider = FutureProvider.autoDispose<List<GuideLevel>>(
  (ref) => ref.watch(guidesRepositoryProvider).getLevels(),
  retry: (_, _) => null,
);

/// A level's guide as the editor opens it. Not kept once the screen closes, so
/// each visit starts from what the server has.
final guideForEditProvider = FutureProvider.autoDispose
    .family<EditableGuide, int>(
      (ref, levelId) => ref.watch(guidesRepositoryProvider).getGuide(levelId),
      retry: (_, _) => null,
    );
