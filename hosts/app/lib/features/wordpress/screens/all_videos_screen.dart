import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/saved_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../models/tsr_article.dart';
import '../providers/tsr_providers.dart';
import '../services/tsr_web_service.dart';
import '../services/content_cache_service.dart';
import '../widgets/video_widgets.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// State notifier for managing videos list with pagination
class AllVideosNotifier extends StateNotifier<AllVideosState> {
  AllVideosNotifier(this._service, this._cacheService)
    : super(const AllVideosState());

  final TsrWebService _service;
  final ContentCacheService _cacheService;
  static const int _pageSize = 20;

  Future<void> loadVideos({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;
    if (refresh) {
      state = state.copyWith(videos: [], offset: 0, hasMore: true, error: null);
    }

    // Try to load from cache first (only for first page)
    if (state.offset == 0) {
      final cached = await _cacheService.getCachedAllVideos();
      if (cached != null && cached.isNotEmpty && !refresh) {
        state = state.copyWith(
          videos: cached,
          offset: cached.length,
          hasMore: cached.length >= _pageSize,
          isLoading: false,
          totalVideos: cached.length,
        );
        return;
      }
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _service.getYouTubeVideos(
        limit: _pageSize,
        offset: state.offset,
      );

      final newVideos = [...state.videos, ...response.videos];
      // Check if we got fewer videos than requested
      final hasMore = response.videos.length >= _pageSize;
      state = state.copyWith(
        videos: newVideos,
        offset: state.offset + response.videos.length,
        hasMore: hasMore,
        isLoading: false,
        totalVideos: response.meta?.total,
      );

      // Cache the first page of videos
      if (state.offset == response.videos.length) {
        await _cacheService.cacheAllVideos(newVideos);
      }
    } catch (e) {
      // On error, try to load from cache as fallback
      if (state.videos.isEmpty) {
        final cached = await _cacheService.getCachedAllVideos(
          maxAge: savedCopyMaxAge,
        );
        if (cached != null && cached.isNotEmpty) {
          state = state.copyWith(
            videos: cached,
            offset: cached.length,
            hasMore: false,
            isLoading: false,
            error: e,
            totalVideos: cached.length,
          );
          return;
        }
      }
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void setSearchQuery(String query) {
    if (state.searchQuery != query) {
      state = state.copyWith(searchQuery: query);
      // Note: YouTube API might not support search, so we filter locally
    }
  }
}

class AllVideosState {
  final List<TsrYouTubeVideo> videos;
  final bool isLoading;
  final Object? error;
  final int offset;
  final bool hasMore;
  final String searchQuery;
  final int? totalVideos;

  const AllVideosState({
    this.videos = const [],
    this.isLoading = false,
    this.error,
    this.offset = 0,
    this.hasMore = true,
    this.searchQuery = '',
    this.totalVideos,
  });

  AllVideosState copyWith({
    List<TsrYouTubeVideo>? videos,
    bool? isLoading,
    Object? error,
    int? offset,
    bool? hasMore,
    String? searchQuery,
    int? totalVideos,
  }) {
    return AllVideosState(
      videos: videos ?? this.videos,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
      totalVideos: totalVideos ?? this.totalVideos,
    );
  }

  List<TsrYouTubeVideo> get filteredVideos {
    if (searchQuery.isEmpty) return videos;
    final query = searchQuery.toLowerCase();
    return videos
        .where(
          (v) =>
              v.title.toLowerCase().contains(query) ||
              (v.description?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }
}

final allVideosProvider =
    StateNotifierProvider<AllVideosNotifier, AllVideosState>((ref) {
      final service = ref.watch(tsrWebServiceProvider);
      final cacheService = ref.watch(contentCacheServiceProvider);
      return AllVideosNotifier(service, cacheService);
    });

class AllVideosScreen extends ConsumerStatefulWidget {
  const AllVideosScreen({super.key});

  @override
  ConsumerState<AllVideosScreen> createState() => _AllVideosScreenState();
}

class _AllVideosScreenState extends ConsumerState<AllVideosScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allVideosProvider.notifier).loadVideos();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(allVideosProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(allVideosProvider.notifier).loadVideos();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allVideosProvider);
    final videos = state.videos;

    return Scaffold(
      appBar: AppBar(
        // Title + subtitle
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Videos'),
            Text(
              AppStrings.videosAppBarSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.darkText,
        actions: [
          // View Channel / Subscribe button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () async {
                final uri = Uri.parse(AppStrings.youtubeChannelUrl);
                try {
                  final launched = await launchUrl(uri);
                  if (launched) return;
                  final fallback = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (fallback) return;
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open channel.')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error opening channel: ${userMessage(e)}'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(AppStrings.viewChannelText),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
        child: state.error != null && videos.isEmpty
            ? AppErrorView(error: state.error!, onRetry: _retry)
            : videos.isEmpty && !state.isLoading
            ? _buildEmptyView()
            : _withSavedCopyNotice(
                state.error,
                RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(allVideosProvider.notifier)
                        .loadVideos(refresh: true);
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      // Responsive columns: 2 on narrow, 3 medium, more on wide screens
                      int crossAxisCount;
                      double childAspectRatio;
                      if (width >= 1200) {
                        int c = (width ~/ 320);
                        if (c < 3) c = 3;
                        if (c > 6) c = 6;
                        crossAxisCount = c;
                        childAspectRatio =
                            1.15; // Slightly taller to fit title and date
                      } else if (width >= 800) {
                        crossAxisCount = 3;
                        childAspectRatio = 1.1;
                      } else {
                        crossAxisCount = 2;
                        childAspectRatio = 0.85;
                      }

                      return GridView.builder(
                        controller: _scrollController,
                        padding: withTabBarInset(
                          context,
                          const EdgeInsets.all(16),
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: videos.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == videos.length) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return VideoGridCard(video: videos[index]);
                        },
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  void _retry() =>
      ref.read(allVideosProvider.notifier).loadVideos(refresh: true);

  /// The saved copy stays on screen; the plain message and Retry sit under it.
  Widget _withSavedCopyNotice(Object? error, Widget list) {
    if (error == null) return list;
    return Column(
      children: [
        Expanded(child: list),
        AppErrorView(error: error, onRetry: _retry, compact: true),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: AppTheme.mediumText,
          ),
          const SizedBox(height: 16),
          Text(
            'No videos found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.mediumText),
          ),
        ],
      ),
    );
  }
}
