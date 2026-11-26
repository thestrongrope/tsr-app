import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/permissions/capabilities.dart';
import '../../../core/permissions/capabilities_home.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/providers/permissions_provider.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/classes_provider.dart';
import '../../grand_quiz/providers/grand_quiz_provider.dart';
import '../../grand_quiz/widgets/grand_quiz_banner.dart';
import '../../notifications/providers/user_notifications_provider.dart';
import 'widgets/home_header.dart';
import 'widgets/home_banner.dart';
import 'widgets/jump_back_in_card.dart';
import 'widgets/latest_videos.dart';
import 'widgets/latest_articles.dart';
import 'widgets/my_classes_widget.dart';
import 'widgets/teaching_shortcuts.dart';
import 'widgets/this_week_card.dart';
import '../../../core/widgets/tab_bar_inset.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RefreshableMixin {
  @override
  void initState() {
    super.initState();
    // Load classes for every registered member: a teacher or manager has
    // classes without being enrolled, and a member with none sees how to join.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasRegisteredMember()) {
        ref.read(classesProvider.notifier).loadClasses();
      }
      // Load grand/mega quiz info
      ref.read(grandQuizProvider.notifier).loadQuizInfo();
      // Load notifications to display unread indicator on notification icon
      ref
          .read(userNotificationsProvider.notifier)
          .fetchNotifications(refresh: true);
    });
  }

  // A guest or unfinished sign-up has token 0 and no classes to ask for.
  bool _hasRegisteredMember() {
    final user = ref.read(currentUserProvider);
    return user != null && user.token > 0;
  }

  @override
  Future<void> onRefresh() async {
    try {
      debugPrint('🔄 Pull-to-refresh triggered on Home Screen');

      if (!mounted) return;

      final loadsClasses = _hasRegisteredMember();

      // Refresh data
      final refreshTasks = [
        ref.read(authStateProvider.notifier).refreshUser(),
        ref
            .read(userNotificationsProvider.notifier)
            .fetchNotifications(refresh: true),
      ];

      // Refresh grand/mega quiz info
      refreshTasks.add(ref.read(grandQuizProvider.notifier).refresh());

      // Only registered members have classes
      if (loadsClasses) {
        refreshTasks.add(ref.read(classesProvider.notifier).refresh());
      }

      await Future.wait(refreshTasks);

      if (!mounted) return;

      await ref.read(permissionsProvider.notifier).silentRefresh();

      if (!mounted) return;
      if (ref.read(permissionsProvider).error != null) {
        showRefreshError('Could not check what you can access. Try again.');
        return;
      }
      showRefreshSuccess('Home data refreshed');
    } catch (e) {
      debugPrint('🔴 Home screen refresh failed: ');
      if (mounted) {
        showRefreshError('Failed to refresh home data');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isSignedIn =
        ref.watch(authStateProvider).status == AuthStatus.authenticated;
    // The user can arrive after this screen opens; load the list then.
    ref.listen(currentUserProvider, (_, _) {
      final state = ref.read(classesProvider);
      if (_hasRegisteredMember() && state.classes == null && !state.isLoading) {
        ref.read(classesProvider.notifier).loadClasses();
      }
    });
    final classesLoading = ref.watch(
      classesProvider.select((s) => s.isLoading),
    );
    final showMyClasses =
        _hasRegisteredMember() &&
        ref
            .watch(capabilitiesProvider)
            .showMyClasses(classesLoading: classesLoading);
    final shouldShowQuizBanner = ref.watch(shouldShowQuizBannerProvider);

    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.subtleGreenGradient),
      child: Column(
        children: [
          // Fixed Header
          HomeHeader(currentUser: currentUser),
          const PermissionsStaleNotice(),
          // Scrollable Content
          Expanded(
            child: RefreshableContent(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: ContentWidthCap(
                      child: Column(
                        children: [
                          if (!isSignedIn) ...[
                            const SizedBox(height: 12),
                            const SignInInvite(
                              message:
                                  'Sign in to see your classes and notifications.',
                            ),
                          ],
                          const SizedBox(height: 12),
                          const HomeBanner(),
                          if (shouldShowQuizBanner) ...[
                            const SizedBox(height: 12),
                            const GrandQuizBanner(),
                          ],
                          const ThisWeekCard(),
                          if (showMyClasses)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppTheme.screenPadding,
                                right: AppTheme.screenPadding,
                                top: AppTheme.spacingMD,
                              ),
                              // The card is the Material the ListTile paints on.
                              child: AppSurfaceCard(
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  leading: const Icon(Icons.event_note),
                                  title: const Text('My class alerts'),
                                  onTap: () => context.push('/my-class-alerts'),
                                ),
                              ),
                            ),
                          const JumpBackInCard(),
                          const TeachingShortcuts(),
                          const SizedBox(height: 24),
                          if (showMyClasses) ...[
                            const MyClassesWidget(),
                            const SizedBox(height: 24),
                          ],
                          const LatestArticles(),
                          const SizedBox(height: 24),
                          const LatestVideos(),
                          SizedBox(height: withTabBarInset(context).bottom),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
