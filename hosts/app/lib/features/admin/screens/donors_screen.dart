import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../reports/providers/reports_provider.dart' show ReportFormat;
import '../../reports/widgets/report_search.dart';
import '../models/donors.dart';
import '../providers/donors_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The donors list (#421), the mobile counterpart of the web's Donors page:
/// name, email, mobile and place of every donor, searchable on any of them, and
/// the list as a file. Shown to whoever holds `donors:read`; the server decides.
class DonorsScreen extends ConsumerStatefulWidget {
  const DonorsScreen({super.key});

  @override
  ConsumerState<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends ConsumerState<DonorsScreen> {
  String _search = '';
  bool _sharing = false;

  Future<void> _share(ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await ref.read(shareDonorsProvider)(format);
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          message: 'The file could not be prepared. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final donors = ref.watch(donorsProvider);
    final hasDonors = donors.asData?.value.isNotEmpty == true;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Donors'),
        actions: [
          if (hasDonors)
            PopupMenuButton<ReportFormat>(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              enabled: !_sharing,
              onSelected: _share,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: ReportFormat.xlsx,
                  child: Text('Share as Excel'),
                ),
                PopupMenuItem(
                  value: ReportFormat.pdf,
                  child: Text('Share as PDF'),
                ),
              ],
            ),
        ],
      ),
      body: donors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The donors could not be loaded.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(donorsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (all) => all.isEmpty
            ? const Center(child: Text('There are no donors.'))
            : _list(all),
      ),
    );
  }

  Widget _list(List<Donor> all) {
    final shown = [
      for (final d in all)
        if (matchesSearch(_search, d.searchFields)) d,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ReportSearchField(
            hint: 'Search by name, email, mobile or place',
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              shown.length == all.length
                  ? '${all.length} donors'
                  : '${shown.length} of ${all.length} donors',
            ),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('No donor matches your search.'))
              : ListView.builder(
                  padding: withTabBarInset(context, const EdgeInsets.all(16)),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _DonorCard(donor: shown[i]),
                ),
        ),
      ],
    );
  }
}

class _DonorCard extends StatelessWidget {
  const _DonorCard({required this.donor});

  final Donor donor;

  @override
  Widget build(BuildContext context) {
    final detail = [
      donor.email,
      donor.mobile,
      donor.place,
    ].where((line) => line.isNotEmpty);
    return Card(
      child: ListTile(
        title: Text(
          donor.name.isEmpty ? '(no name)' : donor.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(detail.join('\n')),
        isThreeLine: detail.length > 1,
      ),
    );
  }
}
