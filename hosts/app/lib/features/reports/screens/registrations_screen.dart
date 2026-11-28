import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_manage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../classes/screens/create_class_screen.dart';
import '../models/unplaced_registrations.dart';
import '../providers/reports_provider.dart';
import '../widgets/registration_actions.dart';
import '../widgets/report_search.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// The people who have registered and are waiting to be placed in a class
/// (#605, #614), the mobile counterpart of the web's registrations page: every
/// detail the page shows, placing in a class, rejecting with a reason, and the
/// list as a file. The server decides which gender the user may see and what
/// they may do.
class RegistrationsScreen extends ConsumerStatefulWidget {
  const RegistrationsScreen({super.key});

  @override
  ConsumerState<RegistrationsScreen> createState() =>
      _RegistrationsScreenState();
}

class _RegistrationsScreenState extends ConsumerState<RegistrationsScreen> {
  int? _gender;
  String _search = '';
  RegistrationPeriod _period = RegistrationPeriod.all;
  bool _sharing = false;

  Future<void> _share(ReportFormat format) =>
      _shareFile(ref.read(shareRegistrationsProvider), format);

  Future<void> _shareAllocated(ReportFormat format) =>
      _shareFile(ref.read(shareAllocatedRegistrationsProvider), format);

  Future<void> _shareFile(ShareRegistrations share, ReportFormat format) async {
    setState(() => _sharing = true);
    try {
      await share(_gender, format);
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

  /// A place or reject finished, or found the registrant already dealt with:
  /// the list is stale either way.
  void _handled(RegistrationOutcome? outcome) {
    if (outcome == null || !mounted) return;
    ref.invalidate(registrationsProvider(_gender));
    if (outcome.byYou) {
      AppSnackBar.showSuccess(context, message: outcome.message);
    } else {
      AppSnackBar.showInfo(context, message: outcome.message);
    }
  }

  /// Opens the create-a-class form (#636); on success, the new class's manage
  /// screen, where the rest of its details are set.
  Future<void> _newClass() async {
    final classId = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute(builder: (_) => const CreateClassScreen()));
    if (classId == null || !mounted) return;
    context.push('/classes/$classId/manage');
  }

  Future<void> _place(Registrant registrant) async {
    final outcome = await showModalBottomSheet<RegistrationOutcome>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => PlaceRegistrantSheet(registrant: registrant),
    );
    _handled(outcome);
  }

  Future<void> _reject(Registrant registrant) async {
    final outcome = await showDialog<RegistrationOutcome>(
      context: context,
      builder: (_) => RejectRegistrantDialog(registrant: registrant),
    );
    _handled(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(capabilitiesProvider);
    // Only someone who reaches both genders chooses; everyone else is pinned.
    final choosesGender = capabilities.choosesRegistrationsGender;
    final waiting = ref.watch(registrationsProvider(_gender));

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Registrations'),
        actions: [
          if (capabilities.canCreateClass)
            IconButton(
              tooltip: 'New class',
              icon: const Icon(Icons.add),
              onPressed: _newClass,
            ),
          if (waiting.asData case AsyncData(
            :final value,
          ) when value.registrants.isNotEmpty)
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
          PopupMenuButton<ReportFormat>(
            tooltip: 'Placed in a class',
            icon: const Icon(Icons.download),
            enabled: !_sharing,
            onSelected: _shareAllocated,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ReportFormat.xlsx,
                child: Text('Placed, as Excel'),
              ),
              PopupMenuItem(
                value: ReportFormat.pdf,
                child: Text('Placed, as PDF'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        children: [
          if (choosesGender) ...[
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Gents')),
                ButtonSegment(value: 2, label: Text('Ladies')),
              ],
              selected: {_gender ?? waiting.asData?.value.gender ?? 1},
              onSelectionChanged: (choice) =>
                  setState(() => _gender = choice.first),
            ),
            const SizedBox(height: 12),
          ],
          // As on the web, the period is set aside while searching.
          if (_search.trim().isEmpty) ...[
            DropdownButtonFormField<RegistrationPeriod>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Registered'),
              items: [
                for (final p in RegistrationPeriod.values)
                  DropdownMenuItem(value: p, child: Text(p.label)),
              ],
              onChanged: (p) => setState(() => _period = p ?? _period),
            ),
            const SizedBox(height: 12),
          ],
          ReportSearchField(
            hint: 'Search by name or place',
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 12),
          ...waiting.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, _) => [
              const Text('The registrations could not be loaded.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(registrationsProvider(_gender)),
                  child: const Text('Try again'),
                ),
              ),
            ],
            data: _body,
          ),
        ],
      ),
    );
  }

  List<Widget> _body(UnplacedRegistrations data) {
    if (data.registrants.isEmpty) {
      return [const Text('Nobody is waiting to be placed.')];
    }
    final searching = _search.trim().isNotEmpty;
    final now = DateTime.now();
    final shown = [
      for (final r in data.registrants)
        if (searching
            ? matchesSearch(_search, [r.name, r.city, r.country])
            : _period.includes(r.registeredOn, now))
          r,
    ];

    return [
      Text(
        shown.length == data.registrants.length
            ? '${data.registrants.length} waiting to be placed'
            : '${shown.length} of ${data.registrants.length} waiting to be placed',
      ),
      const SizedBox(height: 12),
      if (shown.isEmpty)
        Text(
          searching
              ? 'No one matches your search.'
              : 'No one registered in this period.',
        )
      else
        for (final r in shown)
          _RegistrantCard(
            registrant: r,
            canReject: ref.watch(capabilitiesProvider).canRejectRegistrations,
            onPlace: () => _place(r),
            onReject: () => _reject(r),
          ),
    ];
  }
}

class _RegistrantCard extends StatefulWidget {
  const _RegistrantCard({
    required this.registrant,
    required this.canReject,
    required this.onPlace,
    required this.onReject,
  });

  final Registrant registrant;
  final bool canReject;
  final VoidCallback onPlace;
  final VoidCallback onReject;

  @override
  State<_RegistrantCard> createState() => _RegistrantCardState();
}

class _RegistrantCardState extends State<_RegistrantCard> {
  bool _expanded = false;

  /// The details panel's rows, in the web's order, leaving out what they did
  /// not say.
  List<(String, String)> _details() {
    final r = widget.registrant;
    final age = r.ageIn(DateTime.now());
    final interests = r.interestList.join(', ');
    return [
      ('Token', r.token == 0 ? '' : '${r.token}'),
      ('For class', r.requestedClass),
      ('Email', r.email),
      ('Mobile', r.mobile),
      ('Residence', r.residenceLocation),
      ('Location', r.preferredLocation),
      ('Work', r.workLocation),
      ('Birth year / age', r.birthYear == null ? '' : '${r.birthYear} / $age'),
      ('Level', r.classLevel),
      ('Class', r.classNumber),
      ('Profession', r.profession),
      (
        'Islamic study',
        r.islamicStudyYears.isEmpty ? '' : '${r.islamicStudyYears} yrs',
      ),
      ('Interests', interests),
      ('City', r.city),
      ('Country', r.country),
      ('Pincode', r.zip),
    ].where((row) => row.$2.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final registrant = widget.registrant;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppTheme.mediumText);
    final wants = [
      if (registrant.preferredLocation.isNotEmpty)
        'Prefers ${registrant.preferredLocation}',
      if (registrant.requestedClass.isNotEmpty)
        'Asked for ${registrant.requestedClass}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              registrant.name,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (registrant.place.isNotEmpty)
              Text(registrant.place, style: muted),
            if (wants.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(wants.join(' · ')),
            ],
            const SizedBox(height: 4),
            Text(
              '${registrant.status} · registered ${registrant.registeredOn}',
              style: muted,
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              for (final (label, value) in _details())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 120, child: Text(label, style: muted)),
                      Expanded(child: SelectableText(value)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Hide details' : 'Details'),
                ),
                FilledButton(
                  onPressed: widget.onPlace,
                  child: const Text('Place'),
                ),
                if (widget.canReject)
                  OutlinedButton(
                    onPressed: widget.onReject,
                    child: const Text('Reject'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
