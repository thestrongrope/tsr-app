import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/student_transfers.dart';
import '../repositories/student_transfers_repository.dart';

/// Every class, for both pickers.
final transferClassesProvider = FutureProvider.autoDispose<TransferClasses>(
  (ref) => StudentTransfersRepository().getClasses(),
  retry: (retryCount, error) => null,
);

/// Who can be moved out of a class; loaded when it is chosen.
final transferStudentsProvider = FutureProvider.autoDispose
    .family<List<TransferStudent>, int>(
      (ref, classId) => StudentTransfersRepository().getStudents(classId),
      retry: (retryCount, error) => null,
    );

/// Moves the chosen students. A provider so a test can stand in for the network.
typedef MoveStudents =
    Future<TransferResult> Function({
      required int fromClassId,
      required int toClassId,
      required String type,
      required String reason,
      required List<int> tokens,
    });

final moveStudentsProvider = Provider<MoveStudents>(
  (ref) =>
      ({
        required int fromClassId,
        required int toClassId,
        required String type,
        required String reason,
        required List<int> tokens,
      }) => StudentTransfersRepository().move(
        fromClassId: fromClassId,
        toClassId: toClassId,
        type: type,
        reason: reason,
        tokens: tokens,
      ),
);

/// One page of the transfer log for a search: (query, page).
typedef LoadTransferHistory =
    Future<TransferHistoryPage> Function(String query, int page);

final transferHistoryLoaderProvider = Provider<LoadTransferHistory>(
  (ref) =>
      (query, page) =>
          StudentTransfersRepository().getHistory(query: query, page: page),
);
