import 'package:freezed_annotation/freezed_annotation.dart';

import '../utils/topic_codec.dart';

part 'conduction.freezed.dart';

/// A surah from the Holy Quran (used by the recitation picker).
@freezed
sealed class HolyQuranSurah with _$HolyQuranSurah {
  const HolyQuranSurah._();

  const factory HolyQuranSurah({
    required int id,
    required String surah,
    String? arabic,
    @Default(0) int verses,
  }) = _HolyQuranSurah;

  factory HolyQuranSurah.fromJson(Map<String, dynamic> json) {
    return HolyQuranSurah(
      id: json['id'] as int,
      surah: json['surah'] as String? ?? '',
      arabic: json['arabic'] as String?,
      verses: json['verses'] as int? ?? 0,
    );
  }
}

/// A student row in the conduction form (regular or extra).
@freezed
sealed class ConductionStudent with _$ConductionStudent {
  const ConductionStudent._();

  const factory ConductionStudent({
    required int token,
    required String name,
    @Default(false) bool present,
    @Default(0) int recitation,
    @Default(false) bool extra,
  }) = _ConductionStudent;

  factory ConductionStudent.fromJson(Map<String, dynamic> json) {
    return ConductionStudent(
      token: json['token'] as int,
      name: json['name'] as String? ?? '',
      present: json['present'] == 1 || json['present'] == true,
      recitation: json['recitation'] as int? ?? 0,
      extra: json['extra'] == 1 || json['extra'] == true,
    );
  }

  ConductionStudent withPresent(bool value) => copyWith(present: value);
  ConductionStudent withRecitation(int value) => copyWith(recitation: value);
}

/// Minimal class info for the conduction screens.
@freezed
sealed class ConductionClass with _$ConductionClass {
  const ConductionClass._();

  const factory ConductionClass({
    required int id,
    required String code,
    required String name,
    @Default(0) int level,
    String? levelName,
    @Default(0) int gender,
    String? status,
    String? teacherName,
    @Default(<ConductionStudent>[]) List<ConductionStudent> students,
    @Default(<ConductionStudent>[]) List<ConductionStudent> extraStudents,
    @Default(0) int totalStudents,
  }) = _ConductionClass;

  factory ConductionClass.fromJson(Map<String, dynamic> json) {
    final studentsList =
        (json['students'] as List<dynamic>?)
            ?.map((e) => ConductionStudent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <ConductionStudent>[];
    final extraList =
        (json['extraStudents'] as List<dynamic>?)
            ?.map((e) => ConductionStudent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <ConductionStudent>[];

    return ConductionClass(
      id: json['id'] as int,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      level: json['level'] as int? ?? 0,
      levelName: json['levelName'] as String?,
      gender: json['gender'] as int? ?? 0,
      status: json['status'] as String?,
      teacherName: json['teacherName'] as String?,
      students: studentsList,
      extraStudents: extraList,
      totalStudents:
          json['totalStudents'] as int? ??
          (studentsList.length + extraList.length),
    );
  }

  bool get isGents => gender == 1;
}

/// A full conduction session record (teacher/admin view).
@freezed
sealed class ConductionSession with _$ConductionSession {
  const ConductionSession._();

  const factory ConductionSession({
    required int id,
    required DateTime conductedOn,
    required bool conducted,
    int? duration,
    int? attendance,
    int? quranRecitationSurah,
    int? quranRecitationVerse,
    @Default(false) bool arabicConducted,
    @Default(false) bool aqaedConducted,
    @Default(false) bool ahkamConducted,
    @Default(false) bool akhlaqConducted,
    @Default(false) bool otherConducted,
    String? arabicTopic,
    String? aqaedTopic,
    String? ahkamTopic,
    String? akhlaqTopic,
    String? otherTopic,
    String? nonConductionReason,
    @Default(false) bool editable,
  }) = _ConductionSession;

  factory ConductionSession.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      final raw = json['conductedOn'] ?? json['conducted_on'];
      parsedDate = raw != null
          ? DateTime.parse(raw.toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }
    return ConductionSession(
      id: json['id'] as int,
      conductedOn: parsedDate,
      conducted: json['conducted'] == 1 || json['conducted'] == true,
      duration: json['duration'] as int?,
      attendance: json['attendance'] as int?,
      quranRecitationSurah: json['quranRecitationSurah'] as int?,
      quranRecitationVerse: json['quranRecitationVerse'] as int?,
      arabicConducted:
          json['arabicConducted'] == 1 || json['arabicConducted'] == true,
      aqaedConducted:
          json['aqaedConducted'] == 1 || json['aqaedConducted'] == true,
      ahkamConducted:
          json['ahkamConducted'] == 1 || json['ahkamConducted'] == true,
      akhlaqConducted:
          json['akhlaqConducted'] == 1 || json['akhlaqConducted'] == true,
      otherConducted:
          json['otherConducted'] == 1 || json['otherConducted'] == true,
      arabicTopic: json['arabicTopic'] as String?,
      aqaedTopic: json['aqaedTopic'] as String?,
      ahkamTopic: json['ahkamTopic'] as String?,
      akhlaqTopic: json['akhlaqTopic'] as String?,
      otherTopic: json['otherTopic'] as String?,
      nonConductionReason: json['nonConductionReason'] as String?,
      editable: json['editable'] == 1 || json['editable'] == true,
    );
  }

  /// Subject topics covered in this session, in display order.
  ///
  /// A topic chosen from the syllabus is stored with a machine separator
  /// between its parts, so it is rendered through [topicForDisplay] rather than
  /// handed to the UI raw — but only for the three subjects a syllabus can
  /// cover. Akhlaq and Other have no catalog at any level, so whatever is in
  /// them is a teacher's own words, and reformatting text nobody composed would
  /// be changing what they wrote.
  ///
  /// That leaves one gap this layer cannot close: on a level with no syllabus
  /// the first three are free text too, and the session does not know its
  /// level. It is accepted rather than worked around, because the separator was
  /// chosen for appearing in none of the 76,182 values stored to date, and the
  /// alternative — a marker written into the column — would break the format the
  /// web admin form reads and writes.
  List<({String label, String? topic})> get subjectTopics {
    final list = <({String label, String? topic})>[];

    void add(
      String label,
      bool conducted,
      String? topic, {
      bool fromSyllabus = true,
    }) {
      if (!conducted) return;
      list.add((
        label: label,
        topic: (topic == null || !fromSyllabus)
            ? topic
            : topicForDisplay(topic),
      ));
    }

    add('Arabic', arabicConducted, arabicTopic);
    add('Aqaed', aqaedConducted, aqaedTopic);
    add('Ahkam', ahkamConducted, ahkamTopic);
    add('Akhlaq', akhlaqConducted, akhlaqTopic, fromSyllabus: false);
    add('Other', otherConducted, otherTopic, fromSyllabus: false);
    return list;
  }

  /// Formatted duration string (e.g. "1h 30m").
  String get durationFormatted {
    if (duration == null || duration == 0) return '—';
    if (duration! < 60) return '$duration min';
    final hours = duration! ~/ 60;
    final mins = duration! % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

/// Paginated conduction list response.
@freezed
sealed class ConductionListResponse with _$ConductionListResponse {
  const ConductionListResponse._();

  const factory ConductionListResponse({
    ConductionClass? classInfo,
    @Default(<ConductionSession>[]) List<ConductionSession> sessions,
    @Default(0) int totalRecords,
    @Default(1) int totalPages,
    @Default(1) int page,
  }) = _ConductionListResponse;

  factory ConductionListResponse.fromJson(Map<String, dynamic> json) {
    return ConductionListResponse(
      classInfo: json['class'] != null
          ? ConductionClass.fromJson(json['class'] as Map<String, dynamic>)
          : null,
      sessions:
          (json['sessions'] as List<dynamic>?)
              ?.map(
                (e) => ConductionSession.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <ConductionSession>[],
      // PHP's ceil() sends totalPages as a float (e.g. 3.0) and PDO can
      // return counts as strings, so coerce instead of `as int?`.
      totalRecords: _asInt(json['totalRecords']) ?? 0,
      totalPages: _asInt(json['totalPages']) ?? 1,
      page: _asInt(json['page']) ?? 1,
    );
  }

  /// Coerces num/String JSON values to int without throwing on doubles.
  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Form data for adding a new conduction record.
@freezed
sealed class ConductionFormData with _$ConductionFormData {
  const ConductionFormData._();

  const factory ConductionFormData({
    ConductionClass? classInfo,
    DateTime? lastSessionDate,
    DateTime? nextSessionDate,
    DateTime? futureDate,

    /// The last topic the class recorded for each subject, keyed by subject
    /// code ('arabic', 'aqaed', …). A subject the class has never recorded is
    /// absent rather than empty.
    @Default(<String, String>{}) Map<String, String> latestTopics,

    /// The Surah of the class's most recent earlier conduction that has one,
    /// or null when there is none (or the server predates the prefill).
    int? latestSurah,
    @Default(<HolyQuranSurah>[]) List<HolyQuranSurah> holyQuran,
  }) = _ConductionFormData;

  factory ConductionFormData.fromJson(Map<String, dynamic> json) {
    return ConductionFormData(
      classInfo: json['class'] != null
          ? ConductionClass.fromJson(json['class'] as Map<String, dynamic>)
          : null,
      lastSessionDate: json['lastSessionDate'] != null
          ? DateTime.tryParse(json['lastSessionDate'].toString())
          : null,
      nextSessionDate: json['nextSessionDate'] != null
          ? DateTime.tryParse(json['nextSessionDate'].toString())
          : null,
      futureDate: json['futureDate'] != null
          ? DateTime.tryParse(json['futureDate'].toString())
          : null,
      latestTopics: _latestTopicsFromJson(json['latestTopics']),
      latestSurah: (json['latestSurah'] as num?)?.toInt(),
      holyQuran:
          (json['holyQuran'] as List<dynamic>?)
              ?.map((e) => HolyQuranSurah.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <HolyQuranSurah>[],
    );
  }

  /// Re-keys the wire's `arabicTopic`/`aqaedTopic`/… by subject code, dropping
  /// the subjects the server sent as null because the class has never recorded
  /// them. Absent entirely on a server that predates the prefill.
  static Map<String, String> _latestTopicsFromJson(dynamic value) {
    if (value is! Map) return const <String, String>{};

    final topics = <String, String>{};
    for (final subject in const [
      'arabic',
      'aqaed',
      'ahkam',
      'akhlaq',
      'other',
    ]) {
      final raw = value['${subject}Topic'];
      if (raw == null) continue;
      final text = raw.toString().trim();
      if (text.isNotEmpty) topics[subject] = text;
    }
    return topics;
  }
}

/// A conduction record loaded for editing (session + attendance).
@freezed
sealed class ConductionEditData with _$ConductionEditData {
  const ConductionEditData._();

  const factory ConductionEditData({
    ConductionClass? classInfo,
    ConductionSession? session,
    @Default(<ConductionStudent>[]) List<ConductionStudent> attendance,
    @Default(<HolyQuranSurah>[]) List<HolyQuranSurah> holyQuran,
  }) = _ConductionEditData;

  factory ConductionEditData.fromJson(Map<String, dynamic> json) {
    return ConductionEditData(
      classInfo: json['class'] != null
          ? ConductionClass.fromJson(json['class'] as Map<String, dynamic>)
          : null,
      session: json['session'] != null
          ? ConductionSession.fromJson(json['session'] as Map<String, dynamic>)
          : null,
      attendance:
          (json['attendance'] as List<dynamic>?)
              ?.map(
                (e) => ConductionStudent.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <ConductionStudent>[],
      holyQuran:
          (json['holyQuran'] as List<dynamic>?)
              ?.map((e) => HolyQuranSurah.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <HolyQuranSurah>[],
    );
  }
}

/// Date conflict check result.
@freezed
sealed class ConductionDateCheck with _$ConductionDateCheck {
  const ConductionDateCheck._();

  const factory ConductionDateCheck({
    @Default(false) bool alreadyConducted,
    @Default(false) bool sameWeek,
  }) = _ConductionDateCheck;

  factory ConductionDateCheck.fromJson(Map<String, dynamic> json) {
    return ConductionDateCheck(
      alreadyConducted:
          json['alreadyConducted'] == 1 || json['alreadyConducted'] == true,
      sameWeek: json['sameWeek'] == 1 || json['sameWeek'] == true,
    );
  }
}
