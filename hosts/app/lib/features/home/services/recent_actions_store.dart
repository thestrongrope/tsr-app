import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/constants/app_constants.dart';
import '../models/recent_action.dart';

/// Keeps each member's last visits to whitelisted screens on this device, in
/// the settings box under `recent_actions:<token>`. A member sees only their
/// own key; [clearAll] removes every member's on sign-out.
class RecentActionsStore {
  RecentActionsStore([Box? box]) : _box = box;

  /// How many visits are kept per member.
  static const maxEvents = 30;

  static const _prefix = 'recent_actions:';

  final Box? _box;

  Box get _settings => _box ?? Hive.box(AppConstants.settingsBoxKey);

  String _key(int token) => '$_prefix$token';

  /// Oldest first. Empty when nothing is stored or the box is unavailable.
  List<RecentAction> read(int token) {
    try {
      final stored = _settings.get(_key(token));
      if (stored is! List) return const [];
      return [for (final item in stored) ?RecentAction.fromJson(item)];
    } catch (e) {
      debugPrint('🟡 Failed to read recent actions: $e');
      return const [];
    }
  }

  /// Adds [action] and drops all but the newest [maxEvents]. Returns what is
  /// now stored.
  Future<List<RecentAction>> add(int token, RecentAction action) async {
    final all = [...read(token), action];
    final kept = all.length > maxEvents
        ? all.sublist(all.length - maxEvents)
        : all;
    try {
      await _settings.put(_key(token), [for (final a in kept) a.toJson()]);
    } catch (e) {
      debugPrint('🟡 Failed to save recent actions: $e');
    }
    return kept;
  }

  /// Deletes every member's visits.
  Future<void> clearAll() async {
    final box = _settings;
    final keys = box.keys.where((k) => '$k'.startsWith(_prefix)).toList();
    await box.deleteAll(keys);
  }
}
