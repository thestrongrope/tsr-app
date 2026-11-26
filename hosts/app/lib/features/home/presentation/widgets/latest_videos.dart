import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../wordpress/providers/tsr_providers.dart';
import '../../../wordpress/models/tsr_article.dart';
import '../../../../core/widgets/widgets.dart';

class LatestVideos extends ConsumerWidget {
  const LatestVideos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (limit: 5, offset: 0);
    final videosAsync = ref.watch(tsrYouTubeProvider(args));
    final isEmpty = videosAsync.asData?.value.videos.isEmpty ?? false;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: AppSectionHeader(
            title: 'Latest Videos',
            actionLabel: 'View all',
            onAction: () => context.push('/videos'),
          ),
        ),
        const SizedBox(height: 12),
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: AppEmptySection(
              icon: Icons.play_circle_outline,
              message: 'No videos yet',
              actionLabel: 'Browse videos',
              onAction: () => context.push('/videos'),
            ),
          )
        else
          SizedBox(
            height: 220,
            child: videosAsync.when(
              data: (response) => ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: response.videos.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) =>
                    _VideoCard(video: response.videos[index]),
              ),
              loading: () => ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) =>
                    const SkeletonBox(width: 240, height: 220),
              ),
              error: (error, stack) => AppErrorView(
                error: error,
                compact: true,
                onRetry: () => ref.invalidate(tsrYouTubeProvider(args)),
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  final TsrYouTubeVideo video;

  const _VideoCard({required this.video});

  Future<void> _launchVideo() async {
    final uri = Uri.parse(video.youtubeLink);
    try {
      // Try platform default first
      if (await launchUrl(uri)) return;
      // Fallback to external application
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launchVideo,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (video.thumbnail?.url != null)
                      CachedNetworkImage(
                        imageUrl: video.thumbnail!.url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[300]),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                      )
                    else
                      Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.video_library),
                      ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.publishedDateFormatted ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.mediumText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
