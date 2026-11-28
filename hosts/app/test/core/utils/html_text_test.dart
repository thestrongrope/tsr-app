import 'package:flutter_test/flutter_test.dart';
import 'package:the_strong_rope/core/utils/html_text.dart';

void main() {
  group('decodeHtmlEntities', () {
    test('decodes the ampersand that shows up in real video titles', () {
      // Captured from production: this title rendered literally as
      // "#Wilayat &amp; #Tab..." in the App Store screenshots.
      const encoded =
          'Har Nabi (a.s.) Ne Tabarra Kiya | #Wilayat &amp; '
          '#Tabarra';

      expect(
        decodeHtmlEntities(encoded),
        'Har Nabi (a.s.) Ne Tabarra Kiya | #Wilayat & #Tabarra',
      );
    });

    test('decodes the other named entities WordPress emits', () {
      expect(
        decodeHtmlEntities('&lt;b&gt; &quot;quoted&quot; &apos;apos&apos;'),
        '''<b> "quoted" 'apos\'''',
      );
    });

    test('decodes decimal and hex numeric references', () {
      expect(decodeHtmlEntities('Imam&#039;s'), "Imam's");
      expect(decodeHtmlEntities('Imam&#x27;s'), "Imam's");
    });

    test('does not decode twice', () {
      // The reason this is a single pass. Sequential replacement would take
      // &#38;lt; to &lt; and then to <, resurrecting markup the source
      // escaped deliberately.
      expect(decodeHtmlEntities('&#38;lt;'), '&lt;');
      expect(decodeHtmlEntities('&amp;lt;'), '&lt;');
    });

    test('leaves an unknown or malformed entity as it was', () {
      // Dropping it would silently lose characters; rendering it verbatim at
      // least shows what arrived.
      expect(decodeHtmlEntities('a &notreal; b'), 'a &notreal; b');
      expect(decodeHtmlEntities('50% off & more'), '50% off & more');
    });

    test('returns text with no ampersand untouched', () {
      const plain = 'Kaamiyaabi Ke Raaz | Akhlaaq-e-Ahle Bait';

      expect(decodeHtmlEntities(plain), same(plain));
    });

    test('handles an empty string', () {
      expect(decodeHtmlEntities(''), '');
    });
  });

  group('htmlToPlainText', () {
    test('strips tags and decodes what is left', () {
      expect(
        htmlToPlainText('<p>Mubahala &amp; Ghadir</p>'),
        'Mubahala & Ghadir',
      );
    });

    test('replaces the &nbsp; the old stripper handled', () {
      expect(htmlToPlainText('<p>one&nbsp;two</p>'), 'one two');
    });

    test('keeps escaped markup visible instead of eating it', () {
      // The reason tags are stripped before entities are decoded. Decoding
      // first would produce a real <script> tag, which the tag pass would
      // then delete — silently removing text the author meant to be read.
      expect(
        htmlToPlainText('<p>Use &lt;script&gt; carefully</p>'),
        'Use <script> carefully',
      );
    });

    test('trims the whitespace tag removal leaves behind', () {
      expect(htmlToPlainText('<div>  spaced  </div>'), 'spaced');
    });

    test('handles an empty string', () {
      expect(htmlToPlainText(''), '');
    });
  });
}
