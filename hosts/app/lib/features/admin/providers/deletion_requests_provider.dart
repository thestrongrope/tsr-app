import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deletion_requests.dart';
import '../repositories/deletion_requests_repository.dart';

/// The repository, as a provider so a test can stand in for the network.
final deletionRequestsRepositoryProvider = Provider<DeletionRequestsRepository>(
  (ref) => DeletionRequestsRepository(),
);

/// The queue for one status, or all of it when the status is null.
final deletionQueueProvider = FutureProvider.autoDispose
    .family<DeletionQueue, String?>(
      (ref, status) => ref
          .watch(deletionRequestsRepositoryProvider)
          .getQueue(status: status),
      retry: (retryCount, error) => null,
    );
