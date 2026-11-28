// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/html_text.dart';

part 'tsr_article.freezed.dart';
part 'tsr_article.g.dart';

/// Article model for TSR Web API (thestrongrope.com/api/v1)
/// Content is in HTML format
@freezed
sealed class TsrArticle with _$TsrArticle {
  const factory TsrArticle({
    @Default(0) int id,
    required String slug,
    // Same encoding as the video title, and rendered raw at
    // all_articles_screen.dart:824. `content` is deliberately untouched below:
    // it is HTML by design and decoding it would corrupt the markup.
    @JsonKey(fromJson: decodeHtmlEntities) required String title,
    @Default('') String content, // HTML content (only in detail view)
    @Default('') String excerpt,
    String? publishedDate,
    String? modifiedDate,
    @Default([])
    List<String> categories, // Changed from category to categories (array)
    @Default([]) List<String> tags,
    String? author,
    String? language,
    @Default(1) int readingTime,
    @Default(false) bool featured,
  }) = _TsrArticle;

  factory TsrArticle.fromJson(Map<String, dynamic> json) =>
      _$TsrArticleFromJson(json);
}

/// Category model for TSR Web API
@freezed
sealed class TsrCategory with _$TsrCategory {
  const factory TsrCategory({
    required String slug,
    required String title,
    String? description,
    @Default(0) int articleCount,
    @Default([]) List<TsrCategory> subcategories,
  }) = _TsrCategory;

  factory TsrCategory.fromJson(Map<String, dynamic> json) =>
      _$TsrCategoryFromJson(json);
}

/// Tag model for TSR Web API
@freezed
sealed class TsrTag with _$TsrTag {
  const factory TsrTag({
    required String name,
    required String slug,
    @Default(0) int articleCount,
  }) = _TsrTag;

  factory TsrTag.fromJson(Map<String, dynamic> json) => _$TsrTagFromJson(json);
}

/// YouTube video model for TSR Web API
@freezed
sealed class TsrYouTubeVideo with _$TsrYouTubeVideo {
  const factory TsrYouTubeVideo({
    required String id,
    required String videoId,
    // Decoded at the boundary rather than at each render site, so that search
    // in AllVideosScreen matches what the user can actually see. The API hands
    // WordPress's stored encoding straight through.
    @JsonKey(fromJson: decodeHtmlEntities) required String title,
    required String youtubeLink,
    String? publishedDate,
    String? publishedDateFormatted,
    int? views,
    String? intro,
    String? description,
    TsrThumbnail? thumbnail,
  }) = _TsrYouTubeVideo;

  factory TsrYouTubeVideo.fromJson(Map<String, dynamic> json) =>
      _$TsrYouTubeVideoFromJson(json);
}

/// Thumbnail model for YouTube videos
@freezed
sealed class TsrThumbnail with _$TsrThumbnail {
  const factory TsrThumbnail({required String url, int? width, int? height}) =
      _TsrThumbnail;

  factory TsrThumbnail.fromJson(Map<String, dynamic> json) =>
      _$TsrThumbnailFromJson(json);
}

/// YouTube response metadata
@freezed
sealed class TsrYouTubeMeta with _$TsrYouTubeMeta {
  const factory TsrYouTubeMeta({
    int? total,
    String? channelId,
    String? channelName,
    String? channelUrl,
    String? lastUpdated,
    @Default(false) bool cacheHit,
  }) = _TsrYouTubeMeta;

  factory TsrYouTubeMeta.fromJson(Map<String, dynamic> json) =>
      _$TsrYouTubeMetaFromJson(json);
}

/// API Response wrapper for TSR Web API
@freezed
sealed class TsrApiResponse<T> with _$TsrApiResponse<T> {
  const factory TsrApiResponse({
    required bool success,
    T? data,
    TsrPagination? pagination,
    TsrApiError? error,
  }) = _TsrApiResponse<T>;
}

/// Pagination info for API responses
@freezed
sealed class TsrPagination with _$TsrPagination {
  const factory TsrPagination({
    @Default(0) int total,
    @Default(20) int limit,
    @Default(0) int offset,
    @Default(false) bool hasMore,
  }) = _TsrPagination;

  factory TsrPagination.fromJson(Map<String, dynamic> json) =>
      _$TsrPaginationFromJson(json);
}

/// API Error model
@freezed
sealed class TsrApiError with _$TsrApiError {
  const factory TsrApiError({String? code, String? message}) = _TsrApiError;

  factory TsrApiError.fromJson(Map<String, dynamic> json) =>
      _$TsrApiErrorFromJson(json);
}

/// Search result model
@freezed
sealed class TsrSearchResult with _$TsrSearchResult {
  const factory TsrSearchResult({
    required List<TsrArticle> results,
    required String query,
    @Default(0) int total,
  }) = _TsrSearchResult;

  factory TsrSearchResult.fromJson(Map<String, dynamic> json) =>
      _$TsrSearchResultFromJson(json);
}
