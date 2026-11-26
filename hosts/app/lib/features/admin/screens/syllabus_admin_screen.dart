import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/syllabus_admin_provider.dart';
import '../../../core/utils/user_message.dart';
import '../../../core/widgets/tab_bar_inset.dart';

/// Modern admin screen for managing syllabus items with caching
class SyllabusAdminScreen extends ConsumerStatefulWidget {
  const SyllabusAdminScreen({super.key});

  @override
  ConsumerState<SyllabusAdminScreen> createState() =>
      _SyllabusAdminScreenState();
}

class _SyllabusAdminScreenState extends ConsumerState<SyllabusAdminScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-select first level when data loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final levelsAsync = ref.read(syllabusLevelsProvider);
      levelsAsync.whenData((levels) {
        if (levels.isNotEmpty && ref.read(selectedLevelIdProvider) == null) {
          ref.read(selectedLevelIdProvider.notifier).state = levels.first.id;
        }
      });
    });
  }

  Future<void> _showAddEditDialog({
    AdminSyllabusItem? item,
    required int levelId,
  }) async {
    final isEditing = item != null;
    final subjectController = TextEditingController(
      text: item?.subjectName ?? '',
    );
    final descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    final urlController = TextEditingController(text: item?.url ?? '');
    String linkType = item?.linkType ?? 'pdf';
    int sortOrder = item?.sortOrder ?? 0;
    bool isActive = item?.isActive ?? true;

    await showModalBottomSheet<bool>(
      // Stays on the tab's own navigator: the validation messages below go to
      // the shell's SnackBar, which a root-navigator sheet would cover.
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                24 +
                MediaQuery.paddingOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
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

                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryGreen,
                            AppTheme.secondaryGreen,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isEditing
                            ? Icons.edit_document
                            : Icons.add_circle_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit Syllabus Item'
                                : 'Add Syllabus Item',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final levelsAsync = ref.watch(
                                syllabusLevelsProvider,
                              );
                              return levelsAsync.when(
                                data: (levels) {
                                  final level = levels.firstWhere(
                                    (l) => l.id == levelId,
                                    orElse: () => levels.first,
                                  );
                                  return Text(
                                    'Level: ${level.name}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppTheme.mediumText),
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (error, stack) =>
                                    const SizedBox.shrink(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Subject Name Field
                _ModernTextField(
                  controller: subjectController,
                  label: 'Subject Name',
                  hint: 'e.g., Quran Reading, Fiqh',
                  icon: Icons.subject_rounded,
                  isRequired: true,
                ),

                const SizedBox(height: 20),

                // Description Field
                _ModernTextField(
                  controller: descriptionController,
                  label: 'Description',
                  hint: 'Brief description (optional)',
                  icon: Icons.description_rounded,
                  maxLines: 2,
                ),

                const SizedBox(height: 20),

                // Link Type Selector
                Text(
                  'Content Type',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TypeSelectorChip(
                        label: 'PDF Document',
                        icon: Icons.picture_as_pdf_rounded,
                        isSelected: linkType == 'pdf',
                        color: Colors.red,
                        onTap: () => setDialogState(() => linkType = 'pdf'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TypeSelectorChip(
                        label: 'External Link',
                        icon: Icons.link_rounded,
                        isSelected: linkType == 'external',
                        color: Colors.blue,
                        onTap: () =>
                            setDialogState(() => linkType = 'external'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // URL Field
                _ModernTextField(
                  controller: urlController,
                  label: 'URL',
                  hint: linkType == 'pdf'
                      ? 'https://drive.google.com/...'
                      : 'https://example.com/...',
                  icon: Icons.link_rounded,
                  isRequired: true,
                  keyboardType: TextInputType.url,
                ),

                const SizedBox(height: 20),

                // Sort Order & Active Status Row
                Row(
                  children: [
                    Expanded(
                      child: _ModernTextField(
                        controller: TextEditingController(
                          text: sortOrder.toString(),
                        ),
                        label: 'Sort Order',
                        hint: '0',
                        icon: Icons.sort_rounded,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          sortOrder = int.tryParse(value) ?? 0;
                        },
                      ),
                    ),
                    if (isEditing) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.successGreen.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.successGreen.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isActive
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 20,
                                color: isActive
                                    ? AppTheme.successGreen
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? AppTheme.successGreen
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (value) {
                                  setDialogState(() => isActive = value);
                                },
                                activeTrackColor: AppTheme.successGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.mediumText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (subjectController.text.trim().isEmpty) {
                            _showSnackBar(
                              context,
                              'Subject name is required',
                              isError: true,
                            );
                            return;
                          }
                          if (urlController.text.trim().isEmpty) {
                            _showSnackBar(
                              context,
                              'URL is required',
                              isError: true,
                            );
                            return;
                          }

                          try {
                            final repository = ref.read(
                              syllabusAdminRepositoryProvider,
                            );
                            if (isEditing) {
                              await repository.updateItem(
                                itemId: item.id,
                                subjectName: subjectController.text.trim(),
                                description: descriptionController.text.trim(),
                                linkType: linkType,
                                url: urlController.text.trim(),
                                sortOrder: sortOrder,
                                isActive: isActive,
                              );
                            } else {
                              await repository.addItem(
                                levelId: levelId,
                                subjectName: subjectController.text.trim(),
                                description: descriptionController.text.trim(),
                                linkType: linkType,
                                url: urlController.text.trim(),
                                sortOrder: sortOrder,
                              );
                            }

                            // Invalidate cache to refresh data
                            ref.invalidate(syllabusItemsProvider);

                            if (context.mounted) {
                              Navigator.pop(context, true);
                              _showSnackBar(
                                context,
                                isEditing
                                    ? 'Item updated successfully'
                                    : 'Item added successfully',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showSnackBar(
                                context,
                                'Error: ${userMessage(e)}',
                                isError: true,
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isEditing
                                  ? Icons.save_rounded
                                  : Icons.add_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Save Changes' : 'Add Item',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _deleteItem(AdminSyllabusItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Text('Delete Item')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this syllabus item?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isPdf ? Icons.picture_as_pdf : Icons.link,
                    color: item.isPdf ? Colors.red : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.subjectName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.mediumText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = ref.read(syllabusAdminRepositoryProvider);
        await repository.deleteItem(item.id);

        // Invalidate cache to refresh data
        ref.invalidate(syllabusItemsProvider);

        if (mounted) {
          _showSnackBar(context, 'Item deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(
            context,
            'Error deleting item: ${userMessage(e)}',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      // Validate URL
      if (url.isEmpty) {
        if (mounted) {
          _showSnackBar(context, 'Invalid URL', isError: true);
        }
        return;
      }

      // Ensure URL has proper scheme
      String urlToOpen = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        urlToOpen = 'https://$url';
      }

      final uri = Uri.parse(urlToOpen);

      // Try platformDefault mode first (works better with Google Drive)
      bool launched = await launchUrl(uri, mode: LaunchMode.platformDefault);

      // Fallback to external application if platformDefault fails
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!launched && mounted) {
        _showSnackBar(
          context,
          'Could not open link. Please check if you have a browser app installed.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Error opening link: ${userMessage(e)}\n\nPlease check if the URL is valid.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelsAsync = ref.watch(syllabusLevelsProvider);
    final itemsAsync = ref.watch(syllabusItemsProvider);
    final selectedLevelId = ref.watch(selectedLevelIdProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Syllabus Management'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(syllabusLevelsProvider);
              ref.invalidate(syllabusItemsProvider);
            },
          ),
        ],
      ),
      body: levelsAsync.when(
        data: (levels) {
          if (levels.isEmpty) {
            return _buildEmptyState(
              icon: Icons.school_outlined,
              title: 'No Class Levels Found',
              message: 'Please set up class levels first.',
            );
          }

          return Column(
            children: [
              // Level Selector Dropdown (Material 3)
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownMenu<int>(
                  initialSelection: selectedLevelId ?? levels.first.id,
                  expandedInsets: EdgeInsets.zero,
                  requestFocusOnTap: false,
                  leadingIcon: Container(
                    margin: const EdgeInsets.only(left: 8),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryGreen,
                          AppTheme.secondaryGreen,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  trailingIcon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                  selectedTrailingIcon: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                  label: const Text('Select Level'),
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkText,
                  ),
                  menuHeight: 400,
                  dropdownMenuEntries: levels.map((level) {
                    final itemCount = itemsAsync.when(
                      data: (items) => items[level.id]?.length ?? 0,
                      loading: () => 0,
                      error: (error, stack) => 0,
                    );

                    return DropdownMenuEntry<int>(
                      value: level.id,
                      label: level.name,
                      leadingIcon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryGreen,
                              AppTheme.secondaryGreen,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            level.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      trailingIcon: itemCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$itemCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            )
                          : null,
                    );
                  }).toList(),
                  onSelected: (value) {
                    if (value != null) {
                      ref.read(selectedLevelIdProvider.notifier).state = value;
                    }
                  },
                ),
              ),

              // Items List
              Expanded(
                child: itemsAsync.when(
                  data: (allItems) {
                    final currentLevelId = selectedLevelId ?? levels.first.id;
                    final items = allItems[currentLevelId] ?? [];

                    if (items.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No Syllabus Items',
                        message:
                            'Add syllabus items for this level to get started.',
                        action: ElevatedButton.icon(
                          onPressed: () =>
                              _showAddEditDialog(levelId: currentLevelId),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add First Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(syllabusItemsProvider);
                      },
                      child: ListView.builder(
                        padding: withTabBarInset(
                          context,
                          const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ModernSyllabusCard(
                            item: item,
                            index: index,
                            onEdit: () => _showAddEditDialog(
                              item: item,
                              levelId: currentLevelId,
                            ),
                            onDelete: () => _deleteItem(item),
                            onOpen: () => _openUrl(item.url),
                          );
                        },
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _buildEmptyState(
                    icon: Icons.error_outline,
                    title: 'Failed to load data',
                    message: userMessage(error),
                    iconColor: Colors.red,
                    action: ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(syllabusItemsProvider);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildEmptyState(
          icon: Icons.error_outline,
          title: 'Failed to load levels',
          message: userMessage(error),
          iconColor: Colors.red,
          action: ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(syllabusLevelsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: levelsAsync.when(
        data: (levels) {
          if (levels.isEmpty) return null;
          final currentLevelId = selectedLevelId ?? levels.first.id;
          return TabBarFabLift(
            child: FloatingActionButton.extended(
              onPressed: () => _showAddEditDialog(levelId: currentLevelId),
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Item',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
        loading: () => null,
        error: (error, stack) => null,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    Color? iconColor,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (iconColor ?? AppTheme.primaryGreen).withValues(alpha: 0.1),
                    AppTheme.lightGreen,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 48,
                color: iconColor ?? AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.mediumText),
            ),
            if (action != null) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }
}

/// Modern card widget for displaying syllabus item in admin view
class _ModernSyllabusCard extends StatelessWidget {
  final AdminSyllabusItem item;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _ModernSyllabusCard({
    required this.item,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = item.isPdf;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: item.isActive
            ? null
            : Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Index & Icon
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPdf
                              ? [Colors.red.shade400, Colors.red.shade600]
                              : [Colors.blue.shade400, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: (isPdf ? Colors.red : Colors.blue)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.link_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.subjectName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                          if (!item.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_off,
                                    size: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Hidden',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Description
                      if (item.description != null &&
                          item.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.mediumText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Type badge
                          _InfoBadge(
                            icon: isPdf ? Icons.picture_as_pdf : Icons.link,
                            label: isPdf ? 'PDF' : 'Link',
                            color: isPdf ? Colors.red : Colors.blue,
                          ),
                          // Google Drive badge
                          if (item.isGoogleDrive)
                            _InfoBadge(
                              icon: Icons.cloud,
                              label: 'Google Drive',
                              color: Colors.green,
                            ),
                          // Sort order badge
                          _InfoBadge(
                            icon: Icons.sort,
                            label: 'Order: ${item.sortOrder}',
                            color: Colors.purple,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // URL preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: AppTheme.mediumText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.url,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade700,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'Open',
                    color: AppTheme.primaryGreen,
                    onTap: onOpen,
                  ),
                ),
                _VerticalDivider(),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    color: Colors.blue,
                    onTap: onEdit,
                  ),
                ),
                _VerticalDivider(),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: Colors.red,
                    onTap: onDelete,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Info badge widget
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button for card
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical divider for action buttons
class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}

/// Modern text field widget
class _ModernTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isRequired;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _ModernTextField({
    this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isRequired = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkText,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.lightText),
            prefixIcon: Icon(icon, color: AppTheme.mediumText, size: 20),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Type selector chip widget
class _TypeSelectorChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeSelectorChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? color : AppTheme.mediumText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? color : AppTheme.mediumText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
