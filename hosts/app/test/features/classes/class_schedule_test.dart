import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/class_manage.dart';
import 'package:the_strong_rope/features/classes/providers/class_schedule_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_manage_repository.dart';

class _FakeRepository extends ClassManageRepository {
  List<ManageSchedule> stored;
  List<List<ManageSchedule>> saved = [];
  bool failSave = false;

  _FakeRepository(this.stored);

  @override
  Future<ClassScheduleData> getSchedule(int classId) async => ClassScheduleData(
    schedules: stored,
    timezones: const [
      ManageTimezone(timezone: 'Asia/Kolkata', label: 'Kolkata'),
    ],
  );

  @override
  Future<ClassScheduleData> saveSchedule(
    int classId,
    List<ManageSchedule> schedules,
  ) async {
    if (failSave) throw Exception('nope');
    saved.add(schedules);
    stored = schedules;
    return getSchedule(classId);
  }
}

void main() {
  const saturday = ManageSchedule(
    id: 1,
    day: 6,
    hour: 20,
    minute: 30,
    timezone: 'Asia/Kolkata',
  );

  Future<ClassScheduleNotifier> loaded(
    _FakeRepository repo, {
    void Function()? onChanged,
  }) async {
    final notifier = ClassScheduleNotifier(4, repo, onChanged ?? () {});
    await Future<void>.delayed(Duration.zero);
    return notifier;
  }

  test('loads the schedule and is clean until edited', () async {
    final notifier = await loaded(_FakeRepository([saturday]));

    expect(notifier.state.draft, [saturday]);
    expect(notifier.state.isDirty, isFalse);

    notifier.edit([saturday.copyWith(hour: 19)]);
    expect(notifier.state.isDirty, isTrue);
  });

  test(
    'save sends the edit, then is clean and refreshes the class list',
    () async {
      final repo = _FakeRepository([
        saturday.copyWith(topics: const [ManageTopic(id: 5, topicId: 1)]),
      ]);
      var refreshed = 0;
      final notifier = await loaded(repo, onChanged: () => refreshed++);

      notifier.edit([notifier.state.draft.first.copyWith(minute: 0)]);
      await notifier.save();

      expect(repo.saved.single.single.minute, 0);
      expect(notifier.state.isDirty, isFalse);
      expect(refreshed, 1);
    },
  );

  test(
    'a failed save keeps the edits and does not refresh the class list',
    () async {
      final repo = _FakeRepository([saturday])..failSave = true;
      var refreshed = 0;
      final notifier = await loaded(repo, onChanged: () => refreshed++);

      notifier.edit([saturday.copyWith(day: 1)]);
      await expectLater(notifier.save(), throwsException);

      expect(notifier.state.isSaving, isFalse);
      expect(notifier.state.isDirty, isTrue);
      expect(refreshed, 0);
    },
  );
}
