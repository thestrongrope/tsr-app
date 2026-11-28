/// Models for the MCQ management (teacher/admin) feature.
///
/// These mirror the mobile API's `mcq_admin.php` router contract: camelCase
/// over the wire, and the correct answer is exposed as `answer` (the backend
/// stores it in `option1`).
library;

import '../../../core/utils/api_datetime.dart';

/// A quiz row in the management list.
class McqManageQuiz {
  final int id;
  final String code;
  final String name;
  final String? topic;
  final int classId;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? deactivatedAt;
  final int restrictToClass;
  final int questionCount;
  final int submittedCount;

  /// The MCQ's shareable link; null until it is released (#864).
  final String? link;

  const McqManageQuiz({
    required this.id,
    required this.code,
    required this.name,
    this.topic,
    required this.classId,
    required this.createdAt,
    this.publishedAt,
    this.deactivatedAt,
    this.restrictToClass = 1,
    this.questionCount = 0,
    this.submittedCount = 0,
    this.link,
  });

  factory McqManageQuiz.fromJson(Map<String, dynamic> json) {
    return McqManageQuiz(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Untitled Quiz',
      topic: json['topic'] as String?,
      classId: json['classId'] as int,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      publishedAt: _parseDate(json['publishedAt']),
      deactivatedAt: _parseDate(json['deactivatedAt']),
      restrictToClass: json['restrictToClass'] as int? ?? 1,
      questionCount: json['questionCount'] as int? ?? 0,
      submittedCount: json['submittedCount'] as int? ?? 0,
      link: json['link'] as String?,
    );
  }

  /// Whether the quiz is currently live (published and not deactivated).
  bool get isPublished => publishedAt != null && deactivatedAt == null;

  /// Whether the quiz has been deactivated.
  bool get isDeactivated => deactivatedAt != null;

  /// Whether the quiz is open to all TSR subscribers (restrict_to_class = 0).
  bool get isOpenToAll => restrictToClass == 0;

  /// Display status label.
  String get statusLabel {
    if (isDeactivated) return 'Deactivated';
    if (isPublished) return 'Published';
    return 'Draft';
  }
}

/// Paginated management list response.
class McqManageListResponse {
  final int total;
  final int page;
  final int pageSize;
  final bool hasNext;
  final List<McqManageQuiz> items;

  const McqManageListResponse({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasNext,
    required this.items,
  });

  factory McqManageListResponse.fromJson(Map<String, dynamic> json) {
    return McqManageListResponse(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      hasNext: json['hasNext'] as bool? ?? false,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => McqManageQuiz.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <McqManageQuiz>[],
    );
  }
}

/// A question in the edit payload.
class McqManageQuestion {
  final int id;
  final String question;
  final String? answer;
  final String? option2;
  final String? option3;
  final String? option4;
  final String? option5;

  const McqManageQuestion({
    this.id = 0,
    required this.question,
    this.answer,
    this.option2,
    this.option3,
    this.option4,
    this.option5,
  });

  factory McqManageQuestion.fromJson(Map<String, dynamic> json) {
    return McqManageQuestion(
      id: json['id'] as int? ?? 0,
      question: (json['question'] as String?) ?? '',
      answer: json['answer'] as String?,
      option2: json['option2'] as String?,
      option3: json['option3'] as String?,
      option4: json['option4'] as String?,
      option5: json['option5'] as String?,
    );
  }

  /// All non-empty options in display order (answer first).
  List<String> get options {
    final list = <String>[];
    if (answer != null && answer!.trim().isNotEmpty) list.add(answer!);
    for (final o in [option2, option3, option4, option5]) {
      if (o != null && o.trim().isNotEmpty) list.add(o);
    }
    return list;
  }

  /// Whether this question is complete enough to save.
  bool get isComplete =>
      question.trim().isNotEmpty && answer != null && answer!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'question': question,
    'answer': answer,
    'option2': option2,
    'option3': option3,
    'option4': option4,
    'option5': option5,
  };
}

/// Full quiz detail for editing (quiz + questions).
class McqManageDetail {
  final int id;
  final String code;
  final String name;
  final String? topic;
  final int classId;
  final String classCode;
  final String className;
  final int restrictToClass;
  final DateTime? publishedAt;
  final DateTime? deactivatedAt;
  final List<McqManageQuestion> questions;

  const McqManageDetail({
    required this.id,
    required this.code,
    required this.name,
    this.topic,
    required this.classId,
    this.classCode = '',
    this.className = '',
    this.restrictToClass = 1,
    this.publishedAt,
    this.deactivatedAt,
    this.questions = const <McqManageQuestion>[],
  });

  factory McqManageDetail.fromJson(Map<String, dynamic> json) {
    return McqManageDetail(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      topic: json['topic'] as String?,
      classId: json['classId'] as int,
      classCode: (json['classCode'] as String?) ?? '',
      className: (json['className'] as String?) ?? '',
      restrictToClass: json['restrictToClass'] as int? ?? 1,
      publishedAt: _parseDate(json['publishedAt']),
      deactivatedAt: _parseDate(json['deactivatedAt']),
      questions:
          (json['questions'] as List<dynamic>?)
              ?.map(
                (e) => McqManageQuestion.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <McqManageQuestion>[],
    );
  }
}

/// A single student's score row.
class McqScoreEntry {
  final String name;
  final DateTime submitted;
  final int correct;
  final int outOf;

  const McqScoreEntry({
    required this.name,
    required this.submitted,
    required this.correct,
    required this.outOf,
  });

  factory McqScoreEntry.fromJson(Map<String, dynamic> json) {
    return McqScoreEntry(
      name: (json['name'] as String?) ?? '',
      submitted: _parseDate(json['submitted']) ?? DateTime.now(),
      correct: json['correct'] as int? ?? 0,
      outOf: json['outof'] as int? ?? 0,
    );
  }

  double get percent => outOf > 0 ? (correct / outOf * 100) : 0;
}

/// Scores response for a quiz.
class McqScoresResponse {
  final int quizId;
  final String quizName;
  final String? topic;
  final String classCode;
  final List<McqScoreEntry> items;

  const McqScoresResponse({
    required this.quizId,
    required this.quizName,
    this.topic,
    this.classCode = '',
    this.items = const <McqScoreEntry>[],
  });

  factory McqScoresResponse.fromJson(Map<String, dynamic> json) {
    final quiz = json['quiz'] as Map<String, dynamic>? ?? const {};
    return McqScoresResponse(
      quizId: quiz['id'] as int? ?? 0,
      quizName: (quiz['name'] as String?) ?? '',
      topic: quiz['topic'] as String?,
      classCode: (quiz['classCode'] as String?) ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => McqScoreEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <McqScoreEntry>[],
    );
  }
}

/// A standard MCQ available to copy into a class.
class McqStandardQuiz {
  final int id;
  final String code;
  final String topic;
  final String subject;
  final String lesson;
  final String name;
  final int questionCount;
  final bool copied;

  const McqStandardQuiz({
    required this.id,
    required this.code,
    required this.topic,
    required this.subject,
    required this.lesson,
    required this.name,
    this.questionCount = 0,
    this.copied = false,
  });

  factory McqStandardQuiz.fromJson(Map<String, dynamic> json) {
    return McqStandardQuiz(
      id: json['id'] as int,
      code: (json['code'] as String?) ?? '',
      topic: (json['topic'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? '',
      lesson: (json['lesson'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      questionCount: json['questionCount'] as int? ?? 0,
      copied: json['copied'] == true || json['copied'] == 1,
    );
  }

  String get displayName {
    final parts = <String>[
      if (lesson.trim().isNotEmpty) lesson.trim(),
      if (name.trim().isNotEmpty) name.trim(),
    ];
    return parts.join(' - ');
  }
}

/// Standard MCQs grouped by topic then subject.
class McqStandardSubject {
  final String subject;
  final List<McqStandardQuiz> quizzes;

  const McqStandardSubject({required this.subject, required this.quizzes});
}

class McqStandardTopic {
  final String topic;
  final List<McqStandardSubject> subjects;

  const McqStandardTopic({required this.topic, required this.subjects});
}

class McqStandardResponse {
  final String classCode;
  final int languageId;
  final List<McqStandardTopic> topics;

  const McqStandardResponse({
    this.classCode = '',
    this.languageId = 0,
    this.topics = const <McqStandardTopic>[],
  });

  factory McqStandardResponse.fromJson(Map<String, dynamic> json) {
    final classInfo = json['class'] as Map<String, dynamic>? ?? const {};
    final topics = <McqStandardTopic>[];
    for (final t in (json['topics'] as List<dynamic>?) ?? const []) {
      final tMap = t as Map<String, dynamic>;
      final subjects = <McqStandardSubject>[];
      for (final s in (tMap['subjects'] as List<dynamic>?) ?? const []) {
        final sMap = s as Map<String, dynamic>;
        subjects.add(
          McqStandardSubject(
            subject: (sMap['subject'] as String?) ?? '',
            quizzes:
                (sMap['quizzes'] as List<dynamic>?)
                    ?.map(
                      (e) =>
                          McqStandardQuiz.fromJson(e as Map<String, dynamic>),
                    )
                    .toList() ??
                const <McqStandardQuiz>[],
          ),
        );
      }
      topics.add(
        McqStandardTopic(
          topic: (tMap['topic'] as String?) ?? '',
          subjects: subjects,
        ),
      );
    }
    return McqStandardResponse(
      classCode: (classInfo['code'] as String?) ?? '',
      languageId: classInfo['languageId'] as int? ?? 0,
      topics: topics,
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return parseApiLocalDateTime(value.toString());
}

/// A class in the copy picker (`GET /mcq/copy/classes`).
class McqCopyClass {
  final int id;
  final String code;
  final String level;
  final String? city;
  final String? teacher;

  const McqCopyClass({
    required this.id,
    required this.code,
    required this.level,
    this.city,
    this.teacher,
  });

  factory McqCopyClass.fromJson(Map<String, dynamic> json) => McqCopyClass(
    id: json['id'] as int,
    code: (json['code'] as String?) ?? '',
    level: (json['level'] as String?) ?? '',
    city: json['city'] as String?,
    teacher: json['teacher'] as String?,
  );

  /// "CODE - Teacher", as the web's Copy MCQ page labels a class.
  String get label =>
      teacher == null || teacher!.isEmpty ? code : '$code - $teacher';
}

/// A quiz in the copy picker (`GET /mcq/copy/classes/{id}/quizzes`).
class McqCopyQuiz {
  final int id;
  final String name;
  final String createdAt;

  const McqCopyQuiz({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory McqCopyQuiz.fromJson(Map<String, dynamic> json) => McqCopyQuiz(
    id: json['id'] as int,
    name: (json['name'] as String?) ?? 'Untitled Quiz',
    createdAt: (json['createdAt'] as String?) ?? '',
  );
}
