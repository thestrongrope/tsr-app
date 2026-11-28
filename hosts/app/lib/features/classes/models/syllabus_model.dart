// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'syllabus_model.freezed.dart';
part 'syllabus_model.g.dart';

/// Link type for syllabus items.
enum SyllabusLinkType {
  @JsonValue('pdf')
  pdf,
  @JsonValue('external')
  external,
}

/// Represents a single syllabus item.
@freezed
sealed class SyllabusItem with _$SyllabusItem {
  const factory SyllabusItem({
    required int id,
    @JsonKey(name: 'level_id') required int levelId,
    @JsonKey(name: 'subject_name') required String subjectName,
    String? description,
    @JsonKey(name: 'link_type')
    @Default(SyllabusLinkType.pdf)
    SyllabusLinkType linkType,
    required String url,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
  }) = _SyllabusItem;

  factory SyllabusItem.fromJson(Map<String, dynamic> json) =>
      _$SyllabusItemFromJson(json);
}

/// Represents syllabus items grouped by class level.
@freezed
sealed class SyllabusLevel with _$SyllabusLevel {
  const factory SyllabusLevel({
    @JsonKey(name: 'level_id') required int levelId,
    @JsonKey(name: 'level_name') required String levelName,
    @JsonKey(name: 'level_code') required String levelCode,
    @Default([]) List<SyllabusItem> items,
  }) = _SyllabusLevel;

  factory SyllabusLevel.fromJson(Map<String, dynamic> json) =>
      _$SyllabusLevelFromJson(json);
}

/// Represents a class level for selection.
@freezed
sealed class ClassLevel with _$ClassLevel {
  const factory ClassLevel({
    required int id,
    required String code,
    required String name,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
  }) = _ClassLevel;

  factory ClassLevel.fromJson(Map<String, dynamic> json) =>
      _$ClassLevelFromJson(json);
}

/// State for syllabus download/viewing.
enum SyllabusDownloadStatus { notDownloaded, downloading, downloaded, error }

/// Tracks download state for a syllabus item.
@freezed
sealed class SyllabusDownloadState with _$SyllabusDownloadState {
  const factory SyllabusDownloadState({
    required int syllabusId,
    @Default(SyllabusDownloadStatus.notDownloaded)
    SyllabusDownloadStatus status,
    String? localPath,
    String? errorMessage,
    @Default(0.0) double progress,
  }) = _SyllabusDownloadState;
}
