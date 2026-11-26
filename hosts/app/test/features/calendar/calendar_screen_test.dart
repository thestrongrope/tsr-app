import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/calendar/calendar_models.dart';
import 'package:the_strong_rope/features/calendar/calendar_provider.dart';
import 'package:the_strong_rope/features/calendar/calendar_screen.dart';
import 'package:the_strong_rope/features/calendar/class_events_screen.dart';
import 'package:the_strong_rope/features/classes/providers/class_scheduled_notifications_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'calendar_test.dart' show payload, event;

class _Calendar extends CalendarNotifier {
  EventSetting? last;
  bool undone = false;
  @override
  AsyncValue<StudentCalendar?> build() => AsyncData(StudentCalendar(payload()));
  @override
  Future<void> refresh() async {}
  @override
  Future<void> change(
    CalendarEvent event,
    EventSetting setting, {
    bool deleting = false,
  }) async {
    last = setting;
    state = AsyncData(
      StudentCalendar(
        payload(
          settings: {
            event.key: {
              'offset_minutes': setting.offset,
              'muted': setting.muted,
              'deleted': setting.deleted,
            },
          },
        ),
      ),
    );
  }

  @override
  Future<void> undo(String key) async {
    undone = true;
    state = AsyncData(StudentCalendar(payload()));
  }
}

class _Cap extends CalendarAlarmNotice {
  @override
  int build() => 2;
}

class _Events extends ClassEventsRepository {
  Map<String, Object?>? saved;
  String? savedKey;
  List<CalendarEvent> items = [];
  @override
  Future<List<CalendarEvent>> list(int classId) async => items;
  @override
  Future<void> save(
    int classId,
    Map<String, Object?> input,
    String? key,
  ) async {
    saved = input;
    savedKey = key;
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);
  testWidgets(
    'student sees details, link, blocked notice, cap and all alert choices',
    (tester) async {
      final notifier = _Calendar();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarProvider.overrideWith(() => notifier),
            notificationsAllowedProvider.overrideWith((ref) async => false),
            calendarAlarmNoticeProvider.overrideWith(_Cap.new),
          ],
          child: const MaterialApp(home: CalendarScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lesson'), findsOneWidget);
      expect(find.text('Read chapter two'), findsOneWidget);
      expect(find.text('/classes/7/dashboard'), findsOneWidget);
      expect(find.textContaining('Notifications are blocked'), findsOneWidget);
      expect(find.textContaining('Alerts for 2 events'), findsOneWidget);
      for (final offset in eventOffsets) {
        await tester.ensureVisible(find.byType(DropdownButton<int>));
        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(offsetLabel(offset)).last);
        await tester.pumpAndSettle();
        expect(notifier.last!.offset, offset);
        expect(notifier.last!.muted, isFalse);
      }
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Off').last);
      await tester.pumpAndSettle();
      expect(notifier.last!.muted, isTrue);
      await tester.ensureVisible(find.text('Delete for me'));
      await tester.tap(find.text('Delete for me'));
      await tester.pumpAndSettle();
      expect(find.text('No class events'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(notifier.undone, isTrue);
      expect(find.text('Lesson'), findsOneWidget);
    },
  );

  testWidgets(
    'event form refuses missing weekdays and bad time then saves zone',
    (tester) async {
      final repository = _Events();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            classEventsRepositoryProvider.overrideWithValue(repository),
            deviceTimezoneProvider.overrideWith((ref) async => 'Asia/Kolkata'),
          ],
          child: const MaterialApp(home: EventFormScreen(classId: 7)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Prepare lesson',
      );
      await tester.ensureVisible(find.text('Save event'));
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();
      expect(find.text('Choose at least one weekday'), findsOneWidget);
      await tester.tap(find.text('Mon'));
      await tester.enterText(find.byType(TextFormField).at(3), '25:00');
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid time (HH:MM)'), findsOneWidget);
      expect(repository.saved, isNull);
      await tester.enterText(find.byType(TextFormField).at(3), '18:30');
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();
      expect(repository.saved!['timezone'], 'Asia/Kolkata');
      expect(repository.saved!['weekdays'], [1]);
    },
  );

  testWidgets('non-owner has no edit control; eligible takeover is visible', (
    tester,
  ) async {
    final repository = _Events()
      ..items = [
        CalendarEvent(event()),
        CalendarEvent(
          event(key: 'event:2')..addAll({
            'message': 'Orphaned event',
            'editable_by_me': true,
            'takeover': true,
          }),
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classEventsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ClassEventsScreen(classId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Take over'), findsOneWidget);
    expect(find.byTooltip('Delete event'), findsOneWidget);
  });

  testWidgets('owner edits message without replacing the stored zone', (
    tester,
  ) async {
    final repository = _Events();
    final owned = CalendarEvent(event()..['editable_by_me'] = true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classEventsRepositoryProvider.overrideWithValue(repository),
          deviceTimezoneProvider.overrideWith((ref) async => 'Asia/Kolkata'),
        ],
        child: MaterialApp(home: EventFormScreen(classId: 7, event: owned)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('America/New_York'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Updated lesson');
    await tester.ensureVisible(find.text('Save event'));
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    expect(repository.savedKey, 'event:1');
    expect(repository.saved!['message'], 'Updated lesson');
    expect(repository.saved!.containsKey('timezone'), isFalse);
  });

  testWidgets('invalid device zone refuses create', (tester) async {
    final repository = _Events();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classEventsRepositoryProvider.overrideWithValue(repository),
          deviceTimezoneProvider.overrideWith((ref) async => 'Moon/Base'),
        ],
        child: const MaterialApp(home: EventFormScreen(classId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Lesson');
    await tester.tap(find.text('Mon'));
    await tester.ensureVisible(find.text('Save event'));
    await tester.tap(find.text('Save event'));
    await tester.pumpAndSettle();
    expect(repository.saved, isNull);
    expect(find.text('This phone has no valid time zone'), findsOneWidget);
  });
}
