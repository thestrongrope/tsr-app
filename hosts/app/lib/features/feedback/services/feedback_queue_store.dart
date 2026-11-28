import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/constants/app_constants.dart';

/// A feedback message the member wrote with no network, waiting to be sent.
///
/// [clientId] is created once and sent with every attempt, so the server
/// stores a message once however many times it is resent. [payload] holds
/// what goes in the request besides the id (`text` today); a later feature
/// can add keys without changing the stored format. [error] is set once the
/// server refused it.
class QueuedFeedback {
  const QueuedFeedback({
    required this.clientId,
    required this.payload,
    required this.writtenAt,
    this.error,
  });

  final String clientId;
  final Map<String, dynamic> payload;
  final DateTime writtenAt;
  final String? error;

  bool get failed => error != null;

  String get text => payload['text'] as String? ?? '';

  QueuedFeedback withError(String? message) => QueuedFeedback(
    clientId: clientId,
    payload: payload,
    writtenAt: writtenAt,
    error: message,
  );

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    'payload': payload,
    'writtenAt': writtenAt.millisecondsSinceEpoch,
    'error': error,
  };

  factory QueuedFeedback.fromJson(Map<String, dynamic> json) => QueuedFeedback(
    clientId: json['clientId'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    writtenAt: DateTime.fromMillisecondsSinceEpoch(json['writtenAt'] as int),
    error: json['error'] as String?,
  );
}

/// Keeps each member's unsent feedback on this device, in the settings box
/// under `feedback_queue:<token>`. [clearAll] removes every member's on
/// sign-out. Stored as JSON strings, like the conduction queue.
class FeedbackQueueStore {
  FeedbackQueueStore([Box? box]) : _box = box;

  static const _prefix = 'feedback_queue:';

  final Box? _box;

  Box get _settings => _box ?? Hive.box(AppConstants.settingsBoxKey);

  String _key(int token) => '$_prefix$token';

  /// Oldest first. Empty when nothing is stored or the box is unavailable.
  List<QueuedFeedback> read(int token) {
    try {
      final stored = _settings.get(_key(token));
      if (stored is! List) return const [];
      return [
        for (final item in stored)
          QueuedFeedback.fromJson(jsonDecode(item as String)),
      ];
    } catch (e) {
      debugPrint('🟡 Failed to read the feedback queue: $e');
      return const [];
    }
  }

  /// Replaces what is stored for [token] with [items].
  Future<void> write(int token, List<QueuedFeedback> items) async {
    try {
      if (items.isEmpty) {
        await _settings.delete(_key(token));
      } else {
        await _settings.put(_key(token), [
          for (final i in items) jsonEncode(i.toJson()),
        ]);
      }
    } catch (e) {
      debugPrint('🟡 Failed to save the feedback queue: $e');
    }
  }

  /// Deletes every member's queue.
  Future<void> clearAll() async {
    final box = _settings;
    final keys = box.keys.where((k) => '$k'.startsWith(_prefix)).toList();
    await box.deleteAll(keys);
  }
}
