import 'package:freezed_annotation/freezed_annotation.dart';

part 'publication.freezed.dart';
part 'publication.g.dart';

/// A TSR publication, as the website's /api/v1/publications lists it.
///
/// [updated] is the website's display string ("Feb 15, 2026"), shown as sent.
/// [file] and [readOnlineUrl] arrive site-relative; TsrWebService resolves them
/// to full URLs. Every item has at least one of the two.
@freezed
sealed class Publication with _$Publication {
  const Publication._();

  const factory Publication({
    required String title,
    String? summary,
    String? type,
    String? size,
    String? updated,
    String? language,
    String? file,
    String? readOnlineUrl,
  }) = _Publication;

  factory Publication.fromJson(Map<String, dynamic> json) =>
      _$PublicationFromJson(json);

  /// What a tap opens: the reading page when there is one, else the file.
  String? get primaryUrl => readOnlineUrl ?? file;

  /// The file, offered separately only when the tap opens a reading page.
  String? get secondaryUrl => readOnlineUrl != null ? file : null;

  /// The size, or null when the website does not know it (it sends "—").
  String? get displaySize {
    final s = size?.trim();
    if (s == null || s.isEmpty || s == '—') return null;
    return s;
  }
}
