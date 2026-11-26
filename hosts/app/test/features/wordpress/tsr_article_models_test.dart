import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/features/wordpress/models/tsr_article.dart';

void main() {
  group('TsrYouTubeVideo.fromJson', () {
    test('decodes the title, so no screen has to', () {
      // Covers the wiring, not the helper: decodeHtmlEntities has its own
      // tests, but nothing else proves the @JsonKey actually reaches the
      // generated parser. Payload shape and title are from production.
      final video = TsrYouTubeVideo.fromJson(const {
        'id': '1',
        'videoId': 'abc123',
        'title': 'Har Nabi (a.s.) Ne Tabarra Kiya | #Wilayat &amp; #Tabarra',
        'youtubeLink': 'https://youtu.be/abc123',
      });

      expect(
        video.title,
        'Har Nabi (a.s.) Ne Tabarra Kiya | #Wilayat & #Tabarra',
      );
    });

    test('leaves a title with nothing to decode alone', () {
      final video = TsrYouTubeVideo.fromJson(const {
        'id': '2',
        'videoId': 'def456',
        'title': 'Kaamiyaabi Ke Raaz | Akhlaaq-e-Ahle Bait',
        'youtubeLink': 'https://youtu.be/def456',
      });

      expect(video.title, 'Kaamiyaabi Ke Raaz | Akhlaaq-e-Ahle Bait');
    });
  });

  group('TsrArticle.fromJson', () {
    test('decodes the title', () {
      final article = TsrArticle.fromJson(const {
        'slug': 'mubahala-and-ghadir',
        'title': 'Enemies Bowed at Mubahala &amp; Muslims Rebelled at Ghadir',
      });

      expect(
        article.title,
        'Enemies Bowed at Mubahala & Muslims Rebelled at Ghadir',
      );
    });

    test('leaves content alone, because it is markup by design', () {
      // The dividing line for this fix. Decoding content would turn escaped
      // examples back into live tags and corrupt the article body.
      final article = TsrArticle.fromJson(const {
        'slug': 'escaped-markup',
        'title': 'Escaped markup',
        'content': '<p>Use &lt;strong&gt; for emphasis &amp; not &lt;b&gt;</p>',
      });

      expect(
        article.content,
        '<p>Use &lt;strong&gt; for emphasis &amp; not &lt;b&gt;</p>',
      );
    });
  });
}
