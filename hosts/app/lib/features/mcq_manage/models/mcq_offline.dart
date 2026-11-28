/// One option of a question, in the order students see it (#409).
class OfflineOption {
  final String text;
  final bool isCorrect;

  const OfflineOption({required this.text, required this.isCorrect});

  factory OfflineOption.fromJson(Map<String, dynamic> json) => OfflineOption(
    text: (json['text'] as String?) ?? '',
    isCorrect: json['isCorrect'] == true,
  );
}

class OfflineQuestion {
  final int id;
  final String question;
  final List<OfflineOption> options;

  const OfflineQuestion({
    required this.id,
    required this.question,
    required this.options,
  });

  factory OfflineQuestion.fromJson(Map<String, dynamic> json) =>
      OfflineQuestion(
        id: json['id'] as int,
        question: (json['question'] as String?) ?? '',
        options: [
          for (final o in (json['options'] as List<dynamic>? ?? const []))
            OfflineOption.fromJson(o as Map<String, dynamic>),
        ],
      );
}

/// A student of the class. [isOffline] is the server's word for "has no
/// phone"; [submitted] students keep their answers and cannot be chosen.
class OfflineStudent {
  final int token;
  final String name;
  final bool isOffline;
  final bool submitted;

  const OfflineStudent({
    required this.token,
    required this.name,
    required this.isOffline,
    required this.submitted,
  });

  factory OfflineStudent.fromJson(Map<String, dynamic> json) => OfflineStudent(
    token: json['token'] as int,
    name: (json['name'] as String?) ?? '',
    isOffline: json['isOffline'] == true,
    submitted: json['submitted'] == true,
  );
}

/// Everything the offline screens need, from
/// `GET /mcq/manage/{quiz_id}/offline`.
class McqOfflineData {
  final String quizName;
  final String? topic;
  final List<OfflineQuestion> questions;
  final List<OfflineStudent> students;

  const McqOfflineData({
    required this.quizName,
    required this.topic,
    required this.questions,
    required this.students,
  });

  factory McqOfflineData.fromJson(Map<String, dynamic> json) {
    final quiz = json['quiz'] as Map<String, dynamic>? ?? const {};
    return McqOfflineData(
      quizName: (quiz['name'] as String?) ?? '',
      topic: quiz['topic'] as String?,
      questions: [
        for (final q in (json['questions'] as List<dynamic>? ?? const []))
          OfflineQuestion.fromJson(q as Map<String, dynamic>),
      ],
      students: [
        for (final s in (json['students'] as List<dynamic>? ?? const []))
          OfflineStudent.fromJson(s as Map<String, dynamic>),
      ],
    );
  }
}
