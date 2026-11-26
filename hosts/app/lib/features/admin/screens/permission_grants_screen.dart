import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../models/permission_grants.dart';
import '../providers/permission_grants_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

const _maxReason = 300;

void _showError(BuildContext context, Object error) {
  final message = error is ApiException
      ? error.message
      : 'That did not work. Nothing was changed.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Find a member to see and change what they may do (#567). Super admin only.
class PermissionGrantsScreen extends ConsumerStatefulWidget {
  const PermissionGrantsScreen({super.key});

  @override
  ConsumerState<PermissionGrantsScreen> createState() =>
      _PermissionGrantsScreenState();
}

class _PermissionGrantsScreenState
    extends ConsumerState<PermissionGrantsScreen> {
  final _query = TextEditingController();
  List<MemberRef>? _members;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await ref.read(memberSearchProvider)(q);
      if (mounted) setState(() => _members = found);
    } catch (e) {
      if (mounted) {
        setState(() {
          _members = null;
          _error = e is ApiException ? e.message : 'Could not search.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return Scaffold(
      appBar: AppBar(title: const Text('Access')),
      body: ListView(
        padding: withTabBarInset(
          context,
          const EdgeInsets.all(AppTheme.spacingLG),
        ),
        children: [
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Find a member',
              hintText: 'Name, token, email or mobile',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: _search,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!),
          if (members != null && members.isEmpty && !_loading)
            const Text('No member found.'),
          if (members != null)
            for (final m in members)
              ListTile(
                title: Text(m.name),
                subtitle: Text('Token ${m.token}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(AppRoutes.adminPermissionMemberPath(m.token)),
              ),
        ],
      ),
    );
  }
}

/// What one member holds, from their role and granted to them, apart, with the
/// means to grant and revoke (#567). Super admin only.
class MemberPermissionsScreen extends ConsumerWidget {
  const MemberPermissionsScreen({super.key, required this.token});

  final int token;

  Future<void> _grant(
    BuildContext context,
    WidgetRef ref,
    MemberPermissions view,
  ) async {
    final choice =
        await showModalBottomSheet<({String permission, String reason})>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          builder: (_) => _GrantSheet(grantable: view.grantable),
        );
    if (choice == null || !context.mounted) return;
    try {
      await ref.read(grantPermissionProvider)(
        token: token,
        permission: choice.permission,
        reason: choice.reason,
      );
      ref.invalidate(memberPermissionsProvider(token));
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    GrantedPermission grant,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RevokeDialog(grant: grant),
    );
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(revokePermissionProvider)(id: grant.id, reason: reason);
      ref.invalidate(memberPermissionsProvider(token));
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memberPermissionsProvider(token));
    return Scaffold(
      appBar: AppBar(title: const Text('Access')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e is ApiException ? e.message : 'Could not load this member.',
              ),
              const SizedBox(height: AppTheme.spacingMD),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(memberPermissionsProvider(token)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (view) => ListView(
          padding: withTabBarInset(
            context,
            const EdgeInsets.all(AppTheme.spacingLG),
          ),
          children: [
            Text(
              view.member.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Token ${view.member.token}'),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              'Granted to them',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (view.granted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
                child: Text('Nothing has been granted to this member.'),
              ),
            for (final g in view.granted)
              _PermissionCard(
                info: g.info,
                detail: [
                  if (g.reason != null) 'Why: ${g.reason}',
                  if (g.grantedBy != null || g.grantedAt != null)
                    'Granted ${[if (g.grantedBy != null) 'by ${g.grantedBy}', if (g.grantedAt != null) 'on ${g.grantedAt!.substring(0, 10)}'].join(' ')}',
                ],
                action: TextButton(
                  onPressed: () => _revoke(context, ref, g),
                  child: const Text('Revoke'),
                ),
              ),
            const SizedBox(height: AppTheme.spacingSM),
            FilledButton(
              onPressed: view.grantable.isEmpty
                  ? null
                  : () => _grant(context, ref, view),
              child: const Text('Grant a permission'),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              'From their role',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text('Given by their role. Not changed here.'),
            if (view.fromRole.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
                child: Text('Their role gives no permissions of its own.'),
              ),
            for (final p in view.fromRole) _PermissionCard(info: p),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.info,
    this.detail = const [],
    this.action,
  });

  final PermissionInfo info;
  final List<String> detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: AppTheme.spacingSM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.description,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(info.reach),
                  for (final line in detail) Text(line),
                ],
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// Choose a permission, read what it allows and how far, give the reason.
class _GrantSheet extends StatefulWidget {
  const _GrantSheet({required this.grantable});

  final List<PermissionInfo> grantable;

  @override
  State<_GrantSheet> createState() => _GrantSheetState();
}

class _GrantSheetState extends State<_GrantSheet> {
  final _reason = TextEditingController();
  PermissionInfo? _chosen;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spacingLG,
        right: AppTheme.spacingLG,
        top: AppTheme.spacingLG,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLG,
      ),
      child: chosen == null
          ? ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Choose a permission',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final p in widget.grantable)
                  ListTile(
                    title: Text(p.description),
                    subtitle: Text(p.reach),
                    onTap: () => setState(() => _chosen = p),
                  ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chosen.description,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(chosen.reach),
                const SizedBox(height: AppTheme.spacingMD),
                TextField(
                  controller: _reason,
                  maxLength: _maxReason,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Why is this being granted?',
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _chosen = null),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    FilledButton(
                      onPressed: _reason.text.trim().isEmpty
                          ? null
                          : () => Navigator.of(context).pop((
                              permission: chosen.name,
                              reason: _reason.text.trim(),
                            )),
                      child: const Text('Grant'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RevokeDialog extends StatefulWidget {
  const _RevokeDialog({required this.grant});

  final GrantedPermission grant;

  @override
  State<_RevokeDialog> createState() => _RevokeDialogState();
}

class _RevokeDialogState extends State<_RevokeDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Revoke this permission?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.grant.info.description),
          const SizedBox(height: AppTheme.spacingMD),
          TextField(
            controller: _reason,
            maxLength: _maxReason,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Why is this being revoked?',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _reason.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text('Revoke'),
        ),
      ],
    );
  }
}
