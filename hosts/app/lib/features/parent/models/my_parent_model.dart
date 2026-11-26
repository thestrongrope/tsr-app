/// A parent linked to the authenticated child (#633).
class MyParentModel {
  final int id;
  final int parentToken;
  final String parentName;
  final String relationship;
  final String status;
  final String source;
  final String createdAt;

  const MyParentModel({
    required this.id,
    required this.parentToken,
    required this.parentName,
    required this.relationship,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  String get relationshipDisplay {
    if (relationship.isEmpty) return 'Guardian';
    return relationship[0].toUpperCase() + relationship.substring(1).toLowerCase();
  }

  factory MyParentModel.fromJson(Map<String, dynamic> json) {
    return MyParentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parentToken: (json['parent_token'] as num?)?.toInt() ?? 0,
      parentName: json['parent_name'] as String? ?? 'Parent #${json['parent_token']}',
      relationship: json['relationship'] as String? ?? 'guardian',
      status: json['status'] as String? ?? 'active',
      source: json['source'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_token': parentToken,
    'parent_name': parentName,
    'relationship': relationship,
    'status': status,
    'source': source,
    'created_at': createdAt,
  };
}
