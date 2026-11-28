import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/admin/models/standard_mcqs.dart';

void main() {
  test('the sources parse into languages and levels', () {
    final sources = StandardMcqSources.fromJson({
      'languages': [
        {'id': 1, 'name': 'English'},
        {'id': 2, 'name': 'Urdu'},
      ],
      'levels': [
        {'id': 1, 'name': 'Abuzar'},
      ],
    });

    expect(sources.languages.map((l) => l.name), ['English', 'Urdu']);
    expect(sources.languages.map((l) => l.id), [1, 2]);
    expect(sources.levels.single.name, 'Abuzar');
  });

  test('a body that is not the sources throws', () {
    expect(() => StandardMcqSources.fromJson([]), throwsFormatException);
  });

  test('an updated pair carries its quiz count, a failed one its reason', () {
    final results = StandardMcqResult.listFromJson({
      'results': [
        {
          'language_id': 1,
          'level_id': 1,
          'language': 'English',
          'level': 'Abuzar',
          'status': 'updated',
          'quizzes': 12,
        },
        {
          'language_id': 2,
          'level_id': 1,
          'language': 'Urdu',
          'level': 'Abuzar',
          'status': 'failed',
          'reason': 'Not updated: another sheet could not be read',
        },
      ],
    });

    expect(results[0].updated, isTrue);
    expect(results[0].quizzes, 12);
    expect(results[0].reason, isNull);
    expect(results[1].updated, isFalse);
    expect(results[1].quizzes, isNull);
    expect(results[1].reason, contains('could not be read'));
  });

  test('a body without results throws', () {
    expect(
      () => StandardMcqResult.listFromJson({'detail': 'x'}),
      throwsFormatException,
    );
  });
}
