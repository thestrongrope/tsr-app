import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/classes/utils/topic_codec.dart';

/// A deliberately small stand-in for `syllabus_topics.json`.
///
/// It is not a sample of the real catalog — it is built from the names that
/// actually break a naive split, because those are what the codec exists to
/// survive: 73 of the real catalog's 224 names contain ' - ', and one contains
/// ' / '. Vendoring the real 502-line catalog would test the fixture, not the
/// code.
const SubjectCatalog _catalog = {
  'Tahaarat': ['Kurr Water', 'Laws of Urinal - 1'],
  'Ghusl': ['Things Haraam / Makrooh for a Mujnib', 'Ghusl of Janabah'],
  // 'Sujood' is a prefix of 'Sujood - 3'. Matching shortest-first would take
  // 'Sujood' and leave '3' stranded as a detail.
  'Salaat': [
    'Daily Prayers - 1',
    'Prayers of a Traveler - 7',
    'Sujood',
    'Sujood - 3',
  ],
  // A topic the catalog lists with no sub-topics at all.
  'Taqleed': [],
};

/// Detail strings, including two that contain a separator themselves.
const _details = [
  '',
  'covered the whole chapter',
  'part 1 - part 2',
  'see handout :: page 4',
];

void main() {
  group('syllabusTopicsFromJson', () {
    test('an empty JSON array is no catalog, not a crash', () {
      // What the server actually sends for a level with no syllabus, which is
      // every level but Miqdad: PHP's empty array, encoded as `[]`. Verified
      // against the running API — api_send(getSyllabusTopics($level)) with no
      // match emits `[]`, never `{}`.
      expect(syllabusTopicsFromJson(const <dynamic>[]), isEmpty);
    });

    test('an empty object is no catalog either', () {
      expect(syllabusTopicsFromJson(const <String, dynamic>{}), isEmpty);
    });

    test('null and unexpected scalars are no catalog', () {
      expect(syllabusTopicsFromJson(null), isEmpty);
      expect(syllabusTopicsFromJson('nope'), isEmpty);
      expect(syllabusTopicsFromJson(7), isEmpty);
    });

    test('a real body parses into subjects, topics and sub-topics', () {
      final catalog = syllabusTopicsFromJson(const <String, dynamic>{
        'arabic': {
          'Understanding the Holy Quran': ['Lesson 1', 'Lesson 2'],
        },
        'ahkam': {'Taqleed': <dynamic>[]},
      });

      expect(catalog.keys, ['arabic', 'ahkam']);
      expect(catalog['arabic']!['Understanding the Holy Quran'], [
        'Lesson 1',
        'Lesson 2',
      ]);
      expect(catalog['ahkam']!['Taqleed'], isEmpty);
    });

    test('a subject that is not a map is skipped, not fatal', () {
      final catalog = syllabusTopicsFromJson(const <String, dynamic>{
        'arabic': <dynamic>[],
        'aqaed': {
          'Imamat': ['Lesson 1'],
        },
      });

      expect(catalog.keys, ['aqaed']);
    });

    test('sub-topics that are not a list become no sub-topics', () {
      final catalog = syllabusTopicsFromJson(const <String, dynamic>{
        'arabic': {'Broken': 'not a list'},
      });

      expect(catalog['arabic']!['Broken'], isEmpty);
    });
  });

  group('topicForDisplay', () {
    test('the machine separator never reaches the screen', () {
      expect(
        topicForDisplay(
          'Understanding the Holy Quran - Intermediate :: Lesson 2 :: '
          'finished the vocabulary list',
        ),
        'Understanding the Holy Quran - Intermediate · Lesson 2 · '
        'finished the vocabulary list',
      );
    });

    test('a hyphen inside a name is left alone', () {
      // ' - ' is part of the name here, not a separator, so it must survive.
      expect(
        topicForDisplay('Tahaarat :: Laws of Urinal - 1'),
        'Tahaarat · Laws of Urinal - 1',
      );
    });

    test('free text a teacher typed comes back untouched', () {
      const typed = 'Taqleed - first four rulings';
      expect(topicForDisplay(typed), typed);
    });

    test('empty segments are dropped rather than shown as gaps', () {
      expect(topicForDisplay('Salaat ::  :: today'), 'Salaat · today');
      expect(topicForDisplay(''), '');
    });
  });

  group('composeTopic / parseStoredTopic round-trip', () {
    test('every topic and sub-topic survives every detail shape', () {
      var checked = 0;

      for (final topic in _catalog.keys) {
        final subtopics = _catalog[topic]!;
        final selections = subtopics.isEmpty
            ? [const TopicSelection()]
            : subtopics.map((s) => TopicSelection(subtopic: s)).toList();

        // A topic with no sub-topics cannot carry a detail that itself contains
        // the separator — see the limitation pinned below.
        final details = subtopics.isEmpty
            ? _details.where((d) => !d.contains(' :: '))
            : _details;

        for (final base in selections) {
          for (final detail in details) {
            final original = TopicSelection(
              topic: topic,
              subtopic: base.subtopic,
              details: detail,
            );

            final stored = composeTopic(original, _catalog);
            expect(
              stored,
              isNotEmpty,
              reason: 'compose produced nothing for $original',
            );

            final parsed = parseStoredTopic(stored, _catalog);
            expect(
              parsed,
              isNotNull,
              reason: 'could not parse back: "$stored"',
            );
            expect(parsed!.topic, topic, reason: stored);
            expect(parsed.subtopic, base.subtopic, reason: stored);
            expect(parsed.details, detail, reason: stored);
            expect(parsed.custom, '', reason: stored);
            checked++;
          }
        }
      }

      // Guards against a fixture that silently stops covering anything.
      expect(checked, 35);
    });

    test('a topic with no sub-topics cannot carry a separator in its detail', () {
      // A known limitation, kept rather than fixed because the web form parses
      // this column the same way and the two must agree on what they read: with
      // no sub-topic in the middle, the second segment is taken for one. No
      // topic in the real catalog has zero sub-topics, so nothing stored today
      // can reach this.
      final stored = composeTopic(
        const TopicSelection(
          topic: 'Taqleed',
          details: 'see handout :: page 4',
        ),
        _catalog,
      );
      expect(stored, 'Taqleed :: see handout :: page 4');

      final parsed = parseStoredTopic(stored, _catalog)!;
      expect(parsed.subtopic, 'see handout');
      expect(parsed.details, 'page 4');
    });

    test('a detail containing the separator is rejoined, not truncated', () {
      final stored = composeTopic(
        const TopicSelection(
          topic: 'Salaat',
          subtopic: 'Daily Prayers - 1',
          details: 'a :: b :: c',
        ),
        _catalog,
      );
      expect(stored, 'Salaat :: Daily Prayers - 1 :: a :: b :: c');
      expect(parseStoredTopic(stored, _catalog)!.details, 'a :: b :: c');
    });

    test('details are trimmed on the way in', () {
      final stored = composeTopic(
        const TopicSelection(topic: 'Taqleed', details: '   spaced   '),
        _catalog,
      );
      expect(stored, 'Taqleed :: spaced');
    });
  });

  group('composeTopic', () {
    test('a topic with sub-topics composes nothing until one is chosen', () {
      expect(composeTopic(const TopicSelection(topic: 'Salaat'), _catalog), '');
    });

    test('a topic with no sub-topics composes on its own', () {
      expect(
        composeTopic(const TopicSelection(topic: 'Taqleed'), _catalog),
        'Taqleed',
      );
    });

    test('"Other" stores the custom text alone, ignoring any stale detail', () {
      expect(
        composeTopic(
          const TopicSelection(
            topic: otherTopicOption,
            custom: '  Ramadan special session  ',
            details: 'ignored',
          ),
          _catalog,
        ),
        'Ramadan special session',
      );
    });

    test('nothing selected composes to nothing', () {
      expect(composeTopic(const TopicSelection(), _catalog), '');
    });
  });

  group('parseStoredTopic on legacy " - " values', () {
    test('a sub-topic whose own name contains " - " stays whole', () {
      final parsed = parseStoredTopic('Salaat - Daily Prayers - 1', _catalog)!;
      expect(parsed.topic, 'Salaat');
      expect(parsed.subtopic, 'Daily Prayers - 1');
      expect(parsed.details, '');
    });

    test('sub-topics are matched longest-first, not shortest-first', () {
      // Shortest-first would yield subtopic 'Sujood' with detail '3'.
      final parsed = parseStoredTopic('Salaat - Sujood - 3', _catalog)!;
      expect(parsed.subtopic, 'Sujood - 3');
      expect(parsed.details, '');
    });

    test('a trailing legacy segment becomes the detail', () {
      final parsed = parseStoredTopic(
        'Salaat - Sujood - covered fully',
        _catalog,
      )!;
      expect(parsed.subtopic, 'Sujood');
      expect(parsed.details, 'covered fully');
    });

    test('a name containing " / " is matched intact', () {
      final parsed = parseStoredTopic(
        'Ghusl - Things Haraam / Makrooh for a Mujnib',
        _catalog,
      )!;
      expect(parsed.subtopic, 'Things Haraam / Makrooh for a Mujnib');
    });

    test('a bare topic name parses as that topic', () {
      final parsed = parseStoredTopic('Tahaarat', _catalog)!;
      expect(parsed.topic, 'Tahaarat');
      expect(parsed.subtopic, '');
      expect(parsed.details, '');
    });

    test('a topic with no sub-topics takes the remainder as its detail', () {
      final parsed = parseStoredTopic('Taqleed - Chapter 1', _catalog)!;
      expect(parsed.topic, 'Taqleed');
      expect(parsed.subtopic, '');
      expect(parsed.details, 'Chapter 1');
    });

    test('matching is case-insensitive, and returns the catalog spelling', () {
      final parsed = parseStoredTopic('tahaarat - kurr water', _catalog)!;
      expect(parsed.topic, 'Tahaarat');
      expect(parsed.subtopic, 'Kurr Water');
    });

    test('topics are matched longest-first', () {
      // Synthetic: a catalog where one topic name is a ' - '-joined prefix of
      // another. Shortest-first would split it as 'Wuzu' + 'Method'.
      const nested = <String, List<String>>{
        'Wuzu': ['Method'],
        'Wuzu - Method': ['Step 1'],
      };
      final parsed = parseStoredTopic('Wuzu - Method - Step 1', nested)!;
      expect(parsed.topic, 'Wuzu - Method');
      expect(parsed.subtopic, 'Step 1');
      expect(parsed.details, '');
    });
  });

  group('parseStoredTopic does not depend on the catalog for new values', () {
    test('a " :: " value parses identically against an empty catalog', () {
      const stored = 'Salaat :: Daily Prayers - 1 :: covered fully';
      final withCatalog = parseStoredTopic(stored, _catalog)!;
      final without = parseStoredTopic(stored, const {})!;
      expect(without, withCatalog);
      expect(without.topic, 'Salaat');
      expect(without.subtopic, 'Daily Prayers - 1');
      expect(without.details, 'covered fully');
    });

    test('a " :: " value survives its topic being renamed in the catalog', () {
      const stored = 'Salaat :: Sujood - 3';
      const renamed = <String, List<String>>{
        'Salaat (revised)': ['Sujood - 3'],
      };
      expect(
        parseStoredTopic(stored, renamed),
        parseStoredTopic(stored, _catalog),
      );
    });

    test('two segments resolve by whether the topic has sub-topics', () {
      expect(
        parseStoredTopic('Salaat :: Sujood', _catalog)!.subtopic,
        'Sujood',
      );
      expect(parseStoredTopic('Salaat :: Sujood', _catalog)!.details, '');

      expect(parseStoredTopic('Taqleed :: Chapter 1', _catalog)!.subtopic, '');
      expect(
        parseStoredTopic('Taqleed :: Chapter 1', _catalog)!.details,
        'Chapter 1',
      );
    });

    test('a legacy value does lose its structure without the catalog', () {
      // The documented asymmetry, pinned so it cannot change unnoticed: the
      // legacy path is the one that needs the catalog.
      expect(parseStoredTopic('Salaat - Sujood - 3', const {}), isNull);
    });
  });

  group('hydrateTopicSelection', () {
    test('unrecognised free text lands in "Other" with its text intact', () {
      const raw = 'Taqleed chapter one, in my own words';
      expect(parseStoredTopic(raw, _catalog), isNull);

      final hydrated = hydrateTopicSelection(raw, _catalog);
      expect(hydrated.topic, otherTopicOption);
      expect(hydrated.custom, raw);
      expect(hydrated.subtopic, '');
      expect(hydrated.details, '');
    });

    test('such a value round-trips back out unchanged', () {
      const raw = 'Whatever the teacher typed - in 2019';
      expect(composeTopic(hydrateTopicSelection(raw, _catalog), _catalog), raw);
    });

    test('a null or blank value hydrates to an empty selection', () {
      expect(hydrateTopicSelection(null, _catalog), const TopicSelection());
      expect(hydrateTopicSelection('   ', _catalog), const TopicSelection());
    });

    test('a topic the catalog no longer lists falls back to "Other"', () {
      // The dropdown can only show a choice it offers, so a renamed topic has
      // to keep its text somewhere editable rather than select nothing.
      const stored = 'Salaat :: Sujood';
      expect(parseStoredTopic(stored, const {})!.topic, 'Salaat');

      final hydrated = hydrateTopicSelection(stored, {
        'Salaat (revised)': const ['Sujood'],
      });
      expect(hydrated.topic, otherTopicOption);
      expect(hydrated.custom, stored);
    });

    test('a sub-topic the catalog no longer lists falls back to "Other"', () {
      final hydrated = hydrateTopicSelection('Salaat :: Qunoot', _catalog);
      expect(hydrated.topic, otherTopicOption);
      expect(hydrated.custom, 'Salaat :: Qunoot');
    });

    test('a bare topic with sub-topics hydrates with none chosen', () {
      final hydrated = hydrateTopicSelection('Salaat', _catalog);
      expect(hydrated.topic, 'Salaat');
      expect(hydrated.subtopic, '');
      expect(composeTopic(hydrated, _catalog), '');
    });

    test('a recognised value hydrates to its parsed parts', () {
      final hydrated = hydrateTopicSelection(
        'Salaat :: Sujood :: today',
        _catalog,
      );
      expect(hydrated.topic, 'Salaat');
      expect(hydrated.subtopic, 'Sujood');
      expect(hydrated.details, 'today');
    });
  });
}
