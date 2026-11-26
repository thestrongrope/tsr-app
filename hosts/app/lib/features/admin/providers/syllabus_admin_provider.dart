import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../classes/models/syllabus_model.dart';

/// Model for admin syllabus item
class AdminSyllabusItem {
  final int id;
  final int levelId;
  final String subjectName;
  final String? description;
  final String linkType;
  final String url;
  final int sortOrder;
  final bool isActive;

  AdminSyllabusItem({
    required this.id,
    required this.levelId,
    required this.subjectName,
    this.description,
    required this.linkType,
    required this.url,
    required this.sortOrder,
    required this.isActive,
  });

  factory AdminSyllabusItem.fromJson(Map<String, dynamic> json) {
    return AdminSyllabusItem(
      id: json['id'] as int,
      levelId: json['level_id'] as int,
      subjectName: json['subject_name'] as String,
      description: json['description'] as String?,
      linkType: json['link_type'] as String,
      url: json['url'] as String,
      sortOrder: (json['sort_order'] as int?) ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  bool get isGoogleDrive => url.contains('drive.google.com');
  bool get isPdf => linkType == 'pdf';
}

/// Repository for syllabus admin operations
class SyllabusAdminRepository {
  final ApiClient _api;

  SyllabusAdminRepository({ApiClient? api}) : _api = api ?? ApiClient();

  /// Get all class levels
  Future<List<ClassLevel>> getLevels() async {
    try {
      final response = await _api.get<List<dynamic>>(
        AppConstants.syllabusLevelsEndpoint,
      );
      return response
          .map((json) => ClassLevel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching levels: $e');
      rethrow;
    }
  }

  /// Get all syllabus items grouped by level
  Future<Map<int, List<AdminSyllabusItem>>> getSyllabusItems() async {
    try {
      final response = await _api.get<List<dynamic>>(
        '${AppConstants.adminSyllabusEndpoint}?include_inactive=true',
      );

      final Map<int, List<AdminSyllabusItem>> grouped = {};
      for (final levelData in response) {
        final levelMap = levelData as Map<String, dynamic>;
        final levelId = levelMap['level_id'] as int;
        final items = (levelMap['items'] as List)
            .map(
              (item) =>
                  AdminSyllabusItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        grouped[levelId] = items;
      }

      return grouped;
    } catch (e) {
      debugPrint('Error fetching syllabus items: $e');
      rethrow;
    }
  }

  /// Add new syllabus item
  Future<void> addItem({
    required int levelId,
    required String subjectName,
    required String description,
    required String linkType,
    required String url,
    required int sortOrder,
  }) async {
    try {
      await _api.post(
        AppConstants.adminSyllabusEndpoint,
        data: {
          'level_id': levelId,
          'subject_name': subjectName,
          'description': description,
          'link_type': linkType,
          'url': url,
          'sort_order': sortOrder,
        },
      );
    } catch (e) {
      debugPrint('Error adding syllabus item: $e');
      rethrow;
    }
  }

  /// Update existing syllabus item
  Future<void> updateItem({
    required int itemId,
    required String subjectName,
    required String description,
    required String linkType,
    required String url,
    required int sortOrder,
    required bool isActive,
  }) async {
    try {
      await _api.put(
        AppConstants.adminSyllabusItemEndpoint(itemId),
        data: {
          'subject_name': subjectName,
          'description': description,
          'link_type': linkType,
          'url': url,
          'sort_order': sortOrder,
          'is_active': isActive,
        },
      );
    } catch (e) {
      debugPrint('Error updating syllabus item: $e');
      rethrow;
    }
  }

  /// Delete syllabus item
  Future<void> deleteItem(int itemId) async {
    try {
      await _api.delete(AppConstants.adminSyllabusItemEndpoint(itemId));
    } catch (e) {
      debugPrint('Error deleting syllabus item: $e');
      rethrow;
    }
  }
}

/// Repository provider
final syllabusAdminRepositoryProvider = Provider<SyllabusAdminRepository>((
  ref,
) {
  return SyllabusAdminRepository();
});

/// Cached levels provider with auto-dispose
final syllabusLevelsProvider = FutureProvider.autoDispose<List<ClassLevel>>((
  ref,
) async {
  final repository = ref.watch(syllabusAdminRepositoryProvider);
  // Keep data alive for 10 minutes
  ref.keepAlive();
  final link = ref.keepAlive();
  Future.delayed(const Duration(minutes: 10), () => link.close());

  return repository.getLevels();
});

/// Cached syllabus items provider with auto-dispose
final syllabusItemsProvider =
    FutureProvider.autoDispose<Map<int, List<AdminSyllabusItem>>>((ref) async {
      final repository = ref.watch(syllabusAdminRepositoryProvider);
      // Keep data alive for 10 minutes
      ref.keepAlive();
      final link = ref.keepAlive();
      Future.delayed(const Duration(minutes: 10), () => link.close());

      return repository.getSyllabusItems();
    });

/// Selected level state provider
final selectedLevelIdProvider = StateProvider<int?>((ref) => null);

/// Filtered items for selected level
final selectedLevelItemsProvider =
    Provider.autoDispose<List<AdminSyllabusItem>>((ref) {
      final selectedLevelId = ref.watch(selectedLevelIdProvider);
      final itemsAsync = ref.watch(syllabusItemsProvider);

      return itemsAsync.when(
        data: (items) =>
            selectedLevelId != null ? (items[selectedLevelId] ?? []) : [],
        loading: () => [],
        error: (error, stack) => [],
      );
    });
