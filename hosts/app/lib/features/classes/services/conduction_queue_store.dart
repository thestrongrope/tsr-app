import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../../core/constants/app_constants.dart';

/// A conduction record the teacher saved with no network, waiting to be sent.
///
/// [payload] is exactly what `POST /classes/{id}/conduction` takes, including
/// `recordedAt`, the moment the teacher pressed save: the server keeps it as
/// the record's creation time so the 10-day edit window does not restart when
/// the record is sent late. [error] is set once the server refused it.
class QueuedConduction {
  const QueuedConduction({
    required this.classId,
    required this.conductedOn,
    required this.payload,
    this.error,
  });

  final int classId;

  /// `yyyy-MM-dd`, the record's date.
  final String conductedOn;
  final Map<String, dynamic> payload;
  final String? error;

  bool get failed => error != null;

  /// One entry per class and date: saving the same day again replaces it.
  String get key => '$classId:$conductedOn';

  QueuedConduction withError(String? message) => QueuedConduction(
    classId: classId,
    conductedOn: conductedOn,
    payload: payload,
    error: message,
  );

  Map<String, dynamic> toJson() => {
    'classId': classId,
    'conductedOn': conductedOn,
    'payload': payload,
    'error': error,
  };

  factory QueuedConduction.fromJson(Map<String, dynamic> json) =>
      QueuedConduction(
        classId: json['classId'] as int,
        conductedOn: json['conductedOn'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        error: json['error'] as String?,
      );
}

/// Keeps each member's unsent conduction records on this device, in the
/// settings box under `conduction_queue:<token>`. A member sees only their own
/// key; [clearAll] removes every member's on sign-out.
///
/// Stored as JSON strings: Hive hands nested maps back as `Map<dynamic,
/// dynamic>`, which would break the typed payload.
class ConductionQueueStore {
  ConductionQueueStore([Box? box]) : _box = box;

  static const _prefix = 'conduction_queue:';

  final Box? _box;

  Box get _settings => _box ?? Hive.box(AppConstants.settingsBoxKey);

  String _key(int token) => '$_prefix$token';

  /// Oldest first. Empty when nothing is stored or the box is unavailable.
  List<QueuedConduction> read(int token) {
    try {
      final stored = _settings.get(_key(token));
      if (stored is! List) return const [];
      return [
        for (final item in stored)
          QueuedConduction.fromJson(jsonDecode(item as String)),
      ];
    } catch (e) {
      debugPrint('🟡 Failed to read the conduction queue: $e');
      return const [];
    }
  }

  /// Replaces what is stored for [token] with [items].
  Future<void> write(int token, List<QueuedConduction> items) async {
    try {
      if (items.isEmpty) {
        await _settings.delete(_key(token));
      } else {
        await _settings.put(_key(token), [
          for (final i in items) jsonEncode(i.toJson()),
        ]);
      }
    } catch (e) {
      debugPrint('🟡 Failed to save the conduction queue: $e');
    }
  }

  /// Deletes every member's queue.
  Future<void> clearAll() async {
    final box = _settings;
    final keys = box.keys.where((k) => '$k'.startsWith(_prefix)).toList();
    await box.deleteAll(keys);
  }
}
