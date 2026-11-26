// `GET /api/v1/lectures/search` on thestrongrope.com (#557): the TSR YouTube
// lectures, searched on the website's own index. A result carries the chapters
// that matched the query, so a tap can open the video where it matched.
//
// Plain Dart rather than generated code: it is read in one place and the
// website's fields beyond these are not used.

/// One chapter of a lecture, with a link that starts the video there.
class TsrLectureChapter {
  const TsrLectureChapter({
    required this.title,
    required this.startSec,
    required this.url,
  });

  final String title;
  final int startSec;
  final String url;

  factory TsrLectureChapter.fromJson(Map<String, dynamic> json) =>
      TsrLectureChapter(
        title: json['title'] as String? ?? '',
        startSec: (json['start_sec'] as num?)?.toInt() ?? 0,
        url: json['url'] as String? ?? '',
      );
}

/// A lecture found by a search.
class TsrLecture {
  const TsrLecture({
    required this.slug,
    required this.title,
    required this.url,
    required this.thumbnail,
    required this.chapters,
    required this.matchedChapters,
  });

  final String slug;
  final String title;

  /// The video itself.
  final String url;
  final String thumbnail;
  final List<TsrLectureChapter> chapters;

  /// The chapters that matched the query, best first.
  final List<TsrLectureChapter> matchedChapters;

  /// Where a tap should go: the chapter that matched, else the start.
  String get openUrl =>
      matchedChapters.isNotEmpty && matchedChapters.first.url.isNotEmpty
      ? matchedChapters.first.url
      : url;

  factory TsrLecture.fromJson(Map<String, dynamic> json) {
    List<TsrLectureChapter> chapters(String key) => [
      for (final c in json[key] as List? ?? const [])
        if (c is Map<String, dynamic>) TsrLectureChapter.fromJson(c),
    ];
    return TsrLecture(
      slug: json['slug'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      chapters: chapters('chapters'),
      matchedChapters: chapters('matchedChapters'),
    );
  }
}

/// The answer to a lectures search.
class TsrLectureSearch {
  const TsrLectureSearch({required this.results, required this.total});

  final List<TsrLecture> results;

  /// How many lectures matched in all, not only those returned.
  final int total;

  /// Throws [FormatException] when [data] is not a lectures search answer.
  factory TsrLectureSearch.fromJson(dynamic data) {
    if (data is! Map<String, dynamic> || data['results'] is! List) {
      throw const FormatException('lectures search: unexpected response');
    }
    return TsrLectureSearch(
      results: [
        for (final r in data['results'] as List)
          if (r is Map<String, dynamic>) TsrLecture.fromJson(r),
      ],
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }
}
