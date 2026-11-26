import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/wordpress/models/publication.dart';
import 'package:the_strong_rope/features/wordpress/services/tsr_web_service.dart';

/// Answers every request with [body], so the service's parsing runs against
/// a payload shaped like production without touching the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Map<String, dynamic> body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TsrWebService _serviceAnswering(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://thestrongrope.com'))
    ..httpClientAdapter = adapter;
  return TsrWebService(dio: dio);
}

void main() {
  group('Publication links', () {
    test('a reading page is what a tap opens, with the file second', () {
      const p = Publication(
        title: 'A Gift for the Youth',
        file: 'https://thestrongrope.com/downloads/books/gift.pdf',
        readOnlineUrl: 'https://thestrongrope.com/a-gift-for-the-youth',
      );

      expect(p.primaryUrl, 'https://thestrongrope.com/a-gift-for-the-youth');
      expect(
        p.secondaryUrl,
        'https://thestrongrope.com/downloads/books/gift.pdf',
      );
    });

    test('a file alone is what a tap opens, with nothing second', () {
      const p = Publication(
        title: 'Dajjaal',
        file: 'https://thestrongrope.com/downloads/books/dajjaal.pdf',
      );

      expect(
        p.primaryUrl,
        'https://thestrongrope.com/downloads/books/dajjaal.pdf',
      );
      expect(p.secondaryUrl, isNull);
    });

    test('a reading page alone is what a tap opens, with nothing second', () {
      const p = Publication(
        title: 'The City of Miracles',
        readOnlineUrl: 'https://thestrongrope.com/the-city-of-miracles',
      );

      expect(p.primaryUrl, 'https://thestrongrope.com/the-city-of-miracles');
      expect(p.secondaryUrl, isNull);
    });
  });

  group('Publication.displaySize', () {
    test('shows a size the website knows', () {
      expect(
        const Publication(title: 't', size: '7.2 MB').displaySize,
        '7.2 MB',
      );
    });

    test(
      'hides the website\'s dash for an unknown size, and a missing one',
      () {
        expect(const Publication(title: 't', size: '—').displaySize, isNull);
        expect(const Publication(title: 't', size: '  ').displaySize, isNull);
        expect(const Publication(title: 't').displaySize, isNull);
      },
    );
  });

  group('TsrWebService.getPublications', () {
    test('reads every item and resolves its links against the site', () async {
      // Shapes copied from the live /api/v1/publications response.
      final adapter = _FakeAdapter({
        'success': true,
        'data': [
          {
            'title': 'A Gift for the Youth',
            'summary': 'Focuses on early marriage.',
            'type': 'PDF',
            'size': '7.2 MB',
            'updated': 'Feb 15, 2026',
            'language': 'English',
            'file': '/downloads/books/a-gift-for-the-youth-branded.pdf',
            'readOnlineUrl': '/a-gift-for-the-youth',
            'downloadOnly': false,
          },
          {
            'title': 'Dua Faakshif',
            'updated': 'Jul 08, 2026',
            'language': 'Multilingual',
            'readOnlineUrl': '/duas/dua-faakshif.html',
            'downloadOnly': false,
          },
        ],
      });

      final list = await _serviceAnswering(adapter).getPublications();

      expect(adapter.lastRequest!.path, '/api/v1/publications');
      expect(list, hasLength(2));
      expect(list[0].title, 'A Gift for the Youth');
      expect(list[0].summary, 'Focuses on early marriage.');
      expect(list[0].language, 'English');
      expect(list[0].updated, 'Feb 15, 2026');
      expect(
        list[0].file,
        'https://thestrongrope.com/downloads/books/a-gift-for-the-youth-branded.pdf',
      );
      expect(
        list[0].readOnlineUrl,
        'https://thestrongrope.com/a-gift-for-the-youth',
      );
      expect(list[1].file, isNull);
      expect(
        list[1].primaryUrl,
        'https://thestrongrope.com/duas/dua-faakshif.html',
      );
    });

    test('leaves an absolute link as it is', () async {
      final adapter = _FakeAdapter({
        'success': true,
        'data': [
          {'title': 't', 'file': 'https://cdn.example.org/x.pdf'},
        ],
      });

      final list = await _serviceAnswering(adapter).getPublications();

      expect(list.single.file, 'https://cdn.example.org/x.pdf');
    });

    test(
      'throws on a failure envelope instead of returning an empty list',
      () async {
        final adapter = _FakeAdapter({
          'success': false,
          'error': {'code': 'INTERNAL_ERROR', 'message': 'boom'},
        });

        expect(
          _serviceAnswering(adapter).getPublications(),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}
