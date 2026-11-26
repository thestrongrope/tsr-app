import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz_admin.dart';
import '../repositories/quiz_admin_repository.dart';

/// The repository, as a provider so a test can stand in for the network.
final quizAdminRepositoryProvider = Provider<QuizAdminRepository>(
  (ref) => QuizAdminRepository(),
);

/// The quiz as the server holds it now. Invalidate it after every action.
final quizAdminStateProvider = FutureProvider.autoDispose<QuizAdminState>(
  (ref) => ref.watch(quizAdminRepositoryProvider).getState(),
  retry: (retryCount, error) => null,
);
