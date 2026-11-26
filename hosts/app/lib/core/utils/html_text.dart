/// Decoding for the HTML-encoded text the TSR web API returns.
///
/// WordPress stores post titles with their entities already encoded, and
/// `/api/v1` hands them over untouched. A YouTube title such as
/// `Har Nabi (a.s.) Ne Tabarra Kiya | #Wilayat & #Tabarra` arrives as
/// `... #Wilayat &amp; #Tabarra`, and Flutter's `Text` renders that literally
/// — there is no HTML layer to undo it. The ampersand is the one that shows
/// up in practice because titles are written in prose; the rest are here so a
/// quote or an apostrophe cannot produce the same surprise later.
///
/// **Scope.** [decodeHtmlEntities] is applied at the API boundary to the two
/// *titles* — `TsrYouTubeVideo.title` and `TsrArticle.title` — which are plain
/// text that merely arrives encoded. Markup is not decoded there:
///
///   - `TsrArticle.content` is HTML by design and is left entirely alone.
///   - `TsrArticle.excerpt` is HTML too, but every screen renders it as plain
///     text, so it goes through [htmlToPlainText] at the render site. It must
///     not be decoded at the boundary — see that function for why.
///   - `TsrCategory.title` and `TsrTag.name` carry the same encoding and have
///     shown no failure yet.
///
/// Widen this deliberately rather than by reflex.
///
/// Deliberately not the `html` package: this needs a handful of named
/// entities and a numeric form, and pulling a parser in to get them would be
/// a dependency with far more surface than the problem.
library;

/// One named entity or one numeric character reference, decimal (`&#39;`) or
/// hex (`&#x27;`).
///
/// Everything is matched in a **single** pass on purpose. Replacing entity by
/// entity in sequence lets one substitution feed the next: `&#38;lt;` decodes
/// to `&lt;`, which a later pass would then turn into `<`, resurrecting markup
/// the source had escaped twice. Matching once and substituting once cannot.
final RegExp _entity = RegExp(r'&(?:#(x?)([0-9a-fA-F]+)|([a-zA-Z]+));');

/// The named entities WordPress actually emits in titles.
const Map<String, String> _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
};

/// Decodes the HTML entities in [value], leaving everything else alone.
///
/// Returns the input unchanged when it carries no `&`, which is the common
/// case and keeps this off the hot path for most titles.
String decodeHtmlEntities(String value) {
  if (!value.contains('&')) return value;

  return value.replaceAllMapped(_entity, (match) {
    final name = match.group(3);
    if (name != null) {
      // An unrecognised name is left exactly as it was: a mangled or unknown
      // entity reads better as itself than as a dropped character.
      return _namedEntities[name.toLowerCase()] ?? match.group(0)!;
    }

    final radix = match.group(1)!.isEmpty ? 10 : 16;
    final code = int.tryParse(match.group(2)!, radix: radix);
    if (code == null || code < 0 || code > 0x10FFFF) return match.group(0)!;

    return String.fromCharCode(code);
  });
}

/// Matches an HTML tag.
final RegExp _tag = RegExp(r'<[^>]*>');

/// Renders an HTML fragment as the plain text a `Text` widget should show.
///
/// **Tags first, entities second, and the order is load-bearing.** Decoding
/// first would turn an escaped `&lt;script&gt;` — text the author intended the
/// reader to *see* — into a real `<script>` tag, which the tag pass would then
/// delete. Stripping first means anything still escaped afterwards was never
/// markup, so decoding it is safe.
///
/// That is also why `TsrArticle.excerpt` is not decoded at the API boundary
/// the way the titles are: a boundary decode runs before any stripper, which
/// is exactly the unsafe order.
///
/// Consolidates three strippers that had drifted apart — one handled `&nbsp;`
/// and nothing else, one stripped tags only, and two screens rendered the raw
/// fragment.
String htmlToPlainText(String html) {
  return decodeHtmlEntities(html.replaceAll(_tag, '')).trim();
}
