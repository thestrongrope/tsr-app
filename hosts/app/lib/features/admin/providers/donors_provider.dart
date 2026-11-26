import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/share_bytes.dart';
import '../../reports/providers/reports_provider.dart' show ReportFormat;
import '../models/donors.dart';
import '../repositories/donors_repository.dart';

/// The donors, as the server lists them.
final donorsProvider = FutureProvider.autoDispose<List<Donor>>(
  (ref) => DonorsRepository().getDonors(),
  retry: (retryCount, error) => null,
);

/// Fetches the donors as a file and hands it to the share sheet. A provider so
/// a test can stand in for the network and the sheet; it throws if the file
/// cannot be fetched, and the screen says so.
typedef ShareDonors = Future<void> Function(ReportFormat format);

final shareDonorsProvider = Provider<ShareDonors>(
  (ref) => (format) async {
    final bytes = await DonorsRepository().download(format.name);
    await shareBytes(bytes, 'Donors.${format.name}');
  },
);
