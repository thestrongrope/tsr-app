/// A parent-child link record (#633).
class ParentLinkModel {
  final int id;
  final int parentToken;
  final int childToken;
  final String childName;
  final String relationship;
  final String status;
  final String source;
  final String createdAt;

  /// Who created the link, by display name ("Invite link" for an accepted
  /// invite). The server never sends the creator's internal id.
  final String createdByName;
  final String? activatedAt;
  final String? revokedAt;

  const ParentLinkModel({
    required this.id,
    required this.parentToken,
    required this.childToken,
    required this.childName,
    required this.relationship,
    required this.status,
    required this.source,
    required this.createdAt,
    this.createdByName = '',
    this.activatedAt,
    this.revokedAt,
  });

  bool get isActive => status == 'active';

  String get relationshipDisplay {
    if (relationship.isEmpty) return 'Guardian';
    return relationship[0].toUpperCase() + relationship.substring(1).toLowerCase();
  }

  factory ParentLinkModel.fromJson(Map<String, dynamic> json) {
    return ParentLinkModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      parentToken: (json['parent_token'] as num?)?.toInt() ?? 0,
      childToken: (json['child_token'] as num?)?.toInt() ?? 0,
      childName: json['child_name'] as String? ?? 'Child #${json['child_token']}',
      relationship: json['relationship'] as String? ?? 'guardian',
      status: json['status'] as String? ?? 'active',
      source: json['source'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      createdByName: json['created_by_name'] as String? ?? '',
      activatedAt: json['activated_at'] as String?,
      revokedAt: json['revoked_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_token': parentToken,
    'child_token': childToken,
    'child_name': childName,
    'relationship': relationship,
    'status': status,
    'source': source,
    'created_at': createdAt,
    'created_by_name': createdByName,
    'activated_at': activatedAt,
    'revoked_at': revokedAt,
  };
}
