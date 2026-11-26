/// A class level that can have a guide (#417).
class GuideLevel {
  final int id;
  final String name;

  const GuideLevel({required this.id, required this.name});

  factory GuideLevel.fromJson(Map<String, dynamic> json) =>
      GuideLevel(id: json['id'] as int, name: json['name'] as String);
}

/// A level's guide as the editor starts from it: [guide] is the stored HTML,
/// null for a level whose guide was never written.
class EditableGuide {
  final String? guide;
  final String levelName;

  const EditableGuide({required this.guide, required this.levelName});

  factory EditableGuide.fromJson(Map<String, dynamic> json) => EditableGuide(
    guide: json['guide'] as String?,
    levelName: json['level_name'] as String? ?? '',
  );
}
