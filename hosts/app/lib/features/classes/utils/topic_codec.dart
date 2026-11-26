/// Composing and parsing the syllabus topic values stored in
/// `class_sessions.*_topic`.
///
/// A teacher picks a topic, then a sub-topic, then optionally types what was
/// actually covered. All three go into the one existing column, so this file is
/// the only place that knows how they are joined and taken apart again. It is a
/// port of the same logic in the web admin's `class_sessions_add.php`; the two
/// must agree, because both write to the same column and either may read what
/// the other wrote.
library;

/// Separator between topic, sub-topic and detail.
///
/// Deliberately not ' - ': that string appears in 73 of the real catalog's 224
/// names ("Daily Prayers - 1", "Sujood - 3") and in 5,394 of the 76,182 topic
/// values teachers have typed by hand, so it cannot delimit anything here.
/// ' :: ' appears in neither, not once.
const String topicSeparator = ' :: ';

/// What joined the parts before [topicSeparator] existed.
///
/// Every value stored today predates the change, so reading it back still has
/// to work — see [parseStoredTopic].
const String _legacySeparator = ' - ';

/// The topic option standing for "not in the syllabus", which swaps the
/// sub-topic dropdown for a free-text box.
const String otherTopicOption = 'Other';

/// One subject's slice of the syllabus catalog: topic name to its sub-topics.
///
/// A topic may legitimately have none, in which case it is stored on its own.
typedef SubjectCatalog = Map<String, List<String>>;

/// Everything the class's level offers, keyed by subject code.
///
/// Empty for a level with no syllabus — only Miqdad has one today — and empty
/// for a subject the syllabus does not cover. Either way the subject shows the
/// plain text field rather than a dropdown that could only offer "Other".
typedef SyllabusTopics = Map<String, SubjectCatalog>;

/// Reads the catalog out of a `/classes/{id}/syllabus-topics` body.
///
/// The body is not always a JSON object. A level with no syllabus — every level
/// but Miqdad — makes the server return PHP's empty array, which `json_encode`
/// writes as `[]`, so the common case arrives as a list rather than a map.
/// Anything that is not a map of maps is simply no catalog, which is what puts
/// the subject back on its free-text field.
SyllabusTopics syllabusTopicsFromJson(dynamic body) {
  if (body is! Map) return const <String, SubjectCatalog>{};

  final catalog = <String, SubjectCatalog>{};
  for (final subject in body.entries) {
    final topics = subject.value;
    if (topics is! Map) continue;

    final subjectCatalog = <String, List<String>>{};
    for (final topic in topics.entries) {
      final subtopics = topic.value;
      subjectCatalog[topic.key.toString()] = subtopics is List
          ? subtopics.map((s) => s.toString()).toList()
          : const <String>[];
    }
    if (subjectCatalog.isNotEmpty) {
      catalog[subject.key.toString()] = subjectCatalog;
    }
  }
  return catalog;
}

/// What the three controls for one subject currently hold.
class TopicSelection {
  /// The chosen topic, [otherTopicOption], or '' when nothing is chosen yet.
  final String topic;

  /// The chosen sub-topic, or '' when the topic has none or none is chosen.
  final String subtopic;

  /// The free text typed when [topic] is [otherTopicOption].
  final String custom;

  /// The optional detail typed after the topic and sub-topic.
  final String details;

  const TopicSelection({
    this.topic = '',
    this.subtopic = '',
    this.custom = '',
    this.details = '',
  });

  TopicSelection copyWith({
    String? topic,
    String? subtopic,
    String? custom,
    String? details,
  }) {
    return TopicSelection(
      topic: topic ?? this.topic,
      subtopic: subtopic ?? this.subtopic,
      custom: custom ?? this.custom,
      details: details ?? this.details,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TopicSelection &&
        other.topic == topic &&
        other.subtopic == subtopic &&
        other.custom == custom &&
        other.details == details;
  }

  @override
  int get hashCode => Object.hash(topic, subtopic, custom, details);

  @override
  String toString() =>
      'TopicSelection(topic: $topic, subtopic: $subtopic, '
      'custom: $custom, details: $details)';
}

/// The sub-topics [catalog] lists for [topic], empty when it lists none.
List<String> subtopicsFor(SubjectCatalog catalog, String topic) {
  if (topic.isEmpty || topic == otherTopicOption) return const <String>[];
  return catalog[topic] ?? const <String>[];
}

/// Flattens [selection] into the single value the column stores.
///
/// Returns '' whenever the selection is incomplete — no topic chosen, a topic
/// whose sub-topic is still unpicked, or "Other" with no text. That empty string
/// is also how the form knows the subject is unfinished, so there is no separate
/// notion of completeness to keep in step with this.
String composeTopic(TopicSelection selection, SubjectCatalog catalog) {
  if (selection.topic.isEmpty) return '';

  if (selection.topic == otherTopicOption) {
    return selection.custom.trim();
  }

  final detail = selection.details.trim();
  final tail = detail.isEmpty ? '' : '$topicSeparator$detail';

  if (subtopicsFor(catalog, selection.topic).isEmpty) {
    return '${selection.topic}$tail';
  }

  if (selection.subtopic.isEmpty) return '';
  return '${selection.topic}$topicSeparator${selection.subtopic}$tail';
}

/// A stored topic value as it should read on screen.
///
/// [topicSeparator] is punctuation for a parser, not for a person: left alone
/// it puts "Understanding the Holy Quran - Intermediate :: Lesson 2 :: finished
/// the vocabulary list" in front of a teacher reading a list of sessions. The
/// parts are worth showing; the thing joining them is not.
///
/// This needs no catalog and makes no judgement about which part is which, so
/// it is safe on any value from any level. Anything written before the
/// separator existed contains none of it and comes back untouched.
String topicForDisplay(String stored) {
  return stored
      .split(topicSeparator)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' · ');
}

/// Splits a stored value back into topic, sub-topic and detail, or null when
/// neither path recognises it.
///
/// Values written with [topicSeparator] split structurally, without consulting
/// the catalog. That matters: renaming a topic in the catalog must not strip
/// the structure from every value already stored under the old name.
///
/// Older values — everything written before that separator, including the free
/// text teachers typed themselves — are matched against the catalog on
/// [_legacySeparator] instead. Topic and sub-topic come from a closed list
/// there, so whatever survives matching them is the detail, and candidates are
/// tried longest-first so a name cannot be shadowed by a shorter one that is
/// its prefix.
TopicSelection? parseStoredTopic(String value, SubjectCatalog catalog) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.contains(topicSeparator)) {
    final parts = trimmed.split(topicSeparator);
    final topic = parts[0].trim();

    // Three or more segments is unambiguous. A detail that itself contains the
    // separator is rejoined rather than truncated.
    if (parts.length >= 3) {
      return TopicSelection(
        topic: topic,
        subtopic: parts[1].trim(),
        details: parts.sublist(2).join(topicSeparator).trim(),
      );
    }

    // Two segments: the second is a sub-topic for any topic that has them, and
    // a detail only for a topic that has none. This is the one place the
    // structural path still needs the catalog; an unrecognised topic assumes a
    // sub-topic, which is how compose writes the common case.
    final second = parts[1].trim();
    final hasSubtopics = catalog.containsKey(topic)
        ? catalog[topic]!.isNotEmpty
        : true;
    return hasSubtopics
        ? TopicSelection(topic: topic, subtopic: second)
        : TopicSelection(topic: topic, details: second);
  }

  bool startsWith(String haystack, String needle) =>
      haystack.toLowerCase().startsWith(needle.toLowerCase());

  final topics = catalog.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final topic in topics) {
    if (!startsWith(trimmed, topic)) continue;

    final afterTopic = trimmed.substring(topic.length);
    if (afterTopic.isEmpty) return TopicSelection(topic: topic);
    if (!startsWith(afterTopic, _legacySeparator)) continue;

    final rest = afterTopic.substring(_legacySeparator.length);
    final subtopics = List<String>.from(catalog[topic] ?? const <String>[])
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final subtopic in subtopics) {
      if (!startsWith(rest, subtopic)) continue;

      final afterSub = rest.substring(subtopic.length);
      if (afterSub.isEmpty) {
        return TopicSelection(topic: topic, subtopic: subtopic);
      }
      if (startsWith(afterSub, _legacySeparator)) {
        return TopicSelection(
          topic: topic,
          subtopic: subtopic,
          details: afterSub.substring(_legacySeparator.length).trim(),
        );
      }
    }

    if (subtopics.isEmpty) {
      return TopicSelection(topic: topic, details: rest.trim());
    }
  }

  return null;
}

/// Turns a stored value into the state the three controls should open with.
///
/// Anything the catalog cannot account for goes to [otherTopicOption] with its
/// text intact, so a teacher opening an old session sees what they wrote rather
/// than an empty box. Only call this when the subject actually has a catalog —
/// without one there are no dropdowns to populate, and the raw value belongs in
/// the plain text field.
TopicSelection hydrateTopicSelection(String? raw, SubjectCatalog catalog) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return const TopicSelection();

  final parsed = parseStoredTopic(trimmed, catalog);

  // A name the catalog no longer lists cannot be offered as a dropdown choice,
  // so it is treated exactly like text the parse did not recognise at all. This
  // is what a renamed topic or sub-topic looks like from here — most likely one
  // renamed since the value was written, or written by the web form against a
  // newer catalog. Preserving the text under "Other" keeps it editable; leaving
  // it selected would show a blank dropdown and lose the value on the next save.
  if (parsed == null ||
      !catalog.containsKey(parsed.topic) ||
      (parsed.subtopic.isNotEmpty &&
          !catalog[parsed.topic]!.contains(parsed.subtopic))) {
    return TopicSelection(topic: otherTopicOption, custom: trimmed);
  }

  return parsed;
}
