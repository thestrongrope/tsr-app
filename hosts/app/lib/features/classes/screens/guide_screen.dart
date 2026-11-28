import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_section.dart';
import '../../../core/widgets/app_error_view.dart';
import '../providers/classes_provider.dart';
import '../widgets/class_loading_skeleton.dart';
import '../widgets/guide_content.dart';
import '../providers/class_guide_provider.dart';
import 'guide_translate_screen.dart';

/// The guide for a class's level (#412), read-only. Links open outside the
/// app: documents in their own app, the rest in the browser.
class GuideScreen extends ConsumerWidget {
  const GuideScreen({
    super.key,
    required this.classId,
    this.launch = openGuideLinkExternally,
    this.share = shareGuideLink,
    this.webViewBuilder,
  });

  final int classId;

  /// Opens a URL outside the app; false when it could not be opened.
  final GuideLauncher launch;

  /// Hands the public link to the system share sheet.
  final Future<void> Function(String) share;

  /// The translate screen's web view; null for the real one. For tests.
  final GuideWebViewBuilder? webViewBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(classGuideProvider(classId));
    final className = ref.watch(
      classesProvider.select(
        (state) =>
            state.classes?.where((c) => c.id == classId).firstOrNull?.name,
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Guide'),
        actions: guideActions(
          context,
          guide: guide.asData?.value,
          launch: launch,
          share: share,
          webViewBuilder: webViewBuilder,
        ),
      ),
      body: guide.when(
        loading: () => const ClassLoadingSkeleton(),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(classGuideProvider(classId)),
        ),
        data: (data) {
          final html = data.guide;
          if (html == null) {
            return _NoGuide(className: className, levelName: data.levelName);
          }
          return GuideBody(html: html, launch: launch);
        },
      ),
    );
  }
}

/// A level with no guide: names the class and its level so the teacher can
/// tell the screen opened for the right class.
class _NoGuide extends StatelessWidget {
  const _NoGuide({required this.className, required this.levelName});

  final String? className;
  final String levelName;

  String get _message {
    final level = levelName.isEmpty ? null : levelName;
    if (className != null && level != null) {
      return '$className ($level) has no guide yet.';
    }
    if (className != null) return '$className has no guide yet.';
    if (level != null) return 'The $level level has no guide yet.';
    return 'There is no guide for this level yet.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Align(
        alignment: Alignment.topCenter,
        child: AppEmptySection(
          icon: Icons.menu_book_outlined,
          message: _message,
        ),
      ),
    );
  }
}
