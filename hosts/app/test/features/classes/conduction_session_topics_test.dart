import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/models/models.dart';

/// What the conduction list actually renders.
///
/// The list builds a chip per subject from `subjectTopics`, so this getter is
/// the last point at which a stored value can be made fit to read. It was
/// handing the UI the raw column, separators and all.
ConductionSession _session({
  String? arabic,
  String? akhlaq,
  bool arabicConducted = true,
  bool akhlaqConducted = false,
}) {
  return ConductionSession(
    id: 1,
    conductedOn: DateTime(2026, 9, 9),
    conducted: true,
    arabicConducted: arabicConducted,
    arabicTopic: arabic,
    akhlaqConducted: akhlaqConducted,
    akhlaqTopic: akhlaq,
  );
}

void main() {
  test('a syllabus topic reads as its parts, not as stored punctuation', () {
    final topics = _session(
      arabic:
          'Understanding the Holy Quran - Intermediate :: Lesson 2 :: '
          'finished the vocabulary list',
    ).subjectTopics;

    expect(topics.single.label, 'Arabic');
    expect(
      topics.single.topic,
      'Understanding the Holy Quran - Intermediate · Lesson 2 · '
      'finished the vocabulary list',
    );
    expect(topics.single.topic, isNot(contains('::')));
  });

  test('free text from before the dropdowns is unchanged', () {
    const typed = 'UHQI L9 - revision';
    expect(_session(arabic: typed).subjectTopics.single.topic, typed);
  });

  test('a subject with no topic recorded stays null', () {
    expect(_session(arabic: null).subjectTopics.single.topic, isNull);
  });

  test('Akhlaq is never reformatted, because it has no syllabus', () {
    // No level gives Akhlaq or Other a catalog, so their value is always a
    // teacher's own words. If one of them literally types the separator, that
    // is text they wrote and it has to survive to the screen unchanged.
    const typed = 'patience :: and gratitude';
    final topics = _session(
      arabic: null,
      arabicConducted: false,
      akhlaq: typed,
      akhlaqConducted: true,
    ).subjectTopics;

    expect(topics.single.label, 'Akhlaq');
    expect(topics.single.topic, typed);
  });

  test('the same text under Arabic is still formatted', () {
    // The counterpart: Arabic can come from the syllabus, so it goes through
    // the formatter. This asymmetry is the point, not an oversight.
    expect(
      _session(arabic: 'patience :: and gratitude').subjectTopics.single.topic,
      'patience · and gratitude',
    );
  });

  test('only conducted subjects are listed, in display order', () {
    final topics = _session(
      arabic: 'Taqleed :: Lesson 1',
      akhlaq: 'Patience',
      akhlaqConducted: true,
    ).subjectTopics;

    expect(topics.map((t) => t.label), ['Arabic', 'Akhlaq']);
    expect(topics.last.topic, 'Patience');
  });
}
