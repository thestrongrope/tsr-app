/// The guide for a class's level (#412). [guide] is HTML; a level with no guide
/// has neither it nor a [shareUrl].
class ClassGuide {
  final String? guide;
  final String? shareUrl;
  final String levelName;

  const ClassGuide({
    required this.guide,
    required this.shareUrl,
    required this.levelName,
  });

  factory ClassGuide.fromJson(Map<String, dynamic> json) => ClassGuide(
    guide: json['guide'] as String?,
    shareUrl: json['share_url'] as String?,
    levelName: json['level_name'] as String? ?? '',
  );
}

/// A guide a student or teacher can open: the slug a guide link carries and
/// the level's name (#1138).
class GuideSummary {
  final String slug;
  final String name;

  const GuideSummary({required this.slug, required this.name});

  factory GuideSummary.fromJson(Map<String, dynamic> json) =>
      GuideSummary(slug: json['slug'] as String, name: json['name'] as String);
}
