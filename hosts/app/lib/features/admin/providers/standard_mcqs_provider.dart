import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/standard_mcqs.dart';
import '../repositories/standard_mcqs_repository.dart';

/// The repository, as a provider so a test can stand in for the network.
final standardMcqsRepositoryProvider = Provider<StandardMcqsRepository>(
  (ref) => StandardMcqsRepository(),
);

/// The languages and levels the update offers.
final standardMcqSourcesProvider =
    FutureProvider.autoDispose<StandardMcqSources>(
      (ref) => ref.watch(standardMcqsRepositoryProvider).getSources(),
      retry: (retryCount, error) => null,
    );
