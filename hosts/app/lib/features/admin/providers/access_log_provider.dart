import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/share_bytes.dart';
import '../../reports/providers/reports_provider.dart' show ReportFormat;
import '../models/access_log.dart';
import '../repositories/access_log_repository.dart';

final accessLogRepositoryProvider = Provider<AccessLogRepository>((ref) {
  return AccessLogRepository();
});

/// The access log for one filter. A failed load shows at once with a Retry
/// button, not after silent retries.
final accessLogProvider = FutureProvider.autoDispose
    .family<AccessLog, AccessLogFilter>(
      (ref, filter) =>
          ref.watch(accessLogRepositoryProvider).getAccessLog(filter),
      retry: (_, _) => null,
    );

/// Fetches the filtered accesses as a file and hands it to the share sheet. A
/// provider so a test can stand in for the network and the sheet; it throws if
/// the file cannot be fetched, and the screen says so.
typedef ShareAccessLog =
    Future<void> Function(ReportFormat format, AccessLogFilter filter);

final shareAccessLogProvider = Provider<ShareAccessLog>(
  (ref) => (format, filter) async {
    final bytes = await ref
        .read(accessLogRepositoryProvider)
        .download(format.name, filter);
    await shareBytes(bytes, 'Admin_access_log.${format.name}');
  },
);
