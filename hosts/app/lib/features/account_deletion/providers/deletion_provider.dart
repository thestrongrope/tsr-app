import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deletion_request.dart';
import '../repositories/deletion_repository.dart';

final deletionRepositoryProvider = Provider<DeletionRepository>(
  (ref) => DeletionRepository(),
);

/// The member's current deletion request, for the screens that show its detail.
///
/// The authoritative *status* lives on `AuthState`, because the router reads it;
/// this exists for the request date and grace period, which only the pending
/// screen needs.
final deletionRequestProvider = FutureProvider.autoDispose<DeletionRequest>(
  (ref) => ref.read(deletionRepositoryProvider).fetch(),
);
