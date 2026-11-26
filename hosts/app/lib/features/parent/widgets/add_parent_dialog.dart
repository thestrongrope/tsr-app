import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/user_message.dart';
import '../providers/parent_provider.dart';

const _ambiguousTokenMessage =
    'More than one member has that token number. Please contact an admin.';

/// The server refuses a token number that more than one member holds with
/// code `ambiguous_token`; the staff member cannot fix that, an admin can.
bool _isAmbiguousToken(Object error) =>
    error is ApiException && error.body?['code'] == 'ambiguous_token';

/// Dialog to link a parent to a child via one-time link or staff token entry (#633).
class AddParentDialog extends ConsumerStatefulWidget {
  final int childToken;
  final String childName;
  final bool allowDirectTokenEntry;

  const AddParentDialog({
    super.key,
    required this.childToken,
    required this.childName,
    this.allowDirectTokenEntry = false,
  });

  @override
  ConsumerState<AddParentDialog> createState() => _AddParentDialogState();
}

class _AddParentDialogState extends ConsumerState<AddParentDialog> {
  int _selectedMode = 0; // 0 = Invite link, 1 = Token entry

  // Invite link state
  bool _isLoadingLink = false;
  String? _linkUrl;
  String? _linkError;

  // Direct token entry state
  final TextEditingController _tokenController = TextEditingController();
  bool _isLookingUp = false;
  bool _isSaving = false;
  String? _lookupName;
  String? _tokenError;
  String _relationship = 'Father';

  @override
  void initState() {
    super.initState();
    _createLink();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _createLink() async {
    setState(() {
      _isLoadingLink = true;
      _linkError = null;
    });

    try {
      final repo = ref.read(parentRepositoryProvider);
      final invite = await repo.createInviteLink(widget.childToken);
      if (mounted) {
        setState(() {
          _isLoadingLink = false;
          _linkUrl = invite.url;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLink = false;
          _linkError = userMessage(e);
        });
      }
    }
  }

  Future<void> _lookupParent() async {
    final tokenText = _tokenController.text.trim();
    final parentToken = int.tryParse(tokenText);
    if (parentToken == null || parentToken <= 0) {
      setState(() {
        _tokenError = 'Please enter a valid token number';
        _lookupName = null;
      });
      return;
    }

    setState(() {
      _isLookingUp = true;
      _tokenError = null;
      _lookupName = null;
    });

    try {
      final repo = ref.read(parentRepositoryProvider);
      final name = await repo.lookupParentName(widget.childToken, parentToken);
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          if (name != null && name.isNotEmpty) {
            _lookupName = name;
          } else {
            _tokenError = 'Parent not found with token #$parentToken';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
          _tokenError = _isAmbiguousToken(e)
              ? _ambiguousTokenMessage
              : 'Member not found or cannot be linked';
        });
      }
    }
  }

  Future<void> _confirmAndSave() async {
    final parentToken = int.tryParse(_tokenController.text.trim());
    if (parentToken == null || _lookupName == null) return;

    setState(() {
      _isSaving = true;
      _tokenError = null;
    });

    try {
      final repo = ref.read(parentRepositoryProvider);
      await repo.addParentDirect(
        widget.childToken,
        parentToken,
        _relationship.toLowerCase(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _tokenError =
              _isAmbiguousToken(e) ? _ambiguousTokenMessage : userMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Add Parent for ${widget.childName}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.allowDirectTokenEntry) ...[
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Invite Link'),
                      icon: Icon(Icons.link),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('By Token'),
                      icon: Icon(Icons.badge_outlined),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (set) {
                    setState(() => _selectedMode = set.first);
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (_selectedMode == 0) _buildInviteLinkView(theme) else _buildTokenEntryView(theme),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_selectedMode == 1)
          FilledButton(
            key: const Key('confirm-add-parent-button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(104, 40),
            ),
            onPressed: (_lookupName != null && !_isSaving) ? _confirmAndSave : null,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm', maxLines: 1),
          ),
      ],
    );
  }

  Widget _buildInviteLinkView(ThemeData theme) {
    if (_isLoadingLink) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_linkError != null) {
      return Column(
        children: [
          Text(_linkError!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _createLink,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share this one-time invite link with the parent. '
          'They will sign in, choose their relationship, and accept.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (_linkUrl != null && _linkUrl!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _linkUrl!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy Link'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _linkUrl!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTokenEntryView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter the parent\'s token number to look them up and link directly.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('parent-token-input'),
                controller: _tokenController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Parent Token',
                  hintText: 'e.g. 1001',
                  isDense: true,
                  errorText: _tokenError,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _lookupParent(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              height: 48,
              child: ElevatedButton(
                key: const Key('lookup-parent-button'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                ),
                onPressed: _isLookingUp ? null : _lookupParent,
                child: _isLookingUp
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lookup'),
              ),
            ),
          ],
        ),
        if (_lookupName != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm Person:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade900,
                        ),
                      ),
                      Text(
                        _lookupName!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('relationship-picker'),
            initialValue: _relationship,
            decoration: const InputDecoration(
              labelText: 'Relationship',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Father', child: Text('Father')),
              DropdownMenuItem(value: 'Mother', child: Text('Mother')),
              DropdownMenuItem(value: 'Guardian', child: Text('Guardian')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _relationship = val);
            },
          ),
        ],
      ],
    );
  }
}
