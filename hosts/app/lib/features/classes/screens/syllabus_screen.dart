import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/theme/app_theme.dart';
import '../models/syllabus_model.dart';
import '../widgets/class_loading_skeleton.dart';
import '../../../core/widgets/app_error_view.dart';
import '../providers/syllabus_provider.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Screen to display syllabus items for a class level.
class SyllabusScreen extends ConsumerStatefulWidget {
  final int classId;
  final int levelId;

  const SyllabusScreen({
    super.key,
    required this.classId,
    required this.levelId,
  });

  @override
  ConsumerState<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends ConsumerState<SyllabusScreen> {
  @override
  void initState() {
    super.initState();
    // Load syllabus when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(syllabusProvider(widget.levelId).notifier)
          .loadSyllabus(widget.levelId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(syllabusProvider(widget.levelId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.syllabus?.levelName != null
              ? '${state.syllabus!.levelName} Syllabus'
              : 'Syllabus',
        ),
      ),
      body: _buildBody(context, state, theme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SyllabusState state,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const ClassLoadingSkeleton();
    }

    if (state.error != null) {
      return AppErrorView(
        error: state.loadFailure ?? state.error!,
        onRetry: () => ref
            .read(syllabusProvider(widget.levelId).notifier)
            .loadSyllabus(widget.levelId),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Syllabus Available',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Syllabus for this level has not been added yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(syllabusProvider(widget.levelId).notifier)
            .refreshSyllabus(widget.levelId);
      },
      child: ListView.builder(
        padding: withTabBarInset(context, const EdgeInsets.all(16)),
        itemCount: state.syllabus!.items.length,
        itemBuilder: (context, index) {
          final item = state.syllabus!.items[index];
          final downloadState = state.downloadStates[item.id];
          return _SyllabusItemCard(
            item: item,
            downloadState: downloadState,
            onTap: () => _handleItemTap(item, downloadState),
            onOpenInBrowser: () => _openInBrowser(item),
          );
        },
      ),
    );
  }

  /// Check if URL is a Google Drive link
  bool _isGoogleDriveUrl(String url) {
    return url.contains('drive.google.com');
  }

  Future<void> _handleItemTap(
    SyllabusItem item,
    SyllabusDownloadState? downloadState,
  ) async {
    if (item.linkType == SyllabusLinkType.external) {
      // Open external link in browser
      final uri = Uri.parse(item.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open link')));
        }
      }
    } else {
      // Handle PDF - for Google Drive, prefer opening in browser for reliability
      if (_isGoogleDriveUrl(item.url)) {
        // Show options dialog
        _showPdfOptionsDialog(item, downloadState);
      } else {
        // For non-Google Drive PDFs, try to download and open
        await _downloadAndOpen(item, downloadState);
      }
    }
  }

  void _showPdfOptionsDialog(
    SyllabusItem item,
    SyllabusDownloadState? downloadState,
  ) {
    final isDownloaded =
        downloadState?.status == SyllabusDownloadStatus.downloaded;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withValues(alpha: 0.5),
                      AppTheme.secondaryGreen.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.subjectName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how to open this PDF',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
            ),
            const SizedBox(height: 24),

            // Open in Browser (Recommended)
            _OptionTile(
              icon: Icons.open_in_browser,
              iconColor: AppTheme.primaryGreen,
              title: 'Open in Browser',
              subtitle: 'Recommended - Opens Google Drive viewer',
              onTap: () {
                Navigator.pop(context);
                _openInBrowser(item);
              },
            ),

            const SizedBox(height: 12),

            // Download option
            if (isDownloaded) ...[
              _OptionTile(
                icon: Icons.folder_open,
                iconColor: Colors.blue,
                title: 'Open Downloaded File',
                subtitle: 'Open the locally saved PDF',
                onTap: () {
                  Navigator.pop(context);
                  _openLocalFile(downloadState!.localPath!);
                },
              ),
            ] else ...[
              _OptionTile(
                icon: Icons.download,
                iconColor: Colors.orange,
                title: 'Download PDF',
                subtitle: 'Save to device for offline access',
                onTap: () {
                  Navigator.pop(context);
                  _downloadAndOpen(item, downloadState);
                },
              ),
            ],

            const SizedBox(height: 12),

            // Delete downloaded file option
            if (isDownloaded) ...[
              _OptionTile(
                icon: Icons.delete_outline,
                iconColor: Colors.red,
                title: 'Delete Downloaded File',
                subtitle: 'Remove from device storage',
                onTap: () async {
                  Navigator.pop(context);
                  // Store messenger before async gap
                  final messenger = mounted
                      ? ScaffoldMessenger.of(context)
                      : null;

                  await ref
                      .read(syllabusRepositoryProvider)
                      .deleteLocalPdf(item);
                  ref
                      .read(syllabusProvider(widget.levelId).notifier)
                      .loadSyllabus(widget.levelId);

                  // Safe to use stored messenger
                  messenger?.showSnackBar(
                    const SnackBar(content: Text('Downloaded file deleted')),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openInBrowser(SyllabusItem item) async {
    try {
      final uri = Uri.parse(item.url);
      // Use platformDefault for better compatibility with Google Drive
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Please install a browser app.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndOpen(
    SyllabusItem item,
    SyllabusDownloadState? downloadState,
  ) async {
    // If already downloaded, open it
    if (downloadState?.status == SyllabusDownloadStatus.downloaded &&
        downloadState?.localPath != null) {
      _openLocalFile(downloadState!.localPath!);
      return;
    }

    // If currently downloading, do nothing
    if (downloadState?.status == SyllabusDownloadStatus.downloading) {
      return;
    }

    // Show downloading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              Text('Downloading PDF...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    // Download the file
    final path = await ref
        .read(syllabusProvider(widget.levelId).notifier)
        .downloadPdf(item);

    // Hide the snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF downloaded successfully!'),
          backgroundColor: AppTheme.successGreen,
          // Auto-dismiss even though an action is present (Flutter defaults
          // `persist` to true when there's an action).
          persist: false,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => _openLocalFile(path),
          ),
        ),
      );
      _openLocalFile(path);
    } else if (mounted) {
      // Download failed, offer to open in browser
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Download failed. Try opening in browser instead.',
          ),
          backgroundColor: AppTheme.errorRed,
          duration: const Duration(seconds: 5),
          // Auto-dismiss even though an action is present (Flutter defaults
          // `persist` to true when there's an action).
          persist: false,
          action: SnackBarAction(
            label: 'Open in Browser',
            textColor: Colors.white,
            onPressed: () => _openInBrowser(item),
          ),
        ),
      );
    }
  }

  Future<void> _openLocalFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found. Please download again.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
}

/// Option tile for the bottom sheet
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card widget for displaying a single syllabus item.
class _SyllabusItemCard extends StatelessWidget {
  final SyllabusItem item;
  final SyllabusDownloadState? downloadState;
  final VoidCallback onTap;
  final VoidCallback onOpenInBrowser;

  const _SyllabusItemCard({
    required this.item,
    required this.downloadState,
    required this.onTap,
    required this.onOpenInBrowser,
  });

  bool _isGoogleDriveUrl(String url) {
    return url.contains('drive.google.com');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPdf = item.linkType == SyllabusLinkType.pdf;
    final isDownloaded =
        downloadState?.status == SyllabusDownloadStatus.downloaded;
    final isDownloading =
        downloadState?.status == SyllabusDownloadStatus.downloading;
    final isGoogleDrive = isPdf && _isGoogleDriveUrl(item.url);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPdf
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : [AppTheme.primaryGreen, AppTheme.secondaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isPdf ? Colors.red : AppTheme.primaryGreen)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.open_in_new_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subjectName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isPdf
                                ? Colors.red.withValues(alpha: 0.1)
                                : AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPdf ? Icons.picture_as_pdf : Icons.link,
                                size: 12,
                                color: isPdf
                                    ? Colors.red
                                    : AppTheme.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPdf ? 'PDF' : 'LINK',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isPdf
                                      ? Colors.red
                                      : AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Google Drive badge
                        if (isGoogleDrive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud,
                                  size: 12,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Drive',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Downloaded badge
                        if (isPdf && isDownloaded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.download_done,
                                  size: 12,
                                  color: AppTheme.successGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Saved',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppTheme.successGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action icon
              if (isDownloading)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPdf
                        ? (isGoogleDrive
                              ? Icons.touch_app_rounded
                              : (isDownloaded
                                    ? Icons.open_in_new
                                    : Icons.download_rounded))
                        : Icons.arrow_forward_ios_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
