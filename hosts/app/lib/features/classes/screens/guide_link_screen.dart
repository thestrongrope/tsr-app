import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/route_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_error_view.dart';
import '../models/class_guide.dart';
import '../providers/class_guide_provider.dart';
import '../widgets/class_loading_skeleton.dart';
import '../widgets/guide_content.dart';
import 'guide_translate_screen.dart';

const _notForYouMessage = 'Guides are for students and teachers.';

bool _isRefusal(Object error) =>
    error is ApiException && error.statusCode == 403;

bool _isUnknownGuide(Object error) =>
    error is ApiException && error.statusCode == 404;

/// A guide link (#1138): the level's guide the link names, `?guide=<slug>`.
/// A guide that does not exist says so and lists the guides; a person who is
/// neither a student nor a teacher is told the guide is not for them and sees
/// none of it. A signed-out person never reaches here: the router sends them
/// to sign in and back.
class GuideLinkScreen extends ConsumerWidget {
  const GuideLinkScreen({
    super.key,
    required this.slug,
    this.launch = openGuideLinkExternally,
    this.share = shareGuideLink,
    this.webViewBuilder,
  });

  /// The `guide` query of the link; null or empty when the link names none.
  final String? slug;

  /// Opens a URL outside the app; false when it could not be opened.
  final GuideLauncher launch;

  /// Hands the public link to the system share sheet.
  final Future<void> Function(String) share;

  /// The translate screen's web view; null for the real one. For tests.
  final GuideWebViewBuilder? webViewBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = slug;
    if (name == null || name.isEmpty) {
      return _frame(context, null, const _UnknownGuide());
    }

    final guide = ref.watch(guideBySlugProvider(name));
    return _frame(
      context,
      guide.asData?.value,
      guide.when(
        loading: () => const ClassLoadingSkeleton(),
        error: (error, _) {
          if (_isRefusal(error)) return const _NotForYou();
          if (_isUnknownGuide(error)) return const _UnknownGuide();
          return AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(guideBySlugProvider(name)),
          );
        },
        data: (data) => GuideBody(html: data.guide ?? '', launch: launch),
      ),
    );
  }

  Widget _frame(BuildContext context, ClassGuide? guide, Widget body) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Guide'),
        actions: guideActions(
          context,
          guide: guide,
          launch: launch,
          share: share,
          webViewBuilder: webViewBuilder,
        ),
      ),
      body: body,
    );
  }
}

class _NotForYou extends StatelessWidget {
  const _NotForYou();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppTheme.spacingLG),
      child: Align(
        alignment: Alignment.topCenter,
        child: AppEmptySection(
          icon: Icons.lock_outline,
          message: _notForYouMessage,
        ),
      ),
    );
  }
}

/// The link names no guide that exists: say so, and list the ones that do.
class _UnknownGuide extends ConsumerWidget {
  const _UnknownGuide();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guides = ref.watch(readableGuidesProvider);
    return guides.when(
      loading: () => const ClassLoadingSkeleton(),
      error: (error, _) => _isRefusal(error)
          ? const _NotForYou()
          : AppErrorView(
              error: error,
              onRetry: () => ref.invalidate(readableGuidesProvider),
            ),
      data: (list) => ListView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        children: [
          const Text('That guide does not exist. Choose one of these:'),
          const SizedBox(height: AppTheme.spacingMD),
          for (final guide in list)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(guide.name),
              onTap: () => context.push(
                '${AppRoutes.guideLink}?guide=${Uri.encodeQueryComponent(guide.slug)}',
              ),
            ),
        ],
      ),
    );
  }
}
