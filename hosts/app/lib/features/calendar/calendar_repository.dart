import 'dart:convert';
import 'dart:math';
import 'package:hive_ce/hive.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/saved_copy.dart';
import 'calendar_models.dart';

typedef CalendarRead = Future<Map<String, Object?>> Function();
typedef CalendarWrite =
    Future<Map<String, Object?>> Function(Map<String, Object?>);

class CalendarRepository {
  CalendarRepository({
    required this.owner,
    Box? box,
    CalendarRead? fetch,
    CalendarWrite? upload,
    DateTime Function()? clock,
    bool Function()? isCurrentOwner,
  }) : box = box ?? Hive.box(AppConstants.cacheBoxKey),
       fetch =
           fetch ??
           (() => ApiClient().get<Map<String, Object?>>('/me/calendar')),
       upload =
           upload ??
           ((body) => ApiClient().put<Map<String, Object?>>(
             '/me/calendar/settings',
             data: body,
           )),
       clock = clock ?? DateTime.now,
       isCurrentOwner = isCurrentOwner ?? (() => signedInToken() == owner);
  final int owner;
  final Box box;
  final CalendarRead fetch;
  final CalendarWrite upload;
  final DateTime Function() clock;
  final bool Function() isCurrentOwner;
  String get _cacheKey => 'calendar:$owner';
  String get _pendingKey => 'calendar_outbox:$owner';
  SavedCopies get _copies => SavedCopies(
    box,
    owner: () => isCurrentOwner() ? owner : null,
    maxAge: null,
  );
  Map<String, Object?> _pending = {};
  Map<String, Object?>? _calendar;

  Future<void> initialize() async {
    final cached = _copies.read(_cacheKey);
    if (cached is String) _calendar = calendarMap(jsonDecode(cached));
    final pending = _copies.read(_pendingKey);
    if (pending is String) _pending = calendarMap(jsonDecode(pending));
    // An app killed during Undo commits the held deletion on next start.
    for (final key in _pending.keys.toList()) {
      final value = calendarMap(_pending[key]);
      value.remove('hold_until');
      _pending[key] = value;
    }
    await _savePending();
  }

  StudentCalendar? get current {
    if (!isCurrentOwner()) return null;
    final saved = _calendar;
    if (saved == null) return null;
    final settings = calendarMap(saved['settings'] ?? <String, Object?>{});
    for (final key in _pending.keys) {
      settings[key] = calendarMap(_pending[key]);
    }
    return StudentCalendar({...saved, 'settings': settings});
  }

  String get deviceKey {
    final saved = box.get('calendar_install_key');
    if (saved is String) return saved;
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> _savePending() =>
      _copies.save(_pendingKey, jsonEncode(_pending));

  Future<void> change(
    String key,
    EventSetting setting, {
    bool holdDelete = false,
  }) async {
    if (!eventOffsets.contains(setting.offset)) {
      throw ArgumentError('Unsupported offset');
    }
    final existing = current?.setting(key);
    if (existing?.deleted == true) throw StateError('This event was deleted');
    if (!isCurrentOwner()) throw StateError('Calendar member changed');
    final now = DateTime.fromMillisecondsSinceEpoch(
      clock().millisecondsSinceEpoch,
      isUtc: true,
    );
    _pending[key] = <String, Object?>{
      'event_key': key,
      'offset_minutes': setting.offset,
      'muted': setting.muted,
      'deleted': setting.deleted,
      'client_updated_at': now.toIso8601String(),
      if (holdDelete)
        'hold_until': now.add(const Duration(seconds: 10)).toIso8601String(),
      if (holdDelete) 'previous': _pending[key],
    };
    await _savePending();
  }

  Future<bool> undo(String key) async {
    final raw = _pending[key];
    if (raw == null) return false;
    final value = calendarMap(raw);
    final until = DateTime.tryParse(value['hold_until'] as String? ?? '');
    if (until == null || !clock().isBefore(until)) return false;
    final previous = value['previous'];
    if (previous == null) {
      _pending.remove(key);
    } else {
      _pending[key] = previous;
    }
    await _savePending();
    return true;
  }

  Future<StudentCalendar> refresh() async {
    try {
      final fresh = await fetch();
      if (!isCurrentOwner()) throw StateError('Calendar member changed');
      _calendar = fresh;
      // Drop changes for a class/slot removed while this phone was offline.
      final available = StudentCalendar(fresh).events.map((e) => e.key).toSet();
      final canonical = calendarMap(fresh['settings'] ?? <String, Object?>{});
      _pending.removeWhere((key, _) => !available.contains(key));
      final ready = <String, Object?>{};
      for (final key in _pending.keys) {
        final value = calendarMap(_pending[key]);
        final hold = DateTime.tryParse(value['hold_until'] as String? ?? '');
        if (hold == null || !clock().isBefore(hold)) ready[key] = value;
      }
      final keys = ready.keys.toList();
      final device = deviceKey;
      await box.put('calendar_install_key', device);
      for (var start = 0; start < keys.length; start += 200) {
        final batch = keys.skip(start).take(200).toList();
        final Map<String, Object?> response;
        try {
          response = await upload({
            'device_key': device,
            'changes': batch.map((key) {
              final value = calendarMap(ready[key]);
              return {...value}
                ..remove('hold_until')
                ..remove('previous');
            }).toList(),
          });
        } catch (error) {
          if (!_refused(error)) rethrow;
          // A retry would be refused again, and would block every later
          // refresh: drop the changes and keep what the server holds.
          batch.forEach(_pending.remove);
          await _savePending();
          continue;
        }
        if (!isCurrentOwner()) throw StateError('Calendar member changed');
        canonical.addAll(calendarMap(response['settings']));
        for (final key in batch) {
          if (identical(_pending[key], ready[key]) ||
              jsonEncode(_pending[key]) == jsonEncode(ready[key])) {
            _pending.remove(key);
          }
        }
        _calendar = {...fresh, 'settings': canonical};
        await _copies.save(_cacheKey, jsonEncode(_calendar));
        await _savePending();
      }
      _calendar = {...fresh, 'settings': canonical};
      await _copies.save(_cacheKey, jsonEncode(_calendar));
      await _savePending();
      return current!;
    } catch (error) {
      if (!isUnreachable(error) || current == null) rethrow;
      return current!;
    }
  }

  /// The server answered and said no to the change itself (not to the
  /// sign-in, and not "slow down").
  static bool _refused(Object error) =>
      error is ApiException &&
      !isUnreachable(error) &&
      error.statusCode != 401 &&
      error.statusCode != 429;

  static Future<void> clearAll() async {
    final box = Hive.box(AppConstants.cacheBoxKey);
    await box.deleteAll(
      box.keys
          .where(
            (key) =>
                '$key'.startsWith('calendar:') ||
                '$key'.startsWith('calendar_outbox:'),
          )
          .toList(),
    );
  }
}
