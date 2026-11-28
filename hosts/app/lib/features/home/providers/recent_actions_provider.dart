import 'package:flutter/material.dart';
import 'package:riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_home.dart';
import '../../../core/router/route_config.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/recent_action.dart';
import '../services/recent_actions_store.dart';

/// How many items the card shows.
const jumpBackInLimit = 4;

/// The signed-in member's token, or null for a guest (token 0) and when signed
/// out. Nothing is recorded or shown without one.
final recentActionsMemberProvider = Provider<int?>((ref) {
  final auth = ref.watch(authStateProvider);
  final token = auth.user?.token;
  if (auth.status != AuthStatus.authenticated || token == null || token <= 0) {
    return null;
  }
  return token;
});

final recentActionsStoreProvider = Provider<RecentActionsStore>(
  (ref) => RecentActionsStore(),
);

/// The member's remembered visits. A different member gets a new notifier, so
/// one never sees another's.
final recentActionsProvider =
    StateNotifierProvider<RecentActionsNotifier, List<RecentAction>>((ref) {
      final store = ref.watch(recentActionsStoreProvider);
      return RecentActionsNotifier(
        store,
        ref.watch(recentActionsMemberProvider),
      );
    });

class RecentActionsNotifier extends StateNotifier<List<RecentAction>> {
  RecentActionsNotifier(this._store, this._token, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(_token == null ? const [] : _store.read(_token));

  final RecentActionsStore _store;
  final int? _token;
  final DateTime Function() _now;

  /// Remembers a visit. Does nothing for a guest.
  Future<void> record(RecentActionKind kind, {int? classId}) async {
    final token = _token;
    if (token == null) return;
    state = await _store.add(
      token,
      RecentAction(kind: kind, classId: classId, at: _now()),
    );
  }
}

/// One tappable item on the card.
class JumpBackItem {
  const JumpBackItem({
    required this.title,
    required this.icon,
    required this.path,
  });

  final String title;
  final IconData icon;
  final String path;
}

/// The card's items: the top-ranked remembered visits that are still valid.
/// A class no longer in the live class list, or an action the member's
/// permissions no longer allow, is dropped; titles come from the live class,
/// never from storage.
final jumpBackItemsProvider = Provider<List<JumpBackItem>>((ref) {
  final events = ref.watch(recentActionsProvider);
  final capabilities = ref.watch(capabilitiesProvider);

  final items = <JumpBackItem>[];
  for (final group in rankRecentActions(events, DateTime.now())) {
    final item = _liveItem(group, capabilities);
    if (item != null) items.add(item);
    if (items.length == jumpBackInLimit) break;
  }
  return items;
});

/// Each check is the one the router applies to the same screen.
JumpBackItem? _liveItem(
  RecentActionGroup group,
  Capabilities capabilities,
) {
  if (!group.kind.forClass) {
    return switch (group.kind) {
      RecentActionKind.thisWeek when capabilities.mayOpenThisWeek =>
        const JumpBackItem(
          title: 'This week',
          icon: Icons.event_note_outlined,
          path: AppRoutes.adminThisWeek,
        ),
      RecentActionKind.adminQuiz when capabilities.mayOpenQuizAdmin =>
        const JumpBackItem(
          title: 'Grand and Mega quiz',
          icon: Icons.emoji_events_outlined,
          path: AppRoutes.adminQuiz,
        ),
      RecentActionKind.adminStandardMcqs
          when capabilities.mayOpenStandardMcqs =>
        const JumpBackItem(
          title: 'Standard MCQs',
          icon: Icons.quiz_outlined,
          path: AppRoutes.adminStandardMcqs,
        ),
      RecentActionKind.adminTransfers when capabilities.mayOpenTransfers =>
        const JumpBackItem(
          title: 'Transfer students',
          icon: Icons.swap_horiz,
          path: AppRoutes.adminTransfers,
        ),
      RecentActionKind.adminWhatsappReminders
          when capabilities.mayManageWhatsappReminders =>
        const JumpBackItem(
          title: 'WhatsApp reminders',
          icon: Icons.chat_outlined,
          path: AppRoutes.adminWhatsappReminders,
        ),
      _ => null,
    };
  }

  final cls = capabilities.classForJumpBack(group.classId);
  if (cls == null) return null;
  bool allowed(String permission) =>
      capabilities.classForJumpBack(cls.id, permission: permission) != null;
  final base = '/classes/${cls.id}';
  return switch (group.kind) {
    RecentActionKind.classDashboard => JumpBackItem(
      title: '${cls.name}: Dashboard',
      icon: Icons.dashboard_outlined,
      path: '$base/dashboard',
    ),
    RecentActionKind.classQuizzes => JumpBackItem(
      title: '${cls.name}: Quizzes',
      icon: Icons.quiz_outlined,
      path: '$base/quizzes',
    ),
    RecentActionKind.classConduction when allowed('sessions:create') =>
      JumpBackItem(
        title: '${cls.name}: Conduction',
        icon: Icons.fact_check_outlined,
        path: '$base/conduction',
      ),
    RecentActionKind.classNotification when allowed('notifications:send') =>
      JumpBackItem(
        title: '${cls.name}: Send announcement',
        icon: Icons.campaign_outlined,
        path: '$base/notifications/send',
      ),
    _ => null,
  };
}
