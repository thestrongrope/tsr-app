/// Parsing for the timestamps the mobile API returns.
///
/// The API emits naive values — `2026-09-01T10:15:00`, no `Z` and no offset —
/// and those values are UTC (`current_timestamp` on a UTC server). Dart's
/// `DateTime.parse` reads a string with no designator as **local** time, so on
/// an IST handset every such timestamp lands 5½ hours out. That is the
/// dangerous kind of wrong: "requested 3 days ago" still reads plausibly.
///
/// This is API-wide, not specific to one endpoint — `api_cast_value()` does a
/// bare space-to-`T` replace for every datetime column. Other features still
/// use `DateTime.parse` directly and carry the same latent bug.
library;

/// Matches a trailing `Z` or a numeric offset such as `+05:30` or `-0530`.
final RegExp _timeZoneDesignator = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

final RegExp _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Parses an API timestamp as UTC, whether or not it carries a designator.
///
/// Returns null for null, empty and unparseable input rather than throwing —
/// a missing or malformed date should render as "unknown", not crash a screen.
DateTime? parseApiDateTime(String? value) {
  if (value == null) return null;

  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  // Only assume UTC where the server left the zone off. If the API is later
  // fixed to emit RFC 3339, the designator is honoured and this keeps working.
  final withZone = _timeZoneDesignator.hasMatch(trimmed)
      ? trimmed
      : '${trimmed}Z';

  return DateTime.tryParse(withZone)?.toUtc();
}

/// [parseApiDateTime] in the member's own time zone, for showing and for
/// "x ago" sums. Null for null, empty and unparseable input.
///
/// Not for a value with no time of day (a conduction date, a registration
/// date): that is a calendar date, and converting it could move it a day.
DateTime? parseApiLocalDateTime(String? value) =>
    parseApiDateTime(value)?.toLocal();

/// A server time as "yyyy-MM-dd HH:mm" in the member's own time zone, for
/// display. A value that cannot be read is returned as sent, so the member
/// still sees something. Null and empty give an empty string. A date with no
/// time of day is returned unchanged, in every time zone.
String formatApiLocalDateTime(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  if (_dateOnly.hasMatch(value.trim())) return value.trim();
  final local = parseApiLocalDateTime(value);
  if (local == null) return value;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
