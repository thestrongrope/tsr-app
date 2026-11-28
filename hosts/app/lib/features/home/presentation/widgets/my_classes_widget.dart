import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/permissions/capabilities.dart';
import '../../../../core/permissions/capabilities_home.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../classes/models/class_model.dart';
import '../../../classes/providers/classes_provider.dart';

/// How many classes Home shows; the Classes tab holds the rest.
const _homeClassLimit = 2;

/// Classes the person attends, then conducts, then manages. Each kind keeps
/// the server's order.
List<ClassModel> orderForHome(List<ClassModel> classes) => [
  ...classes.where((c) => c.isAttending),
  ...classes.where((c) => c.isConducting),
  ...classes.where((c) => c.isManaging),
];

String _kindLabel(ClassModel c) {
  if (c.isConducting) return 'Conducting';
  if (c.isManaging) return 'Managing';
  return 'Attending';
}

class MyClassesWidget extends ConsumerWidget {
  const MyClassesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesState = ref.watch(classesProvider);
    // Do not link to a Classes tab that is not there.
    final linksToClasses = ref.watch(capabilitiesProvider).showClassesLinks;
    final ordered = orderForHome(classesState.classes ?? const []);
    final shown = ordered.take(_homeClassLimit).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: AppSectionHeader(
            title: 'My Classes',
            actionLabel: linksToClasses && ordered.length > _homeClassLimit
                ? 'View all'
                : null,
            onAction: () => context.go('/classes'),
          ),
        ),
        const SizedBox(height: 12),
        if (classesState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            child: Column(
              children: [
                SkeletonBox(height: 80),
                SizedBox(height: 12),
                SkeletonBox(height: 80),
              ],
            ),
          )
        else if (classesState.error != null)
          AppErrorView(
            error: classesState.error!,
            compact: true,
            onRetry: () => ref.read(classesProvider.notifier).refresh(),
          )
        else if (!classesState.hasClasses)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: AppEmptySection(
              icon: Icons.school_outlined,
              message: 'No Classes Yet',
              actionLabel: linksToClasses ? 'See classes' : null,
              onAction: linksToClasses ? () => context.go('/classes') : null,
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final classModel = shown[index];
              // A label opens each kind, so a kind the person lacks has none.
              final opensKind =
                  index == 0 ||
                  _kindLabel(shown[index - 1]) != _kindLabel(classModel);
              final card = _ClassCard(
                classModel: classModel,
                onTap: () {
                  ref.read(selectedClassIdProvider.notifier).state =
                      classModel.id;
                  // Open the class page directly instead of the list.
                  context.push('/classes/${classModel.id}/dashboard');
                },
              );
              if (!opensKind) return card;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _kindLabel(classModel),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mediumText,
                      ),
                    ),
                  ),
                  card,
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  final dynamic classModel;
  final VoidCallback onTap;

  const _ClassCard({required this.classModel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final levelDisplay = classModel.levelName ?? 'Level ${classModel.level}';
    final codeDisplay = classModel.code?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppTheme.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              levelDisplay,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkText,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (codeDisplay.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                codeDisplay,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppTheme.mediumText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              classModel.teacherName ?? 'Teacher',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.mediumText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppTheme.lightText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
