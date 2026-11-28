import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../constants/app_constants.dart';

class SyllabusCacheService {
  static const _prefix = 'syllabus:';
  static const defaultTtlMillis = 24 * 60 * 60 * 1000; // 24h

  Future<Map<String, dynamic>?> getCached(
    int classId, {
    int ttlMillis = defaultTtlMillis,
  }) async {
    final box = Hive.box(AppConstants.cacheBoxKey);
    final key = '$_prefix$classId';
    final data = box.get(key);
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final updatedAt = map['updatedAt'] as int?;
      if (updatedAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - updatedAt <= ttlMillis) {
          // Hive returns nested maps as Map<dynamic, dynamic>, which is not a
          // subtype of Map<String, dynamic> — convert instead of casting.
          final payload = map['payload'];
          if (payload is Map) {
            return Map<String, dynamic>.from(payload);
          }
        }
      }
    }
    return null;
  }

  Future<void> save(int classId, Map<String, dynamic> payload) async {
    final box = Hive.box(AppConstants.cacheBoxKey);
    final key = '$_prefix$classId';
    await box.put(key, {
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    });
  }

  Future<void> clear(int classId) async {
    final box = Hive.box(AppConstants.cacheBoxKey);
    await box.delete('$_prefix$classId');
  }
}
