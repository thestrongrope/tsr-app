import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/unplaced_registrations.dart';
import '../providers/reports_provider.dart';

/// What happened in a place or reject flow that the list must hear about: the
/// registrant is no longer waiting, whether this person did it or someone else
/// got there first. Null from a flow means nothing changed.
class RegistrationOutcome {
  const RegistrationOutcome(this.message, {required this.byYou});

  final String message;
  final bool byYou;
}

const _generic = 'Something went wrong. Please try again.';

/// The server's own words for a refusal it explains (already handled, other
/// gender, no permission); a plain message for anything else.
String _failureMessage(Object error) {
  if (error is ApiException && {403, 409, 422}.contains(error.statusCode)) {
    return error.message;
  }
  return _generic;
}

/// Choose the class to place [registrant] in (#614). Shows what the web page
/// shows on choosing one: level, teacher, location and how many students.
class PlaceRegistrantSheet extends ConsumerStatefulWidget {
  const PlaceRegistrantSheet({super.key, required this.registrant});

  final Registrant registrant;

  @override
  ConsumerState<PlaceRegistrantSheet> createState() =>
      _PlaceRegistrantSheetState();
}

class _PlaceRegistrantSheetState extends ConsumerState<PlaceRegistrantSheet> {
  PlacementClass? _chosen;
  bool _placing = false;
  String? _error;

  Future<void> _place() async {
    final chosen = _chosen;
    if (chosen == null) return;
    setState(() {
      _placing = true;
      _error = null;
    });
    try {
      await ref.read(placeRegistrantProvider)(widget.registrant.id, chosen.id);
      if (!mounted) return;
      Navigator.of(context).pop(
        RegistrationOutcome(
          '${widget.registrant.name} placed in ${chosen.code}.',
          byYou: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 409) {
        Navigator.of(context).pop(RegistrationOutcome(e.message, byYou: false));
        return;
      }
      setState(() {
        _placing = false;
        _error = _failureMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(
      registrationClassesProvider(widget.registrant.id),
    );
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Place ${widget.registrant.name}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: classes.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e is ApiException && e.statusCode == 409
                          ? e.message
                          : 'The classes could not be loaded.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(
                        registrationClassesProvider(widget.registrant.id),
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
                data: (list) => list.isEmpty
                    ? const Text('There is no class you can place them in.')
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final c in list)
                            ListTile(
                              selected: _chosen?.id == c.id,
                              enabled: !_placing,
                              leading: Icon(
                                _chosen?.id == c.id
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              onTap: () => setState(() => _chosen = c),
                              title: Text('${c.code} · ${c.level}'),
                              subtitle: Text(
                                [
                                  if (c.teacher.isNotEmpty) c.teacher,
                                  if (c.location.isNotEmpty) c.location,
                                  '${c.students} students',
                                ].join(' · '),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _placing
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _chosen == null || _placing ? null : _place,
                  child: Text(_placing ? 'Placing…' : 'Place'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for the reason a registrant is turned down (required, at most 500
/// characters, as the server insists).
class RejectRegistrantDialog extends ConsumerStatefulWidget {
  const RejectRegistrantDialog({super.key, required this.registrant});

  final Registrant registrant;

  @override
  ConsumerState<RejectRegistrantDialog> createState() =>
      _RejectRegistrantDialogState();
}

class _RejectRegistrantDialogState
    extends ConsumerState<RejectRegistrantDialog> {
  final _reason = TextEditingController();
  bool _rejecting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) return;
    setState(() {
      _rejecting = true;
      _error = null;
    });
    try {
      await ref.read(rejectRegistrantProvider)(widget.registrant.id, reason);
      if (!mounted) return;
      Navigator.of(context).pop(
        RegistrationOutcome('${widget.registrant.name} rejected.', byYou: true),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 409) {
        Navigator.of(context).pop(RegistrationOutcome(e.message, byYou: false));
        return;
      }
      setState(() {
        _rejecting = false;
        _error = _failureMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reject ${widget.registrant.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reason,
            enabled: !_rejecting,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason'),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _rejecting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _reason.text.trim().isEmpty || _rejecting ? null : _reject,
          child: Text(_rejecting ? 'Rejecting…' : 'Reject'),
        ),
      ],
    );
  }
}
