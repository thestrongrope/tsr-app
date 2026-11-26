import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/class_manage.dart';
import 'package:the_strong_rope/features/classes/providers/class_manage_provider.dart';
import 'package:the_strong_rope/features/classes/repositories/class_manage_repository.dart';

Map<String, dynamic> _payload({bool canTransfer = false}) => {
  'class': {
    'id': 27,
    'code': 'AY-7',
    'name': 'Sulsi',
    'levelId': 4,
    'levelName': 'AMMAR',
    'gender': 1,
    'genderName': 'Male',
    'languageId': 1,
    'startedOn': null,
    'format': 'Offline',
    'address': null,
    'city': 'New Delhi',
    'country': 'India',
    'location': '',
    'teacher': 12757,
    'teacherName': 'A Teacher',
    'joinUrl': null,
  },
  'tags': [
    {'id': 1, 'name': 'Mumbra'},
  ],
  'schedules': [
    {
      'id': 387,
      'day': 6,
      'hour': 19,
      'minute': 0,
      'timezone': 'Asia/Kolkata',
      'topics': [
        {'id': 5, 'topicId': 1},
      ],
    },
  ],
  'lookups': {
    'languages': [
      {'id': 1, 'name': 'English'},
    ],
    'tags': [
      {'id': 1, 'name': 'Mumbra'},
    ],
    'topics': [
      {'id': 1, 'name': 'Quran'},
    ],
    'timezones': [
      {'timezone': 'Asia/Kolkata', 'label': '(UTC+05:30) Kolkata'},
    ],
  },
  'can': {
    'update': true,
    'enrol': true,
    'setClassAdmin': false,
    'transfer': canTransfer,
  },
  'students': [
    {
      'token': 21410,
      'name': 'A Student',
      'email': 'a@example.invalid',
      'mobile': null,
      'joinedOn': '2026-10-03',
      'notes': null,
      'mcqAdmin': false,
    },
  ],
  'removedStudents': <dynamic>[],
  'mcqStudents': [
    {'token': 3108, 'name': 'A Quiz Taker', 'email': null, 'mobile': ''},
  ],
  'transferHistory': canTransfer ? <dynamic>[] : null,
  'destinations': canTransfer
      ? [
          {'id': 132, 'code': 'AY-9', 'name': 'Other'},
        ]
      : null,
};

class _FakeRepository extends ClassManageRepository {
  ClassDraft? saved;
  ManageRoster? nextRoster;

  @override
  Future<ClassManagePayload> getManage(int classId) async =>
      ClassManagePayload.fromJson(_payload());

  @override
  Future<ClassManagePayload> save(int classId, ClassDraft draft) async {
    saved = draft;
    return ClassManagePayload.fromJson(_payload());
  }

  int? added;

  @override
  Future<ManageRoster> addStudent(int classId, int token) async {
    added = token;
    return nextRoster!;
  }

  @override
  Future<ManageRoster> removeStudent(
    int classId,
    int token,
    String reason,
  ) async => nextRoster!;
}

void main() {
  group('ClassManagePayload.fromJson', () {
    test('reads the class, schedule topics, lookups and rosters', () {
      final p = ClassManagePayload.fromJson(_payload());
      expect(p.classInfo.name, 'Sulsi');
      expect(p.classInfo.location, isNull, reason: 'blank text is no value');
      expect(p.schedules.single.topics.single.id, 5);
      expect(p.lookups.timezones.single.timezone, 'Asia/Kolkata');
      expect(p.roster.students.single.email, 'a@example.invalid');
      expect(p.can.update, isTrue);
      expect(p.can.transfer, isFalse);
    });

    test('quiz takers who are not enrolled parse as people to add', () {
      final p = ClassManagePayload.fromJson(_payload());
      expect(p.roster.mcqStudents.single.token, 3108);
      expect(p.roster.mcqStudents.single.mobile, isNull);
    });

    test('a payload without the transfer parts parses to empty lists', () {
      final p = ClassManagePayload.fromJson(_payload());
      expect(p.destinations, isEmpty);
      expect(p.roster.transferHistory, isEmpty);
    });

    test('destinations appear when the caller may transfer', () {
      final p = ClassManagePayload.fromJson(_payload(canTransfer: true));
      expect(p.destinations.single.code, 'AY-9');
    });
  });

  group('ClassDraft', () {
    test(
      'sends the full schedule list, with topic ids, as the server expects',
      () {
        final p = ClassManagePayload.fromJson(_payload());
        final json = ClassDraft.from(p).toJson();
        expect(json['teacher'], 12757);
        expect(json['tags'], [1]);
        final schedule = (json['schedules'] as List).single as Map;
        expect(schedule['id'], 387);
        expect((schedule['topics'] as List).single, {'id': 5, 'topicId': 1});
      },
    );
  });

  group('ClassManageNotifier', () {
    test('an edit makes the draft dirty and discarding restores it', () async {
      final notifier = ClassManageNotifier(27, _FakeRepository(), () {});
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isDirty, isFalse);

      notifier.editDraft((d) => d.copyWith(city: 'Pune'));
      expect(notifier.state.isDirty, isTrue);

      notifier.discardEdits();
      expect(notifier.state.isDirty, isFalse);
    });

    test(
      'saving sends the draft and tells the class list to refresh',
      () async {
        final repository = _FakeRepository();
        var refreshed = 0;
        final notifier = ClassManageNotifier(27, repository, () => refreshed++);
        await Future<void>.delayed(Duration.zero);

        notifier.editDraft((d) => d.copyWith(city: 'Pune'));
        await notifier.save();

        expect(repository.saved!.city, 'Pune');
        expect(refreshed, 1, reason: 'reminders follow the new schedule');
        expect(notifier.state.isDirty, isFalse);
      },
    );

    test(
      'adding a quiz taker enrols them and drops them from the list',
      () async {
        final repository = _FakeRepository()
          ..nextRoster = const ManageRoster(
            students: [ManagedStudent(token: 3108, name: 'A Quiz Taker')],
          );
        final notifier = ClassManageNotifier(27, repository, () {});
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.payload!.roster.mcqStudents, hasLength(1));

        await notifier.addStudent(3108);

        expect(repository.added, 3108);
        expect(notifier.state.payload!.roster.students.single.token, 3108);
        expect(notifier.state.payload!.roster.mcqStudents, isEmpty);
      },
    );

    test(
      'a student action replaces the roster and leaves unsaved edits',
      () async {
        final repository = _FakeRepository()
          ..nextRoster = const ManageRoster(
            removedStudents: [RemovedStudent(token: 21410, name: 'A Student')],
          );
        final notifier = ClassManageNotifier(27, repository, () {});
        await Future<void>.delayed(Duration.zero);
        notifier.editDraft((d) => d.copyWith(city: 'Pune'));

        await notifier.removeStudent(21410, 'left');

        expect(notifier.state.payload!.roster.students, isEmpty);
        expect(notifier.state.payload!.roster.removedStudents, hasLength(1));
        expect(notifier.state.draft!.city, 'Pune');
      },
    );
  });
}
