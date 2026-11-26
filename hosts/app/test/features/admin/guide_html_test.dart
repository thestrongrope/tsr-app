import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:the_strong_rope/features/admin/models/guide_html.dart';

/// The editor holds a Delta; the server stores the web's Quill HTML. These
/// pin the two conversions at the edges, above all the indented list items the
/// stock converter drops (#417).
void main() {
  String roundTrip(String html) =>
      guideDocumentToHtml(guideHtmlToDocument(html));

  String textOf(String html) =>
      html_parser.parse(html).body!.text.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// The indent of each line, in order (null where there is none).
  List<Object?> indentsOf(String html) => [
    for (final op in guideHtmlToDocument(html).toDelta().toList())
      if (op.data == '\n') op.attributes?['indent'],
  ];

  test('indented list items come in as indented, not flat', () {
    const html =
        '<ul><li>a</li><li class="ql-indent-1">b</li>'
        '<li class="ql-indent-2">c</li><li>d</li></ul>';

    expect(indentsOf(html).take(4), [null, 1, 2, null]);
  });

  test('indented items are written back in the web editor\'s flat form', () {
    const html =
        '<ul><li>a</li><li class="ql-indent-1">b</li>'
        '<li class="ql-indent-2">c</li><li>d</li></ul>';

    final back = roundTrip(html);

    expect(back, contains('<li class="ql-indent-1">b</li>'));
    expect(back, contains('<li class="ql-indent-2">c</li>'));
    expect(back, isNot(contains('<ul><li>a<ul>')), reason: 'not nested');
    expect(html_parser.parse(back).querySelectorAll('ul').length, 1);
  });

  test('numbered lists keep their indent too', () {
    const html = '<ol><li>one</li><li class="ql-indent-1">sub</li></ol>';

    final back = roundTrip(html);

    expect(back, contains('<ol>'));
    expect(back, contains('<li class="ql-indent-1">sub</li>'));
  });

  test('a guide keeps its text, headings, links and emphasis', () {
    const html =
        '<h1>Miqdad</h1><h2>Subjects</h2>'
        '<p>Read the <a href="https://drive.google.com/file/d/1/view" '
        'target="_blank">Syllabus</a>&nbsp;first, then <strong>MCQ</strong> '
        'and <em>notes</em> &amp; more.</p>'
        '<ol><li>Quran</li><li>Aqaed</li></ol>';

    final back = roundTrip(html);
    final doc = html_parser.parse(back);

    expect(textOf(back), textOf(html));
    expect(doc.querySelector('h1')!.text, 'Miqdad');
    expect(doc.querySelector('h2')!.text, 'Subjects');
    expect(
      doc.querySelector('a')!.attributes['href'],
      'https://drive.google.com/file/d/1/view',
    );
    expect(doc.querySelector('strong')!.text, 'MCQ');
    expect(doc.querySelector('em')!.text, 'notes');
    expect(doc.querySelectorAll('ol > li').length, 2);
  });

  test('an unchanged guide has no indent where it had none', () {
    expect(
      indentsOf('<ul><li>a</li><li>b</li></ul>').whereType<int>(),
      isEmpty,
    );
  });

  test('an empty or blank guide opens as an empty document', () {
    for (final html in ['', '  \n ']) {
      expect(
        guideHtmlToDocument(html).toPlainText().trim(),
        isEmpty,
        reason: html,
      );
    }
  });

  test('a list that starts already indented keeps its text and its indent', () {
    const html =
        '<p>Intro</p><ul><li class="ql-indent-1">first</li>'
        '<li class="ql-indent-1">second</li></ul><p>After</p>';

    final back = roundTrip(html);

    expect(textOf(back), textOf(html));
    expect(back, contains('<li class="ql-indent-1">first</li>'));
    expect(back, contains('<li class="ql-indent-1">second</li>'));
    expect(
      html_parser.parse(back).querySelectorAll('li').length,
      2,
      reason: 'no empty bullet added',
    );
  });

  test('indent is kept when an item skips a level', () {
    const html =
        '<ul><li>a</li><li class="ql-indent-2">deep</li><li>b</li></ul>';

    final back = roundTrip(html);

    expect(textOf(back), textOf(html));
    expect(back, contains('<li class="ql-indent-2">deep</li>'));
    expect(html_parser.parse(back).querySelectorAll('li').length, 3);
  });

  test('saving again and again does not change the guide', () {
    const html =
        '<h1>Miqdad</h1><p>Intro</p><ul><li>a</li>'
        '<li class="ql-indent-1">b</li></ul><p>End</p>';

    final once = roundTrip(html);

    expect(roundTrip(once), once);
    expect(roundTrip(roundTrip(once)), once);
  });

  test('consecutive paragraphs and headings stay separate lines', () {
    const html =
        '<h3>Age</h3><h3>Duration</h3><p>One</p><p>Two <a href="https://x">link</a></p>'
        '<p>Three</p><p><br></p><p>Four</p>';

    final back = roundTrip(html);
    final doc = html_parser.parse(back);

    expect(doc.querySelectorAll('h3').length, 2);
    expect(doc.querySelectorAll('p').map((p) => p.text).toList(), [
      'One',
      'Two link',
      'Three',
      '',
      'Four',
    ]);
    expect(roundTrip(back), back);
  });

  test('blank lines under headings and paragraphs are kept', () {
    const html = '<h1>Title</h1><h4><br></h4><p>Text</p><p><br></p><p>More</p>';

    final back = roundTrip(html);

    expect(back, contains('<h4><br></h4>'));
    expect(back, contains('<p><br></p>'));
    expect(roundTrip(back), back);
  });

  test(
    'bold, italic and underline survive, and a link keeps only its address',
    () {
      const html =
          '<p><strong>b</strong> <em>i</em> <u>u</u> '
          '<a href="https://x/y" target="_blank" style="color: red">l</a></p>';

      final doc = html_parser.parse(roundTrip(html));

      expect(doc.querySelector('strong')!.text, 'b');
      expect(doc.querySelector('em')!.text, 'i');
      expect(doc.querySelector('u')!.text, 'u');
      expect(doc.querySelector('a')!.attributes['href'], 'https://x/y');
    },
  );
}
