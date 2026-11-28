import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_lecture.dart';

// `GET /api/v1/lectures/search` on thestrongrope.com (#557): the TSR YouTube
// lectures, with the chapters that matched the query.

Map<String, dynamic> _lecture({List<Map<String, dynamic>>? matched}) => {
  'slug': 'tauheed-basics',
  'title': 'Tauheed Basics',
  'url': 'https://www.youtube.com/watch?v=abc',
  'thumbnail': 'https://i.ytimg.com/vi/abc/hqdefault.jpg',
  'chapters': [
    {
      'start_sec': 0,
      'title': 'Intro',
      'url': 'https://www.youtube.com/watch?v=abc&t=0',
    },
    {
      'start_sec': 300,
      'title': 'Unity',
      'url': 'https://www.youtube.com/watch?v=abc&t=300',
    },
  ],
  'matchedChapters': matched ?? <Map<String, dynamic>>[],
  'score': 4.2,
};

void main() {
  test('a lecture parses with its chapters', () {
    final lecture = TsrLecture.fromJson(_lecture());

    expect(lecture.title, 'Tauheed Basics');
    expect(lecture.url, 'https://www.youtube.com/watch?v=abc');
    expect(lecture.chapters.map((c) => c.title), ['Intro', 'Unity']);
    expect(lecture.chapters.last.startSec, 300);
  });

  test('a result opens at the chapter that matched, else at the start', () {
    final matched = TsrLecture.fromJson(
      _lecture(
        matched: [
          {
            'start_sec': 300,
            'title': 'Unity',
            'url': 'https://www.youtube.com/watch?v=abc&t=300',
          },
        ],
      ),
    );
    final plain = TsrLecture.fromJson(_lecture());

    expect(matched.openUrl, 'https://www.youtube.com/watch?v=abc&t=300');
    expect(plain.openUrl, 'https://www.youtube.com/watch?v=abc');
  });

  test('a lecture with no chapters at all still parses', () {
    final lecture = TsrLecture.fromJson({
      'slug': 's',
      'title': 'T',
      'url': 'https://www.youtube.com/watch?v=x',
    });

    expect(lecture.chapters, isEmpty);
    expect(lecture.thumbnail, '');
    expect(lecture.openUrl, 'https://www.youtube.com/watch?v=x');
  });

  test('the search answer parses its results and total', () {
    final search = TsrLectureSearch.fromJson({
      'results': [_lecture()],
      'total': 31,
      'query': 'tauheed',
    });

    expect(search.results, hasLength(1));
    expect(search.total, 31);
  });

  test(
    'a body that is not a lecture search throws so the group can say so',
    () {
      expect(() => TsrLectureSearch.fromJson('nope'), throwsFormatException);
      expect(
        () => TsrLectureSearch.fromJson({'total': 3}),
        throwsFormatException,
      );
    },
  );
}
