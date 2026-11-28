import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/route_config.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/services/action_link.dart';
import '../models/tsr_article.dart';

/// Opens a lecture in the app's own player. A video the API cannot identify is
/// handed to the phone instead, so the tap never dead-ends.
void openTsrVideo(BuildContext context, TsrYouTubeVideo video) {
  final videoId = video.videoId.trim().isNotEmpty
      ? video.videoId.trim()
      : youtubeVideoId(video.youtubeLink);

  if (videoId == null || videoId.isEmpty) {
    unawaited(openVideoOnYouTube(context, video));
    return;
  }

  unawaited(context.push(AppRoutes.videoDetailPath(videoId), extra: video));
}

/// The YouTube video id in [url], or null when it is not a video address.
String? youtubeVideoId(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return null;

  final host = uri.host.toLowerCase();
  if (host == 'youtu.be' || host == 'www.youtu.be') {
    return _firstSegment(uri);
  }

  if (!host.endsWith('youtube.com') && !host.endsWith('youtube-nocookie.com')) {
    return null;
  }

  final fromQuery = uri.queryParameters['v']?.trim();
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

  final segments = uri.pathSegments;
  if (segments.length >= 2 &&
      const {'embed', 'shorts', 'live', 'v'}.contains(segments.first)) {
    return segments[1].trim().isEmpty ? null : segments[1].trim();
  }

  return null;
}

String? _firstSegment(Uri uri) {
  if (uri.pathSegments.isEmpty) return null;
  final id = uri.pathSegments.first.trim();
  return id.isEmpty ? null : id;
}

/// "12.5K" / "3.4M", or null when the count is missing or zero.
String? formatVideoViews(int? views) {
  if (views == null || views <= 0) return null;
  if (views >= 1000000) {
    return '${(views / 1000000).toStringAsFixed(1)}M';
  }
  if (views >= 1000) {
    return '${(views / 1000).toStringAsFixed(1)}K';
  }
  return '$views';
}

/// "Oct 29, 2026 · 2 views", skipping whichever half is unavailable.
String videoMetaLine(TsrYouTubeVideo video) {
  final date = video.publishedDateFormatted?.trim() ?? '';
  final views = formatVideoViews(video.views);
  return [
    if (date.isNotEmpty) date,
    if (views != null) '$views views',
  ].join(' · ');
}

Future<void> openYouTubeChannel(BuildContext context) async {
  final uri = Uri.parse(AppStrings.youtubeChannelUrl);
  if (await _launch(uri)) return;
  if (!context.mounted) return;
  AppSnackBar.showError(
    context,
    message: 'Could not open the YouTube channel.',
  );
}

/// Opens [video] in YouTube, the same way a tapped notification does. Says so
/// when YouTube cannot be opened.
Future<void> openVideoOnYouTube(
  BuildContext context,
  TsrYouTubeVideo video, {
  Future<bool> Function(Uri uri) launch = launchVideo,
}) async {
  final id = video.videoId.trim().isNotEmpty
      ? video.videoId.trim()
      : youtubeVideoId(video.youtubeLink);
  final uri = id != null && id.isNotEmpty
      ? Uri.https('www.youtube.com', '/watch', {'v': id})
      : Uri.tryParse(video.youtubeLink);
  await openYouTubeUri(context, uri, launch: launch);
}

/// Opens the YouTube watch page for [videoId].
Future<void> openYouTubeVideoId(
  BuildContext context,
  String videoId, {
  Future<bool> Function(Uri uri) launch = launchVideo,
}) => openYouTubeUri(
  context,
  Uri.https('www.youtube.com', '/watch', {'v': videoId}),
  launch: launch,
);

Future<void> openYouTubeUri(
  BuildContext context,
  Uri? uri, {
  Future<bool> Function(Uri uri) launch = launchVideo,
}) async {
  if (uri != null && await launch(uri)) return;
  if (!context.mounted) return;
  AppSnackBar.showError(context, message: 'Could not open this video.');
}

Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
