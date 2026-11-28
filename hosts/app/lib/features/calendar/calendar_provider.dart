import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/permissions_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/scheduled_notification_service.dart';
import '../home/providers/recent_actions_provider.dart';
import 'calendar_models.dart';
import 'calendar_repository.dart';

final calendarRepositoryFactoryProvider =
    Provider<CalendarRepository Function(int)>(
      (ref) =>
          (owner) => CalendarRepository(owner: owner),
    );
final calendarClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final calendarProvider =
    NotifierProvider<CalendarNotifier, AsyncValue<StudentCalendar?>>(
      CalendarNotifier.new,
    );
final calendarAlarmNoticeProvider = NotifierProvider<CalendarAlarmNotice, int>(
  CalendarAlarmNotice.new,
);

class CalendarAlarmNotice extends Notifier<int> {
  @override
  int build() => 0;
  void setCount(int value) => state = value;
}

final notificationsAllowedProvider = FutureProvider<bool>(
  (ref) => NotificationService().areNotificationsEnabled(),
);

class CalendarNotifier extends Notifier<AsyncValue<StudentCalendar?>> {
  CalendarRepository? _repository;
  DateTime? _lastRefresh;
  bool _refreshing = false;
  bool _refreshQueued = false;
  int _generation = 0;

  @override
  AsyncValue<StudentCalendar?> build() {
    final owner = ref.watch(recentActionsMemberProvider);
    final generation = ++_generation;
    _refreshing = false;
    _refreshQueued = false;
    _repository = owner == null
        ? null
        : ref.read(calendarRepositoryFactoryProvider)(owner);
    _lastRefresh = null;
    ref.onDispose(() {
      if (_generation == generation) _generation++;
    });
    void updateDropped() => ref
        .read(calendarAlarmNoticeProvider.notifier)
        .setCount(ScheduledNotificationService.instance.eventDropped.value);
    ScheduledNotificationService.instance.eventDropped.addListener(
      updateDropped,
    );
    ref.onDispose(
      () => ScheduledNotificationService.instance.eventDropped.removeListener(
        updateDropped,
      ),
    );
    ref.listen(isOfflineProvider, (_, offline) {
      if (!offline) refresh();
    });
    final resumeSubscription = PermissionsNotifier.resumeEvents.stream.listen(
      (_) => resume(),
    );
    ref.onDispose(resumeSubscription.cancel);
    final timer = Timer.periodic(const Duration(hours: 6), (_) => refresh());
    ref.onDispose(timer.cancel);
    final repository = _repository;
    Future.microtask(() async {
      if (generation != _generation) return;
      if (repository == null) {
        await ScheduledNotificationService.instance.cancelEvents();
        return;
      }
      try {
        await repository.initialize();
        if (generation != _generation) return;
        state = AsyncData(repository.current);
        await refresh();
      } catch (error, stack) {
        if (generation == _generation) state = AsyncError(error, stack);
      }
    });
    return owner == null ? const AsyncData(null) : const AsyncLoading();
  }

  Future<void> resume() async {
    ref.invalidate(notificationsAllowedProvider);
    if (_lastRefresh == null ||
        ref.read(calendarClockProvider)().difference(_lastRefresh!) >=
            const Duration(hours: 6)) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null) return;
    if (_refreshing) {
      // A change made while a refresh is in flight still has to be uploaded.
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    final generation = _generation;
    try {
      final calendar = await repository.refresh();
      if (generation != _generation) return;
      state = AsyncData(calendar);
      _lastRefresh = ref.read(calendarClockProvider)();
      await _arm(calendar);
    } catch (error, stack) {
      if (generation == _generation) {
        // A failed refresh must not hide a saved calendar whose alarms are
        // still armed on this phone.
        final saved = repository.current;
        state = saved == null ? AsyncError(error, stack) : AsyncData(saved);
      }
    } finally {
      if (generation == _generation) _refreshing = false;
    }
    if (_refreshQueued && generation == _generation) {
      _refreshQueued = false;
      await refresh();
    }
  }

  Future<void> _arm(StudentCalendar calendar) async {
    final generation = _generation;
    final dropped = await ScheduledNotificationService.instance.scheduleEvents(
      calendar,
    );
    if (generation == _generation) {
      ref.read(calendarAlarmNoticeProvider.notifier).setCount(dropped);
    }
  }

  Future<void> change(
    CalendarEvent event,
    EventSetting setting, {
    bool deleting = false,
  }) async {
    final repository = _repository;
    if (repository == null) return;
    final generation = _generation;
    await repository.change(event.key, setting, holdDelete: deleting);
    if (generation != _generation) return;
    state = AsyncData(repository.current);
    await _arm(repository.current!);
    if (deleting) {
      final timer = Timer(const Duration(seconds: 10), () {
        if (generation == _generation) refresh();
      });
      ref.onDispose(timer.cancel);
    } else {
      await refresh();
    }
  }

  Future<void> undo(String key) async {
    final repository = _repository;
    final generation = _generation;
    if (repository == null || !await repository.undo(key)) return;
    if (generation != _generation) return;
    state = AsyncData(repository.current);
    await _arm(repository.current!);
  }
}
