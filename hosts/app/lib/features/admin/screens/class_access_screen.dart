import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../core/widgets/tab_bar_inset.dart';
import '../models/class_access.dart';
import '../models/permission_grants.dart';
import '../providers/class_access_provider.dart';
import 'class_access_add_sheet.dart';

/// Find a member to see and change the classes they manage (#1034).
class ClassAccessScreen extends ConsumerStatefulWidget {
  const ClassAccessScreen({super.key});

  @override
  ConsumerState<ClassAccessScreen> createState() => _ClassAccessScreenState();
}

class _ClassAccessScreenState extends ConsumerState<ClassAccessScreen> {
  final _query = TextEditingController();
  List<MemberRef>? _members;
  bool _loading = false;
  Object? _error;

  /// The newest search; an older reply that arrives later is ignored.
  int _latest = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    final mine = ++_latest;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final found = await ref.read(classAccessSearchProvider)(q);
      if (mounted && mine == _latest) setState(() => _members = found);
    } catch (e) {
      if (mounted && mine == _latest) {
        setState(() {
          _members = null;
          _error = e;
        });
      }
    } finally {
      if (mounted && mine == _latest) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: const Text('Class admins')),
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
              hintText: 'Name or token',
              helperText: 'At least 2 characters',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: _search,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (error != null)
            AppErrorView(error: error, compact: true, onRetry: _search),
          if (members != null && members.isEmpty && !_loading)
            const AppEmptySection(
              icon: Icons.search_off_rounded,
              message:
                  'No member found. Check the spelling, or search by name '
                  'or token.',
            ),
          if (members != null)
            for (final m in members)
              ListTile(
                title: Text(m.name),
                subtitle: Text('Token ${m.token}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(AppRoutes.adminClassAccessMemberPath(m.token)),
              ),
        ],
      ),
    );
  }
}

/// The classes one member manages and the rule each comes from, with the
/// means to add and remove access (#1034).
class MemberClassAccessScreen extends ConsumerStatefulWidget {
  const MemberClassAccessScreen({super.key, required this.token});

  final int token;

  @override
  ConsumerState<MemberClassAccessScreen> createState() =>
      _MemberClassAccessScreenState();
}

class _MemberClassAccessScreenState
    extends ConsumerState<MemberClassAccessScreen> {
  bool _removing = false;

  int get _token => widget.token;

  void _reload() {
    if (mounted) ref.invalidate(memberAccessProvider(_token));
  }

  Future<void> _add(MemberAccess view) async {
    final outcome = await showModalBottomSheet<AddAccessOutcome>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => AddClassAccessSheet(
        token: _token,
        version: view.version,
        onWritten: _reload,
      ),
    );
    if (outcome == null || !mounted) return;
    if (outcome == AddAccessOutcome.memberChanged) {
      AppSnackBar.showError(context, message: memberChangedMessage);
      return;
    }
    AppSnackBar.showSuccess(context, message: 'Access added.');
  }

  Future<void> _remove(MemberAccess view, AccessRule rule) async {
    if (_removing) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RemoveDialog(rule: rule),
    );
    if (reason == null || !mounted) return;
    setState(() => _removing = true);
    try {
      await ref.read(revokeAccessProvider)(
        id: rule.id,
        reason: reason,
        version: view.version,
      );
      _reload();
      if (mounted) {
        AppSnackBar.showSuccess(context, message: 'Access removed.');
      }
    } on MemberChanged {
      _reload();
      if (mounted) {
        AppSnackBar.showError(context, message: memberChangedMessage);
      }
    } catch (e) {
      // Already removed by someone else: read the member again so it shows.
      if (e is ApiException && e.statusCode == 409) _reload();
      if (mounted) {
        AppSnackBar.showError(context, message: classAccessSaveFailure(e));
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberAccessProvider(_token));
    return Scaffold(
      appBar: AppBar(title: const Text('Class admins')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: _reload),
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
            if (view.fromRole != null) ...[
              AppSurfaceCard(child: Text(view.fromRole!)),
              const SizedBox(height: AppTheme.spacingMD),
            ],
            const AppSectionHeader(title: 'Classes they manage'),
            const SizedBox(height: AppTheme.spacingSM),
            if (view.rules.isEmpty && view.fromRole == null)
              AppEmptySection(
                icon: Icons.groups_outlined,
                message:
                    '${view.member.name} does not manage any class yet. '
                    'Add access to make them a class admin.',
              ),
            for (final rule in view.rules)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: _RuleCard(
                  rule: rule,
                  onRemove: _removing ? null : () => _remove(view, rule),
                ),
              ),
            const SizedBox(height: AppTheme.spacingSM),
            FilledButton(
              onPressed: () => _add(view),
              child: const Text('Add class access'),
            ),
          ],
        ),
      ),
    );
  }
}

String _day(String timestamp) =>
    timestamp.length >= 10 ? timestamp.substring(0, 10) : timestamp;

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.onRemove});

  final AccessRule rule;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final more = rule.classCount - rule.classes.length;
    final count =
        '${rule.classCount} ${rule.classCount == 1 ? 'class' : 'classes'}';
    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(rule.note),
            subtitle: Text('$count. Added ${_day(rule.createdAt)}'),
            children: [
              for (final c in rule.classes)
                ListTile(
                  dense: true,
                  title: Text(c.name),
                  subtitle: Text(c.code),
                ),
              if (more > 0)
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: Text('and $more more'),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onRemove, child: const Text('Remove')),
          ),
        ],
      ),
    );
  }
}

class _RemoveDialog extends StatefulWidget {
  const _RemoveDialog({required this.rule});

  final AccessRule rule;

  @override
  State<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<_RemoveDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Remove this access?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.rule.note),
          const SizedBox(height: AppTheme.spacingMD),
          TextField(
            controller: _reason,
            maxLength: maxClassAccessReason,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Why is this being removed?',
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
          child: const Text('Remove access'),
        ),
      ],
    );
  }
}
