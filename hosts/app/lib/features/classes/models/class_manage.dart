import 'package:freezed_annotation/freezed_annotation.dart';

import '../../admin/models/enrol_by_token.dart';

part 'class_manage.freezed.dart';

// Models for the manage-a-class screen (#402): the mobile counterpart of the
// web's edit_class.php. They mirror GET /classes/{id}/manage.

String? _text(dynamic value) {
  final s = value as String?;
  return (s == null || s.isEmpty) ? null : s;
}

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  return (value as List<dynamic>? ?? const [])
      .map((e) => parse(e as Map<String, dynamic>))
      .toList();
}

/// An id and a name: a tag, a topic or a language.
@Freezed(fromJson: false, toJson: false)
sealed class ManageOption with _$ManageOption {
  const factory ManageOption({required int id, required String name}) =
      _ManageOption;

  factory ManageOption.fromJson(Map<String, dynamic> json) =>
      ManageOption(id: json['id'] as int, name: json['name'] as String? ?? '');
}

@Freezed(fromJson: false, toJson: false)
sealed class ManageTimezone with _$ManageTimezone {
  const factory ManageTimezone({
    required String timezone,
    required String label,
  }) = _ManageTimezone;

  factory ManageTimezone.fromJson(Map<String, dynamic> json) => ManageTimezone(
    timezone: json['timezone'] as String,
    label: json['label'] as String? ?? json['timezone'] as String,
  );
}

/// The class fields the screen edits, plus the ones it only shows.
@Freezed(fromJson: false, toJson: false)
sealed class ManagedClass with _$ManagedClass {
  const factory ManagedClass({
    required int id,
    required String code,
    required String name,
    required String levelName,
    required int gender,
    required String genderName,
    int? languageId,

    /// `YYYY-MM-DD`, as the API sends and accepts it.
    String? startedOn,
    @Default('Offline') String format,
    String? address,
    String? city,
    String? country,
    String? location,
    required int teacher,
    String? teacherName,
    String? joinUrl,
  }) = _ManagedClass;

  factory ManagedClass.fromJson(Map<String, dynamic> json) => ManagedClass(
    id: json['id'] as int,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    levelName: json['levelName'] as String? ?? '',
    gender: json['gender'] as int? ?? 0,
    genderName: json['genderName'] as String? ?? '',
    languageId: json['languageId'] as int?,
    startedOn: _text(json['startedOn']),
    format: json['format'] as String? ?? 'Offline',
    address: _text(json['address']),
    city: _text(json['city']),
    country: _text(json['country']),
    location: _text(json['location']),
    teacher: json['teacher'] as int? ?? 0,
    teacherName: _text(json['teacherName']),
    joinUrl: _text(json['joinUrl']),
  );
}

/// One topic attached to a schedule slot. [id] is the existing row, null when new.
@Freezed(fromJson: false, toJson: false)
sealed class ManageTopic with _$ManageTopic {
  const ManageTopic._();

  const factory ManageTopic({int? id, required int topicId}) = _ManageTopic;

  factory ManageTopic.fromJson(Map<String, dynamic> json) =>
      ManageTopic(id: json['id'] as int?, topicId: json['topicId'] as int);

  Map<String, dynamic> toJson() => {'id': id, 'topicId': topicId};
}

/// One weekly slot. [id] is null for a slot added on this screen.
@Freezed(fromJson: false, toJson: false)
sealed class ManageSchedule with _$ManageSchedule {
  const ManageSchedule._();

  const factory ManageSchedule({
    int? id,

    /// 1 = Monday ... 7 = Sunday.
    required int day,
    required int hour,
    required int minute,
    required String timezone,
    @Default([]) List<ManageTopic> topics,
  }) = _ManageSchedule;

  factory ManageSchedule.fromJson(Map<String, dynamic> json) => ManageSchedule(
    id: json['id'] as int?,
    day: json['day'] as int,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    timezone: json['timezone'] as String? ?? '',
    topics: _list(json['topics'], ManageTopic.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': day,
    'hour': hour,
    'minute': minute,
    'timezone': timezone,
    'topics': topics.map((t) => t.toJson()).toList(),
  };
}

/// A current student. Email and mobile are real member data: shown to whoever
/// holds the permission, never logged.
@Freezed(fromJson: false, toJson: false)
sealed class ManagedStudent with _$ManagedStudent {
  const factory ManagedStudent({
    required int token,
    required String name,
    String? email,
    String? mobile,
    String? joinedOn,
    String? notes,
    @Default(false) bool mcqAdmin,

    /// No sign-in and no real email: a record a super admin may link to a
    /// member (#1135).
    @Default(false) bool extraStudent,
  }) = _ManagedStudent;

  factory ManagedStudent.fromJson(Map<String, dynamic> json) => ManagedStudent(
    token: json['token'] as int,
    name: json['name'] as String? ?? '',
    email: _text(json['email']),
    mobile: _text(json['mobile']),
    joinedOn: _text(json['joinedOn']),
    notes: _text(json['notes']),
    mcqAdmin: json['mcqAdmin'] == true,
    extraStudent: json['extraStudent'] == true,
  );
}

@Freezed(fromJson: false, toJson: false)
sealed class RemovedStudent with _$RemovedStudent {
  const factory RemovedStudent({
    required int token,
    required String name,
    String? email,
    String? mobile,
    String? removedAt,
    String? removedReason,
    String? removedByName,
  }) = _RemovedStudent;

  factory RemovedStudent.fromJson(Map<String, dynamic> json) => RemovedStudent(
    token: json['token'] as int,
    name: json['name'] as String? ?? '',
    email: _text(json['email']),
    mobile: _text(json['mobile']),
    removedAt: _text(json['removedAt']),
    removedReason: _text(json['removedReason']),
    removedByName: _text(json['removedByName']),
  );
}

/// A member who took the class's quizzes but is not enrolled: someone to add.
@Freezed(fromJson: false, toJson: false)
sealed class AddCandidate with _$AddCandidate {
  const factory AddCandidate({
    required int token,
    required String name,
    String? email,
    String? mobile,
  }) = _AddCandidate;

  factory AddCandidate.fromJson(Map<String, dynamic> json) => AddCandidate(
    token: json['token'] as int,
    name: json['name'] as String? ?? '',
    email: _text(json['email']),
    mobile: _text(json['mobile']),
  );
}

@Freezed(fromJson: false, toJson: false)
sealed class TransferRecord with _$TransferRecord {
  const factory TransferRecord({
    required int studentToken,
    required String studentName,
    required String fromClassCode,
    required String toClassCode,
    required String type,
    String? reason,
    String? transferredBy,
    String? transferredAt,
  }) = _TransferRecord;

  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(
    studentToken: json['studentToken'] as int,
    studentName: json['studentName'] as String? ?? '',
    fromClassCode: json['fromClassCode'] as String? ?? '',
    toClassCode: json['toClassCode'] as String? ?? '',
    type: json['type'] as String? ?? 'transfer',
    reason: _text(json['reason']),
    transferredBy: _text(json['transferredBy']),
    transferredAt: _text(json['transferredAt']),
  );
}

/// A class a student can be transferred to.
@Freezed(fromJson: false, toJson: false)
sealed class TransferDestination with _$TransferDestination {
  const factory TransferDestination({
    required int id,
    required String code,
    required String name,
  }) = _TransferDestination;

  factory TransferDestination.fromJson(Map<String, dynamic> json) =>
      TransferDestination(
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// What the caller may do on this class. The server enforces each one too.
@Freezed(fromJson: false, toJson: false)
sealed class ManageCan with _$ManageCan {
  const factory ManageCan({
    @Default(false) bool update,
    @Default(false) bool enrol,
    @Default(false) bool setClassAdmin,
    @Default(false) bool transfer,
    @Default(false) bool link,
  }) = _ManageCan;

  factory ManageCan.fromJson(Map<String, dynamic> json) => ManageCan(
    update: json['update'] == true,
    enrol: json['enrol'] == true,
    setClassAdmin: json['setClassAdmin'] == true,
    transfer: json['transfer'] == true,
    link: json['link'] == true,
  );
}

/// The choices the form offers.
@Freezed(fromJson: false, toJson: false)
sealed class ManageLookups with _$ManageLookups {
  const factory ManageLookups({
    @Default([]) List<ManageOption> languages,
    @Default([]) List<ManageOption> tags,
    @Default([]) List<ManageOption> topics,
    @Default([]) List<ManageTimezone> timezones,
  }) = _ManageLookups;

  factory ManageLookups.fromJson(Map<String, dynamic> json) => ManageLookups(
    languages: _list(json['languages'], ManageOption.fromJson),
    tags: _list(json['tags'], ManageOption.fromJson),
    topics: _list(json['topics'], ManageOption.fromJson),
    timezones: _list(json['timezones'], ManageTimezone.fromJson),
  );
}

/// The two rosters, and the transfer history when the caller may transfer.
/// This is what every student action answers with.
@Freezed(fromJson: false, toJson: false)
sealed class ManageRoster with _$ManageRoster {
  const factory ManageRoster({
    @Default([]) List<ManagedStudent> students,
    @Default([]) List<RemovedStudent> removedStudents,
    @Default([]) List<AddCandidate> mcqStudents,
    @Default([]) List<TransferRecord> transferHistory,
  }) = _ManageRoster;

  factory ManageRoster.fromJson(Map<String, dynamic> json) => ManageRoster(
    students: _list(json['students'], ManagedStudent.fromJson),
    removedStudents: _list(json['removedStudents'], RemovedStudent.fromJson),
    mcqStudents: _list(json['mcqStudents'], AddCandidate.fromJson),
    transferHistory: _list(json['transferHistory'], TransferRecord.fromJson),
  );
}

/// GET /classes/{id}/manage.
@Freezed(fromJson: false, toJson: false)
sealed class ClassManagePayload with _$ClassManagePayload {
  const factory ClassManagePayload({
    required ManagedClass classInfo,
    @Default([]) List<ManageOption> tags,
    @Default([]) List<ManageSchedule> schedules,
    @Default(ManageLookups()) ManageLookups lookups,
    @Default(ManageCan()) ManageCan can,
    @Default(ManageRoster()) ManageRoster roster,
    @Default([]) List<TransferDestination> destinations,
  }) = _ClassManagePayload;

  factory ClassManagePayload.fromJson(Map<String, dynamic> json) =>
      ClassManagePayload(
        classInfo: ManagedClass.fromJson(json['class'] as Map<String, dynamic>),
        tags: _list(json['tags'], ManageOption.fromJson),
        schedules: _list(json['schedules'], ManageSchedule.fromJson),
        lookups: ManageLookups.fromJson(
          json['lookups'] as Map<String, dynamic>? ?? const {},
        ),
        can: ManageCan.fromJson(
          json['can'] as Map<String, dynamic>? ?? const {},
        ),
        roster: ManageRoster.fromJson(json),
        destinations: _list(json['destinations'], TransferDestination.fromJson),
      );
}

/// The body of PUT /classes/{id}: everything the Details and Schedule tabs edit.
/// The server removes any schedule or topic it is not sent, so this always
/// carries the full lists.
@Freezed(fromJson: false, toJson: false)
sealed class ClassDraft with _$ClassDraft {
  const ClassDraft._();

  const factory ClassDraft({
    int? languageId,
    String? startedOn,
    required String format,
    String? address,
    String? city,
    String? country,
    String? location,
    required int teacher,
    String? teacherName,
    @Default([]) List<int> tags,
    @Default([]) List<ManageSchedule> schedules,
  }) = _ClassDraft;

  /// The draft that matches what the server holds.
  factory ClassDraft.from(ClassManagePayload payload) {
    final c = payload.classInfo;
    return ClassDraft(
      languageId: c.languageId,
      startedOn: c.startedOn,
      format: c.format,
      address: c.address,
      city: c.city,
      country: c.country,
      location: c.location,
      teacher: c.teacher,
      teacherName: c.teacherName,
      tags: payload.tags.map((t) => t.id).toList(),
      schedules: payload.schedules,
    );
  }

  Map<String, dynamic> toJson() => {
    'languageId': languageId,
    'startedOn': startedOn,
    'format': format,
    'address': address,
    'city': city,
    'country': country,
    'location': location,
    'teacher': teacher,
    'tags': tags,
    'schedules': schedules.map((s) => s.toJson()).toList(),
  };
}

/// A class the extra student is in.
@Freezed(fromJson: false, toJson: false)
sealed class LinkClass with _$LinkClass {
  const factory LinkClass({
    required int id,
    required String code,
    required String name,
    @Default(false) bool current,
  }) = _LinkClass;

  factory LinkClass.fromJson(Map<String, dynamic> json) => LinkClass(
    id: json['id'] as int,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    current: json['current'] == true,
  );
}

/// The extra student a link would remove.
@Freezed(fromJson: false, toJson: false)
sealed class LinkExtra with _$LinkExtra {
  const factory LinkExtra({
    required int token,
    required String name,
    @Default([]) List<LinkClass> classes,
  }) = _LinkExtra;

  factory LinkExtra.fromJson(Map<String, dynamic> json) => LinkExtra(
    token: json['token'] as int,
    name: json['name'] as String? ?? '',
    classes: _list(json['classes'], LinkClass.fromJson),
  );
}

/// One item both people hold a record for; the super admin picks a side.
/// [member] and [extra] are the fields of each side, which depend on [kind].
@Freezed(fromJson: false, toJson: false)
sealed class LinkConflict with _$LinkConflict {
  const factory LinkConflict({
    required String kind,
    required int itemId,
    String? classCode,
    required String label,
    @Default({}) Map<String, dynamic> member,
    @Default({}) Map<String, dynamic> extra,
  }) = _LinkConflict;

  factory LinkConflict.fromJson(Map<String, dynamic> json) => LinkConflict(
    kind: json['kind'] as String,
    itemId: json['itemId'] as int,
    classCode: _text(json['classCode']),
    label: json['label'] as String? ?? '',
    member: json['member'] as Map<String, dynamic>? ?? const {},
    extra: json['extra'] as Map<String, dynamic>? ?? const {},
  );
}

/// What a link would do: the member, the extra student and every conflict.
@Freezed(fromJson: false, toJson: false)
sealed class LinkPreview with _$LinkPreview {
  const factory LinkPreview({
    required MemberDetails member,
    required LinkExtra extra,
    @Default([]) List<LinkConflict> conflicts,
  }) = _LinkPreview;

  factory LinkPreview.fromJson(Map<String, dynamic> json) => LinkPreview(
    member: MemberDetails.fromJson(json['member']),
    extra: LinkExtra.fromJson(json['extra'] as Map<String, dynamic>),
    conflicts: _list(json['conflicts'], LinkConflict.fromJson),
  );
}

/// The super admin's choice for one conflict. [keep] is `member` or `extra`.
@Freezed(fromJson: false, toJson: false)
sealed class LinkResolution with _$LinkResolution {
  const LinkResolution._();

  const factory LinkResolution({
    required String kind,
    required int itemId,
    required String keep,
  }) = _LinkResolution;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'itemId': itemId,
    'keep': keep,
  };
}

/// 409 `records_changed`: the records moved since the preview. Nothing was
/// written; [preview] is the fresh list to choose again from.
class LinkRecordsChanged implements Exception {
  const LinkRecordsChanged(this.message, this.preview);

  final String message;
  final LinkPreview preview;
}
