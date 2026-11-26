import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

// The server stores a guide as the web's Quill HTML. The editor holds a Delta.
//
// Going out, the Delta goes through vsc_quill_delta_to_html, with the list
// indents handled by hand (below). Coming in, the stock HTML-to-Delta package
// merges consecutive paragraphs and ignores `ql-indent-N`, which is how the web
// stores nearly everything, so the small subset of HTML the web editor writes
// is read here: paragraphs, headings, lists, blockquotes, bold, italic,
// underline, strike and links.

final _indentClass = RegExp(r'ql-indent-(\d+)');
const _headings = {'h1': 1, 'h2': 2, 'h3': 3, 'h4': 4, 'h5': 5, 'h6': 6};

/// The editor's content for a guide's stored HTML.
Document guideHtmlToDocument(String html) {
  final ops = _HtmlReader().read(html_parser.parse(html).body!);
  // A Document cannot be built from no ops (a level with no guide yet).
  return ops.isEmpty ? Document() : Document.fromJson(ops);
}

class _HtmlReader {
  final _ops = <Map<String, dynamic>>[];

  /// The inline content of the line being read, until its block ends.
  final _line = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> read(dom.Element body) {
    _children(body, const {}, listDepth: 0, listType: null);
    _endLine({}); // anything left over at the top level is a paragraph
    return _ops;
  }

  void _children(
    dom.Node parent,
    Map<String, dynamic> inline, {
    required int listDepth,
    required String? listType,
  }) {
    for (final node in parent.nodes) {
      if (node is dom.Text) {
        _text(node.text, inline);
      } else if (node is dom.Element) {
        _element(node, inline, listDepth: listDepth, listType: listType);
      }
    }
  }

  void _element(
    dom.Element element,
    Map<String, dynamic> inline, {
    required int listDepth,
    required String? listType,
  }) {
    final tag = element.localName;
    switch (tag) {
      case 'br':
        if (_line.isNotEmpty) _endLine({});
      case 'ul' || 'ol':
        _endLine({}); // a list starts a new line
        _children(
          element,
          inline,
          listDepth: listDepth + 1,
          listType: tag == 'ol' ? 'ordered' : 'bullet',
        );
      case 'li':
        final indent = _indentClass.firstMatch(element.className);
        _block(element, inline, listDepth: listDepth, listType: listType, {
          'list': listType ?? 'bullet',
          if (indent != null) 'indent': int.parse(indent.group(1)!),
          if (indent == null && listDepth > 1) 'indent': listDepth - 1,
        });
      case 'p' ||
          'blockquote' ||
          'pre' ||
          'h1' ||
          'h2' ||
          'h3' ||
          'h4' ||
          'h5' ||
          'h6':
        _block(element, inline, listDepth: listDepth, listType: listType, {
          if (_headings.containsKey(tag)) 'header': _headings[tag],
          if (tag == 'blockquote') 'blockquote': true,
          if (tag == 'pre') 'code-block': 'plain',
        });
      default:
        final next = {...inline, ..._inlineAttributes(element)};
        _children(element, next, listDepth: listDepth, listType: listType);
    }
  }

  /// A block element is one line, closed with its block attributes. A nested
  /// list inside a list item ends the item's own line first.
  void _block(
    dom.Element element,
    Map<String, dynamic> inline,
    Map<String, dynamic> blockAttributes, {
    required int listDepth,
    required String? listType,
  }) {
    _endLine({});
    for (final node in element.nodes) {
      if (node is dom.Element &&
          (node.localName == 'ul' || node.localName == 'ol')) {
        if (_line.isNotEmpty || !blockAttributes.containsKey('list')) {
          _endLine(blockAttributes, block: true);
        }
        _element(node, inline, listDepth: listDepth, listType: listType);
      } else if (node is dom.Element) {
        _element(node, inline, listDepth: listDepth, listType: listType);
      } else if (node is dom.Text) {
        _text(node.text, inline);
      }
    }
    if (_line.isNotEmpty || element.querySelector('ul, ol') == null) {
      _endLine(blockAttributes, block: true);
    }
  }

  Map<String, dynamic> _inlineAttributes(dom.Element element) {
    switch (element.localName) {
      case 'strong' || 'b':
        return {'bold': true};
      case 'em' || 'i':
        return {'italic': true};
      case 'u':
        return {'underline': true};
      case 's' || 'strike' || 'del':
        return {'strike': true};
      case 'a':
        final href = element.attributes['href'];
        return href == null ? {} : {'link': href};
      default:
        return {};
    }
  }

  void _text(String text, Map<String, dynamic> inline) {
    // Source line breaks are not content in HTML.
    final clean = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
    if (clean.isEmpty) return;
    // Spacing between blocks is not content either.
    if (_line.isEmpty && clean.trim().isEmpty) return;
    _line.add({
      'insert': clean,
      if (inline.isNotEmpty) 'attributes': Map<String, dynamic>.from(inline),
    });
  }

  /// Closes the line being read. A block always ends its line, even an empty
  /// one (a blank line); anything else only does if there is content.
  void _endLine(Map<String, dynamic> blockAttributes, {bool block = false}) {
    if (!block && _line.isEmpty && blockAttributes.isEmpty) return;
    _ops.addAll(_line);
    _line.clear();
    _ops.add({
      'insert': '\n',
      if (blockAttributes.isNotEmpty) 'attributes': blockAttributes,
    });
  }
}

/// The HTML to store for what the editor holds.
String guideDocumentToHtml(Document document) {
  // Convert without the list indents, so the lists come out flat, then put the
  // indents back as classes on the <li> elements, which are in the same order.
  final indents = <int>[];
  final ops = <Map<String, dynamic>>[];
  for (final op in List<Map<String, dynamic>>.from(
    document.toDelta().toJson(),
  )) {
    final attributes = op['attributes'];
    if (op['insert'] == '\n' &&
        attributes is Map &&
        attributes['list'] != null) {
      indents.add((attributes['indent'] as int?) ?? 0);
      ops.add({
        ...op,
        'attributes': Map<String, dynamic>.from(attributes)..remove('indent'),
      });
    } else {
      ops.add(op);
    }
  }

  // One element per line, as the web editor writes it: the default merges
  // neighbouring headings and paragraphs into one element joined by <br>.
  final options = ConverterOptions.forEmail()
    ..multiLineHeader = false
    ..multiLineParagraph = false
    ..multiLineBlockquote = false;
  final html = QuillDeltaToHtmlConverter(ops, options).convert();
  final body = html_parser.parse(html).body!;

  final items = body.querySelectorAll('li');
  if (items.length == indents.length) {
    for (var i = 0; i < items.length; i++) {
      if (indents[i] > 0) items[i].classes.add('ql-indent-${indents[i]}');
    }
  }

  // The editor always ends on an empty line; it is not part of the guide.
  while (body.nodes.isNotEmpty && _isBlankParagraph(body.nodes.last)) {
    body.nodes.removeLast();
  }
  return body.innerHtml;
}

bool _isBlankParagraph(dom.Node node) =>
    node is dom.Element &&
    node.localName == 'p' &&
    node.text.trim().isEmpty &&
    node.children.every((c) => c.localName == 'br');
