import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/permissions/capabilities.dart';
import 'package:the_strong_rope/core/models/permissions_payload.dart';
import 'package:the_strong_rope/core/services/scheduled_notification_service.dart';
import 'package:the_strong_rope/features/classes/models/class_model.dart';
import 'package:the_strong_rope/features/classes/models/class_schedule.dart';
import 'package:the_strong_rope/features/classes/providers/classes_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Records what `rescheduleAll` asks the platform plugin to schedule.
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  final scheduledIds = <int>[];

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [];

  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #zonedSchedule) {
      scheduledIds.add(invocation.positionalArguments[0] as int);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

// Mirrors the service's id layout: 100000 + classId * 1000 + index * 10 + type.
int _classReminderId(int classId) => 100000 + classId * 1000;
int _conductionReminderId(int classId) => 100000 + classId * 1000 + 1;

ClassModel _class(int id, {int gender = 1, String? role}) => ClassModel(
  id: id,
  code: 'C$id',
  name: 'Class $id',
  level: 1,
  gender: gender,
  status: 'A',
  role: role,
  schedules: const [
    ClassSchedule(day: 3, hour: 19, minute: 0, timezone: 'Asia/Kolkata'),
  ],
);

PermissionsPayload _held(
  List<String> permissions, {
  PermissionScopes scopes = const PermissionScopes(),
}) => PermissionsPayload(
  version: 4,
  permissions: permissions,
  scopes: scopes,
  issuedAt: '',
);

Capabilities _capabilities(PermissionsPayload? permissions) =>
    Capabilities.of(payload: permissions, classes: null);

void main() {
  late _RecordingPlugin plugin;

  setUpAll(tzdata.initializeTimeZones);

  setUp(() async {
    plugin = _RecordingPlugin();
    await ScheduledNotificationService.instance.initialize(plugin);
  });

  /// Runs rescheduleAll the way ClassesNotifier does, with both reminders on.
  Future<List<int>> schedule(
    PermissionsPayload? permissions,
    List<ClassModel> classes,
  ) async {
    await ScheduledNotificationService.instance.rescheduleAll(
      classes: classes,
      classReminderEnabled: true,
      conductionReminderEnabled: true,
      remindsConduction: (cls) => remindsConductionFor(_capabilities(permissions), cls),
    );
    return plugin.scheduledIds;
  }

  test(
    'a student gets the class reminder and no conduction reminder',
    () async {
      final ids = await schedule(
        _held([
          'classes:read:enrolled',
        ], scopes: const PermissionScopes(enrolled: [10])),
        [_class(10, role: 'attending')],
      );
      expect(ids, [_classReminderId(10)]);
    },
  );

  test('no permissions yet: no conduction reminder', () async {
    final ids = await schedule(null, [_class(10, role: 'conducting')]);
    expect(ids, [_classReminderId(10)]);
  });

  test('the class teacher gets a conduction reminder', () async {
    final ids = await schedule(
      _held([
        'sessions:create:own',
      ], scopes: const PermissionScopes(own: [10], taught: [10])),
      [_class(10, role: 'conducting')],
    );
    expect(ids, containsAll([_classReminderId(10), _conductionReminderId(10)]));
    expect(ids.length, 2);
  });

  test(
    'rescheduleAll reports how many of each reminder it scheduled',
    () async {
      final permissions = _held([
        'sessions:create:own',
      ], scopes: const PermissionScopes(own: [10], taught: [10]));
      final counts = await ScheduledNotificationService.instance.rescheduleAll(
        classes: [
          _class(10, role: 'conducting'),
          _class(11, role: 'attending'),
        ],
        classReminderEnabled: true,
        conductionReminderEnabled: true,
        remindsConduction: (cls) => remindsConductionFor(_capabilities(permissions), cls),
      );
      expect(counts.classReminders, 2);
      expect(counts.conductionReminders, 1);
    },
  );

  test('a teacher gets none for a class they only attend', () async {
    final ids = await schedule(
      _held([
        'sessions:create:own',
      ], scopes: const PermissionScopes(own: [10], taught: [10])),
      [_class(10, role: 'conducting'), _class(11, role: 'attending')],
    );
    expect(ids, contains(_conductionReminderId(10)));
    expect(ids, isNot(contains(_conductionReminderId(11))));
  });

  test('an MCQ admin gets the tile permission but no reminder', () async {
    final permissions = _held([
      'sessions:create:own',
      'mcqs:manage:own',
    ], scopes: const PermissionScopes(own: [10], taught: []));
    final cls = _class(10, role: 'attending');
    expect(
      permissions.can('sessions:create', classId: 10, classGender: 1),
      isTrue,
    );

    final ids = await schedule(permissions, [cls]);
    expect(ids, [_classReminderId(10)]);
  });

  test(
    'a coordinator gets no conduction reminders for managed classes',
    () async {
      final ids = await schedule(
        _held([
          'sessions:create:assigned',
        ], scopes: const PermissionScopes(assigned: [10])),
        [_class(10, role: 'managing'), _class(11, role: 'managing')],
      );
      expect(ids, isNot(contains(_conductionReminderId(10))));
      expect(ids, isNot(contains(_conductionReminderId(11))));
    },
  );

  test(
    'a gender admin gets no conduction reminders for managed classes',
    () async {
      final ids = await schedule(
        _held([
          'sessions:create:gender',
        ], scopes: const PermissionScopes(gender: 2)),
        [
          _class(20, gender: 2, role: 'managing'),
          _class(10, gender: 1, role: 'managing'),
        ],
      );
      expect(ids, isNot(contains(_conductionReminderId(20))));
      expect(ids, isNot(contains(_conductionReminderId(10))));
    },
  );

  test('a super admin attending a class gets no conduction reminder', () async {
    final ids = await schedule(_held(['sessions:create:all']), [
      _class(10, role: 'attending'),
    ]);
    expect(ids, [_classReminderId(10)]);
  });

  test('a managed class gets no class-start reminder', () async {
    final ids = await schedule(
      _held([
        'sessions:create:assigned',
        'sessions:create:all',
      ], scopes: const PermissionScopes(assigned: [10])),
      [
        _class(10, role: 'managing'),
        _class(11, role: 'managing'),
        _class(12, role: 'attending'),
      ],
    );
    expect(ids, isNot(contains(_classReminderId(10))));
    expect(ids, isNot(contains(_classReminderId(11))));
    expect(ids, contains(_classReminderId(12)));
    // Managing a class brings no conduction reminder either.
    expect(ids, isNot(contains(_conductionReminderId(10))));
    expect(ids, isNot(contains(_conductionReminderId(11))));
  });

  test('conduction reminders off: none, even for the teacher', () async {
    await ScheduledNotificationService.instance.rescheduleAll(
      classes: [_class(10, role: 'conducting')],
      classReminderEnabled: true,
      conductionReminderEnabled: false,
      remindsConduction: (_) => true,
    );
    expect(plugin.scheduledIds, [_classReminderId(10)]);
  });
}
