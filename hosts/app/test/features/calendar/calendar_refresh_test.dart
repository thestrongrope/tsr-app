import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:the_strong_rope/core/providers/connectivity_provider.dart';
import 'package:the_strong_rope/core/providers/permissions_provider.dart';
import 'package:the_strong_rope/features/calendar/calendar_provider.dart';
import 'package:the_strong_rope/features/calendar/calendar_repository.dart';
import 'package:the_strong_rope/features/home/providers/recent_actions_provider.dart';
import 'calendar_test.dart' show payload;
import 'package:the_strong_rope/features/calendar/calendar_models.dart';

class _Offline extends OfflineNotifier {
  @override
  bool build() => false;
  void change(bool offline) => state = offline;
}

class _UnusedBox implements Box {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends CalendarRepository {
  _Repository() : super(owner: 1, box: _UnusedBox());
  int fetched = 0;
  bool failing = false;
  Completer<StudentCalendar>? pending;
  @override
  Future<void> initialize() async {}
  @override
  StudentCalendar get current => StudentCalendar(payload(events: []));
  @override
  Future<StudentCalendar> refresh() async {
    fetched++;
    if (failing) throw StateError('server said no');
    return pending == null ? current : await pending!.future;
  }
}

void main() {
  testWidgets(
    'open, resume after six hours, reconnect and periodic maximum refresh',
    (tester) async {
      var now = DateTime.utc(2027, 3, 12);
      final repository = _Repository();
      final offline = _Offline();
      final container = ProviderContainer(
        overrides: [
          recentActionsMemberProvider.overrideWithValue(1),
          isOfflineProvider.overrideWith(() => offline),
          calendarClockProvider.overrideWithValue(() => now),
          calendarRepositoryFactoryProvider.overrideWithValue(
            (owner) => repository,
          ),
        ],
      );
      container.listen(calendarProvider, (_, next) {});
      await tester.pump();
      expect(repository.fetched, 1);
      now = now.add(const Duration(hours: 6));
      PermissionsNotifier.resumeEvents.add(null);
      await tester.pump();
      expect(repository.fetched, 2);
      offline.change(true);
      offline.change(false);
      await tester.pump();
      expect(repository.fetched, 3);
      await tester.pump(const Duration(hours: 6));
      expect(repository.fetched, 4);
      container.dispose();
    },
  );
  testWidgets('a failed refresh keeps the saved calendar on screen', (
    tester,
  ) async {
    final repository = _Repository()..failing = true;
    final container = ProviderContainer(
      overrides: [
        recentActionsMemberProvider.overrideWithValue(1),
        isOfflineProvider.overrideWith(_Offline.new),
        calendarRepositoryFactoryProvider.overrideWithValue(
          (owner) => repository,
        ),
      ],
    );
    container.listen(calendarProvider, (_, next) {});
    await tester.pump();
    expect(repository.fetched, 1);
    expect(container.read(calendarProvider).hasError, isFalse);
    expect(container.read(calendarProvider).value, isNotNull);
    container.dispose();
  });
  testWidgets('disposing during refresh ignores the late response', (
    tester,
  ) async {
    final repository = _Repository()..pending = Completer<StudentCalendar>();
    final container = ProviderContainer(
      overrides: [
        recentActionsMemberProvider.overrideWithValue(1),
        isOfflineProvider.overrideWith(_Offline.new),
        calendarRepositoryFactoryProvider.overrideWithValue(
          (owner) => repository,
        ),
      ],
    );
    container.listen(calendarProvider, (_, next) {});
    await tester.pump();
    expect(repository.fetched, 1);
    container.dispose();
    repository.pending!.complete(repository.current);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
