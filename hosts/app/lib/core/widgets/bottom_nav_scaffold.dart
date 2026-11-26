import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../permissions/capabilities.dart';
import '../providers/permissions_provider.dart';
import '../theme/app_theme.dart';
import 'permissions_unconfirmed_view.dart';
import 'glass_bottom_nav_bar.dart';
import 'tab_bar_inset.dart';
import '../../features/notifications/providers/user_notifications_provider.dart';

/// The branches of the tab shell, in the order the router declares them.
const _homeBranch = 0;
const _libraryBranch = 1;
const _classesBranch = 2;
const _manageBranch = 3;
const _meBranch = 4;

/// The tabs at the bottom of the main screens: Home, Library and Me for
/// everyone; Classes (#643) for anyone who attends, conducts or manages a class;
/// and Manage (between Classes and Me) for anyone who holds an admin module.
///
/// Each tab keeps its own stack ([StatefulNavigationShell]), so switching tabs
/// returns to where the member left it; tapping the tab already open goes back
/// to its starting screen.
///
/// The floating bar shows on every screen inside a tab, so a member can switch
/// tabs from any of them; it is not shown outside the tabs (sign-in and the
/// like). Pages scroll behind it, and read its height as their bottom padding
/// (`withTabBarInset`) so the last item ends above it.
class BottomNavScaffold extends ConsumerWidget {
  const BottomNavScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranch = navigationShell.currentIndex;
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final permissionsKnown = ref.watch(
      permissionsProvider.select((s) => s.payload != null),
    );
    if (!permissionsKnown) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: PermissionsUnconfirmedView(),
      );
    }
    final capabilities = ref.watch(capabilitiesProvider);
    final isManager = capabilities.showManageTab;
    final hasClasses = capabilities.showClassesTab;

    // The branches whose tab is shown, in tab order.
    final shown = [
      _homeBranch,
      _libraryBranch,
      if (hasClasses) _classesBranch,
      if (isManager) _manageBranch,
      _meBranch,
    ];

    // A member who loses every admin permission while on Manage, or every class
    // while on Classes, goes Home: the tab they are on is gone.
    if ((currentBranch == _manageBranch && !isManager) ||
        (currentBranch == _classesBranch && !hasClasses)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => navigationShell.goBranch(_homeBranch),
      );
    }

    // Back reaches here only on a tab's starting screen: the tab's own stack
    // pops first. From Home it leaves the app; from any other tab it goes Home.
    return PopScope(
      canPop: currentBranch == _homeBranch,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) navigationShell.goBranch(_homeBranch);
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        // The page runs behind the floating bar, which blurs it; the body's
        // bottom padding becomes the bar's height (see withTabBarInset).
        extendBody: true,
        body: Builder(
          builder: (context) {
            // Here the body's bottom padding is the bar's height.
            final lift =
                MediaQuery.paddingOf(context).bottom -
                MediaQuery.viewPaddingOf(context).bottom;
            return TabBarScope(
              fabLift: lift < 0 ? 0 : lift,
              child: navigationShell,
            );
          },
        ),
        bottomNavigationBar: GlassBottomNavBar(
          selectedIndex: shown.contains(currentBranch)
              ? shown.indexOf(currentBranch)
              : 0,
          onDestinationSelected: (index) => navigationShell.goBranch(
            shown[index],
            initialLocation: shown[index] == currentBranch,
          ),
          destinations: [
            for (final branch in shown) _destination(branch, unreadCount),
          ],
        ),
      ),
    );
  }

  GlassNavDestination _destination(int branch, int unreadCount) {
    switch (branch) {
      case _homeBranch:
        return const GlassNavDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Home',
        );
      case _libraryBranch:
        return const GlassNavDestination(
          icon: Icons.local_library_outlined,
          selectedIcon: Icons.local_library_rounded,
          label: 'Library',
        );
      case _classesBranch:
        return const GlassNavDestination(
          icon: Icons.school_outlined,
          selectedIcon: Icons.school_rounded,
          label: 'Classes',
        );
      case _manageBranch:
        return const GlassNavDestination(
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings_rounded,
          label: 'Manage',
        );
      default:
        return GlassNavDestination(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Me',
          badgeCount: unreadCount,
        );
    }
  }
}
