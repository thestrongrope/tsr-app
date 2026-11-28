import '../../features/calendar/calendar_screen.dart';
import '../../features/calendar/class_events_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'route_config.dart';
import 'deep_link_provider.dart';
import 'guide_link_entry.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/models/auth_state.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/providers/recent_actions_provider.dart';
import '../../features/home/services/recent_actions_observer.dart';
import '../../features/profile/presentation/profile_completion_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/wordpress/screens/article_detail_screen.dart';
import '../../features/wordpress/screens/publications_list_screen.dart';
import '../../features/wordpress/screens/content_hub_screen.dart';
import '../../features/wordpress/screens/tsr_article_detail_screen.dart';
import '../../features/wordpress/screens/all_articles_screen.dart';
import '../../features/wordpress/screens/all_videos_screen.dart';
import '../../features/wordpress/screens/video_detail_screen.dart';
import '../../features/wordpress/models/tsr_article.dart';
import '../../features/admin/screens/notification_dashboard_screen.dart';
import '../../features/admin/screens/class_events_picker_screen.dart';
import '../../features/admin/screens/access_log_screen.dart';
import '../../features/admin/screens/admin_screen.dart';
import '../../features/reports/screens/active_teachers_screen.dart';
import '../../features/reports/screens/quran_leaderboard_screen.dart';
import '../../features/admin/screens/deactivated_classes_screen.dart';
import '../../features/admin/screens/class_access_screen.dart';
import '../../features/admin/screens/enrol_by_token_screen.dart';
import '../../features/admin/screens/permission_grants_screen.dart';
import '../../features/admin/screens/student_transfers_screen.dart';
import '../../features/admin/screens/deletion_requests_screen.dart';
import '../../features/admin/screens/quiz_admin_screen.dart';
import '../../features/admin/screens/standard_mcqs_screen.dart';
import '../../features/admin/screens/donors_screen.dart';
import '../../features/admin/screens/feedback_review_screen.dart';
import '../../features/admin/screens/guide_editor_screen.dart';
import '../../features/admin/screens/guides_admin_screen.dart';
import '../../features/admin/screens/whatsapp_reminders_screen.dart';
import '../../features/admin/screens/teacher_detail_screen.dart';
import '../../features/admin/screens/teachers_screen.dart';
import '../../features/members/screens/student_card_screen.dart';
import '../../features/search/screens/global_search_screen.dart';
import '../../features/members/screens/subscriber_card_screen.dart';
import '../../features/reports/screens/registrations_screen.dart';
import '../../features/reports/screens/this_week_screen.dart';
import '../../features/reports/screens/class_sessions_screen.dart';
import '../../features/reports/screens/conduction_report_screen.dart';
import '../../features/reports/screens/mcq_adherence_screen.dart';
import '../../features/reports/screens/mcq_summary_screen.dart';
import '../../features/reports/screens/pending_report_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/reports/screens/student_performance_screen.dart';
import '../../features/reports/screens/subject_conduction_screen.dart';
import '../../features/reports/screens/summary_report_screen.dart';
import '../../features/reports/screens/tsr_report_screen.dart';
import '../../features/reports/screens/weekly_report_screen.dart';
import '../../features/admin/screens/send_notification_screen.dart';
import '../../features/admin/screens/notification_history_screen.dart';
import '../../features/admin/screens/syllabus_admin_screen.dart';
import '../../features/notifications/presentation/notification_permission_screen.dart';
import '../../features/notifications/presentation/user_notifications_screen.dart';
import '../../features/classes/providers/providers.dart';
import '../../features/classes/screens/screens.dart';
import '../../features/mcq_manage/screens/screens.dart';
import '../permissions/capabilities.dart';
import '../permissions/capabilities_manage.dart';
import '../permissions/capabilities_router.dart';
import '../providers/permissions_provider.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../widgets/bottom_nav_scaffold.dart';
import '../widgets/sign_in_invite.dart';
import '../version/release_notes_screen.dart';
import '../../features/about/screens/about_screen.dart';
import '../../features/about/screens/accreditation_screen.dart';
import '../../features/about/screens/contact_screen.dart';
import '../../features/feedback/screens/send_feedback_screen.dart';
import '../../features/wordpress/screens/library_screen.dart';
import '../../features/profile/presentation/me_screen.dart';
import '../../features/account_deletion/screens/delete_account_screen.dart';
import '../../features/account_deletion/screens/deletion_pending_screen.dart';
import '../../features/account_deletion/screens/account_deleted_screen.dart';
import '../../features/parent/models/models.dart';
import '../../features/parent/screens/screens.dart';

/// Navigator keys for managing navigation stack
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable for auth state changes - triggers router refresh
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final _routerRefreshNotifier = _RouterRefreshNotifier();

/// Main router provider with deep linking and auth guard support.
///
/// Features:
/// - Deep link preservation: Saves intended destination during auth redirect
/// - Auth guard: Protects routes based on authentication state
/// - Admin guard: Additional permission checks for admin routes
/// - Navigation stack: Proper back-button handling via nested routes
final routerProvider = Provider<GoRouter>((ref) {
  // Remembers whitelisted screens for Home's "Jump back in" card (#726). Each
  // navigator, the root and one per tab, needs an observer of its own.
  NavigatorObserver recentActionsObserver() => RecentActionsObserver(
    (kind, classId) =>
        ref.read(recentActionsProvider.notifier).record(kind, classId: classId),
  );

  // A new router starts again from the splash screen, resetting every tab.
  // That is right when who is signed in changes (signing in or out, account
  // deletion), so only those rebuild it (#561). Anything else - a refreshed
  // profile, reloaded permissions - re-runs the redirect where the member is.
  ref.watch(authStateProvider.select((s) => (s.status, s.deletionStatus)));
  ref.listen(authStateProvider, (_, _) => _routerRefreshNotifier.notify());
  ref.listen(permissionsProvider, (_, _) => _routerRefreshNotifier.notify());

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    // Records a screen_view in Firebase Analytics on each navigation. Without
    // an observer Analytics only reports lifecycle events like first_open and
    // session_start, and no screen data at all.
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      recentActionsObserver(),
    ],
    refreshListenable: _routerRefreshNotifier,
    // A guide link that arrives while the app is open goes on top (#1138).
    onEnter: GuideLinkEntry().call,
    redirect: (context, state) {
      _settleGuestPermissions(ref);
      return _handleRedirect(
        ref,
        ref.read(authStateProvider),
        ref.read(permissionsProvider),
        state,
      );
    },
    routes: _buildRoutes(recentActionsObserver),
    errorBuilder: _buildErrorPage,
  );
});

/// Nobody signed in means no member to ask the server about: settle on what a
/// guest may see, or the shell would wait for an answer that never comes.
void _settleGuestPermissions(Ref ref) {
  final status = ref.read(authStateProvider).status;
  final signedOut =
      status == AuthStatus.guest ||
      status == AuthStatus.unauthenticated ||
      status == AuthStatus.error;
  final permissions = ref.read(permissionsProvider);
  if (!signedOut || permissions.payload != null || permissions.loading) return;
  Future.microtask(() => ref.read(permissionsProvider.notifier).useGuestBase());
}

/// Centralized redirect logic with deep link preservation.
@visibleForTesting
String? handleRedirect(
  Ref ref,
  AuthState authState,
  PermissionsState permissionsState,
  GoRouterState state,
) => _handleRedirect(ref, authState, permissionsState, state);

String? _handleRedirect(
  Ref ref,
  AuthState authState,
  PermissionsState permissionsState,
  GoRouterState state,
) {
  final authStatus = authState.status;
  final currentLocation = state.matchedLocation;
  final fullUri = state.uri.toString();
  final permsState = permissionsState;

  debugPrint(
    '🔍 Router redirect - Auth: $authStatus, Location: $currentLocation',
  );

  // === INITIAL/LOADING STATE ===
  if (authStatus == AuthStatus.initial || authStatus == AuthStatus.loading) {
    if (currentLocation != AppRoutes.splash) {
      // A link that launches the app arrives while auth is still loading.
      // Keep an app link so it can be restored once we know who is here (#861).
      if (AppRoutes.isAppLink(currentLocation)) {
        ref.read(pendingDeepLinkProvider.notifier).setPendingLink(fullUri);
      }
      debugPrint('🔄 Redirecting to splash - auth loading');
      return AppRoutes.splash;
    }
    return null;
  }

  // === ACCOUNT DELETION ===
  // Checked before the permission guards on purpose. While a deletion request
  // is live the API refuses /me/permissions too, so waiting for permissions
  // to load would strand the member on the splash screen.
  if (authState.deletionStatus.isTerminal) {
    debugPrint('🔒 Account deleted, only the terminal screen is reachable');
    return currentLocation == AppRoutes.accountDeleted
        ? null
        : AppRoutes.accountDeleted;
  }

  if (authStatus == AuthStatus.authenticated &&
      authState.deletionStatus.isRestricted) {
    debugPrint('🔒 Deletion pending, restricting navigation');
    return currentLocation == AppRoutes.deletionPending
        ? null
        : AppRoutes.deletionPending;
  }

  // === AUTHENTICATED STATE ===
  if (authStatus == AuthStatus.authenticated) {
    final currentUser = authState.user;

    // Wait for permissions to load: on the splash screen (starting up, signing
    // in), or when there are none yet. A refresh while the member is in the app
    // keeps the permissions they have until the new ones arrive; a trip to the
    // splash screen and back would reset every tab (#561).
    if (permsState.loading &&
        (permsState.payload == null || currentLocation == AppRoutes.splash)) {
      debugPrint('⏳ Permissions loading, staying on splash');
      if (currentLocation != AppRoutes.splash) {
        return AppRoutes.splash;
      }
      return null;
    }

    // Handle permissions loading from cache
    if (permsState.payload == null &&
        !permsState.loading &&
        !permsState.unconfirmed &&
        permsState.error == null) {
      debugPrint('🔄 Loading permissions from cache...');
      _loadPermissionsFromCache(ref);
      if (currentLocation != AppRoutes.splash) {
        return AppRoutes.splash;
      }
      return null;
    }

    // Permissions loaded - handle navigation
    if (permsState.payload != null) {
      // Redirect from splash/login - check for pending deep link first
      if (currentLocation == AppRoutes.splash ||
          currentLocation == AppRoutes.login) {
        // Check profile completion first
        if (currentUser != null && !currentUser.isProfileComplete) {
          debugPrint(
            '⚠️ Profile incomplete, redirecting to profile-completion',
          );
          return AppRoutes.profileCompletion;
        }

        // Check for pending deep link after login
        final pendingLink = _takePendingLink(ref, permsState);
        if (pendingLink != null) return pendingLink;

        debugPrint('🟢 Authenticated, redirecting to home');
        return AppRoutes.home;
      }

      // Handle profile completion redirect when complete
      if (currentLocation == AppRoutes.profileCompletion &&
          currentUser != null &&
          currentUser.isProfileComplete) {
        // A new member who arrived by an MCQ or join link lands on it (#861).
        final pendingLink = _takePendingLink(
          ref,
          permsState,
          onlyAppLink: true,
        );
        if (pendingLink != null) return pendingLink;
        debugPrint('🟢 Profile completed, redirecting to home');
        return AppRoutes.home;
      }

      // === PERMISSION GUARDS ===

      final capabilities = Capabilities.of(
        payload: permsState.payload,
        classes: ref.read(classesProvider).classes,
      );

      // Class guards: the class is in the path (/classes/:classId/...). Its
      // gender comes from the loaded class list (see allowsClassAction).
      final classId = _classIdOf(currentLocation);
      if (classId != null) {
        final classes = ref.read(classesProvider).classes;
        bool allowed(String permission) => capabilities.allowsClassAction(
          permsState,
          permission,
          classId: classId,
          classes: classes,
        );

        if (currentLocation.contains('/conduction') &&
            !allowed('sessions:create')) {
          debugPrint(
            '🚫 No class conduction permission, redirecting to classes',
          );
          return AppRoutes.classes;
        }

        if (currentLocation.contains('/mcq/manage') &&
            !allowed('mcqs:manage')) {
          debugPrint('🚫 No MCQ management permission, redirecting to classes');
          return AppRoutes.classes;
        }

        if (currentLocation.contains('/mcq/manage/') &&
            currentLocation.endsWith('/copy') &&
            !allowed('mcqs:copy')) {
          debugPrint('🚫 No MCQ copy permission, redirecting to classes');
          return AppRoutes.classes;
        }

        if ((currentLocation.contains('/notifications/') ||
                currentLocation.endsWith('/scheduled-events')) &&
            !allowed('notifications:send')) {
          debugPrint(
            '🚫 No class notification permission, redirecting to classes',
          );
          return AppRoutes.classes;
        }

        if (RegExp(r'^/classes/\d+/schedule$').hasMatch(currentLocation) &&
            !allowed('classes:schedule') &&
            !allowed('classes:update')) {
          debugPrint('🚫 No class schedule permission, redirecting to classes');
          return AppRoutes.classes;
        }

        if (RegExp(r'^/classes/\d+/manage$').hasMatch(currentLocation) &&
            !allowed('classes:update')) {
          debugPrint(
            '🚫 No class management permission, redirecting to classes',
          );
          return AppRoutes.classes;
        }

        if (currentLocation.endsWith('/students/performance') &&
            !allowed('mcqs:manage')) {
          debugPrint('🚫 No student figures permission, redirecting');
          return AppRoutes.classes;
        }

        if (RegExp(r'^/classes/\d+/students$').hasMatch(currentLocation) &&
            !allowed('class-students:read')) {
          debugPrint('🚫 No class roster permission, redirecting to classes');
          return AppRoutes.classes;
        }
      }

      // Admin route guard: each admin screen needs the permission of its
      // module; the dashboard needs any of them.
      if (AppRoutes.isAdminRoute(currentLocation)) {
        final hasNotif = capabilities.canBroadcast;
        final hasClassEvents = capabilities.canManageClassEvents;
        final hasSyllabus = capabilities.canUpdateSyllabus;
        final hasReports = capabilities.canReadReports;
        final hasDeactivated = capabilities.canManageDeactivatedClasses;
        final hasTransfers = capabilities.canTransferStudents;
        final hasPermissions = capabilities.canManagePermissions;
        final hasClassAccess = capabilities.canManageClassAccess;
        final hasEnrolByToken = capabilities.canEnrolByToken;
        final hasTeachers = capabilities.canManageTeachers;
        final hasWhatsapp = capabilities.canManageWhatsappReminders;
        final hasDonors = capabilities.canReadDonors;
        final hasGuides = capabilities.canManageGuides;
        final hasAccessLog = capabilities.canReadAuditLog;
        final hasDeletionRequests = capabilities.canManageDeletionRequests;
        final hasFeedbackReview = capabilities.canReviewFeedback;
        final hasStandardMcqs = capabilities.canUpdateStandardMcqs;
        final hasQuizAdmin = capabilities.canAdminQuiz;
        final hasMcqCopy = capabilities.canCopyMcqs;
        final hasAdminDashboard = capabilities.allowsAdminHub;

        if (currentLocation == AppRoutes.admin) {
          if (!hasAdminDashboard) {
            debugPrint('🚫 No admin module, redirecting to home');
            return AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminNotifications ||
            currentLocation == AppRoutes.sendNotification ||
            currentLocation == AppRoutes.notificationHistory) {
          if (!hasNotif) {
            debugPrint('🚫 No notification admin permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminClassEvents) {
          if (!hasClassEvents) {
            debugPrint('No class-event permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminSyllabus) {
          if (!hasSyllabus) {
            debugPrint('🚫 No syllabus admin permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminReports ||
            currentLocation == AppRoutes.adminConductionReport ||
            currentLocation == AppRoutes.adminWeeklyReport ||
            currentLocation == AppRoutes.adminSummaryReport ||
            currentLocation == AppRoutes.adminStudentPerformance ||
            currentLocation == AppRoutes.adminTsrReport ||
            currentLocation == AppRoutes.adminPendingReport ||
            currentLocation == AppRoutes.adminSubjectConduction ||
            currentLocation.startsWith(AppRoutes.adminClassSessions) ||
            currentLocation.startsWith(AppRoutes.adminMcqSummary) ||
            currentLocation.startsWith(AppRoutes.adminMcqAdherence) ||
            currentLocation == AppRoutes.adminActiveTeachers ||
            currentLocation == AppRoutes.adminQuranLeaderboard ||
            currentLocation == AppRoutes.adminRegistrations ||
            currentLocation == AppRoutes.adminThisWeek) {
          if (!hasReports) {
            debugPrint('🚫 No reports permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
          // The leaderboard and the registrations have a permission of their own.
          if (currentLocation == AppRoutes.adminQuranLeaderboard &&
              !capabilities.canReadQuranLeaderboard) {
            debugPrint('🚫 No leaderboard permission');
            return AppRoutes.adminReports;
          }
          if (currentLocation == AppRoutes.adminRegistrations &&
              !capabilities.canReadRegistrations) {
            debugPrint('🚫 No registrations permission');
            return AppRoutes.adminReports;
          }
        } else if (currentLocation == AppRoutes.adminDeactivatedClasses) {
          if (!hasDeactivated) {
            debugPrint('🚫 No deactivated-classes permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminTransfers) {
          if (!hasTransfers) {
            debugPrint('🚫 No students:transfer permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation.startsWith(AppRoutes.adminPermissions)) {
          // The search and a member's view, which is reached from it.
          if (!hasPermissions) {
            debugPrint('🚫 No permissions:manage permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation.startsWith(AppRoutes.adminClassAccess)) {
          // The search and a member's view, which is reached from it.
          if (!hasClassAccess) {
            debugPrint('🚫 No class-access:manage permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminEnrolByToken) {
          if (!hasEnrolByToken) {
            debugPrint('🚫 No members:enrol-by-token permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminAccessLog) {
          if (!hasAccessLog) {
            debugPrint('🚫 No audit-log:read permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation.startsWith(AppRoutes.adminGuides)) {
          // The level list and an editor, which is reached from it.
          if (!hasGuides) {
            debugPrint('🚫 No guides:manage permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminDonors) {
          if (!hasDonors) {
            debugPrint('🚫 No donors permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminDeletionRequests) {
          if (!hasDeletionRequests) {
            debugPrint('🚫 No deletion-requests permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminFeedback) {
          if (!hasFeedbackReview) {
            debugPrint('🚫 No feedback:review permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminStandardMcqs) {
          if (!hasStandardMcqs) {
            debugPrint('🚫 No standard-mcqs:update permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminQuiz) {
          if (!hasQuizAdmin) {
            debugPrint('🚫 No quiz:admin permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminMcqCopy) {
          if (!hasMcqCopy) {
            debugPrint('🚫 No mcqs:copy permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation == AppRoutes.adminWhatsappReminders) {
          if (!hasWhatsapp) {
            debugPrint('🚫 No WhatsApp reminders permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (currentLocation.startsWith(AppRoutes.adminTeachers)) {
          // The list and a teacher's detail, which is reached from the list.
          if (!hasTeachers) {
            debugPrint('🚫 No teachers permission');
            return hasAdminDashboard ? AppRoutes.admin : AppRoutes.home;
          }
        } else if (!hasAdminDashboard) {
          debugPrint('🚫 No admin access, redirecting to home');
          return AppRoutes.home;
        }
      }
    }

    return null;
  }

  // === GUEST STATE (Anonymous browsing) ===
  // Signed out, or a sign-in that failed, browses as a guest too (#555): the
  // app opens on Home and asks for an account only where one is needed.
  if (authStatus == AuthStatus.guest ||
      authStatus == AuthStatus.unauthenticated ||
      authStatus == AuthStatus.error) {
    // Redirect from splash to home
    if (currentLocation == AppRoutes.splash) {
      final pending = ref.read(pendingDeepLinkProvider);
      // The app was opened by a join or article link: show it, which needs
      // no account to look at.
      if (pending != null &&
          (AppRoutes.isJoinLink(pending) || AppRoutes.isArticleLink(pending))) {
        debugPrint('🔗 Guest opened a public link, showing it');
        return _takePendingLink(ref, permsState);
      }
      // The app was opened by an MCQ, parent-invite or guide link: ask for
      // sign-in, which restores it.
      if (pending != null &&
          (AppRoutes.isMcqLink(pending) ||
              AppRoutes.isParentInviteLink(pending) ||
              AppRoutes.isGuideLink(pending))) {
        debugPrint('🔗 Guest opened a link that needs sign-in, to login');
        return AppRoutes.login;
      }
      debugPrint('🟢 Guest mode, redirecting to home');
      return AppRoutes.home;
    }

    // Allow public routes and home page for guests
    if (AppRoutes.isPublicRoute(currentLocation) ||
        currentLocation == AppRoutes.home ||
        currentLocation.startsWith('/home/articles') ||
        currentLocation == AppRoutes.videos ||
        currentLocation == AppRoutes.classes ||
        currentLocation == AppRoutes.me) {
      return null;
    }

    // Save intended destination and redirect to login for protected routes
    debugPrint('🔒 Guest trying to access protected route: $fullUri');
    ref.read(pendingDeepLinkProvider.notifier).setPendingLink(fullUri);
    return AppRoutes.login;
  }

  return null;
}

/// The saved link to restore, or null. Clears it once it is used. With
/// [onlyAppLink] any link but an MCQ or join link is left alone.
String? _takePendingLink(
  Ref ref,
  PermissionsState permsState, {
  bool onlyAppLink = false,
}) {
  final pendingLink = ref.read(pendingDeepLinkProvider);
  if (pendingLink == null) return null;
  if (onlyAppLink && !AppRoutes.isAppLink(pendingLink)) return null;

  debugPrint('🔗 Restoring pending deep link: $pendingLink');
  // Clear the pending link after we use it (delayed to avoid build-phase mutation)
  Future.microtask(() {
    ref.read(pendingDeepLinkProvider.notifier).clear();
  });

  // Validate the pending link is not a protected route we can't access
  final capabilities = Capabilities.of(
    payload: permsState.payload,
    classes: ref.read(classesProvider).classes,
  );
  if (!AppRoutes.isAdminRoute(pendingLink) || capabilities.allowsAdminHub) {
    return pendingLink;
  }
  return null;
}

/// The class id in a `/classes/:classId/...` path, or null.
int? _classIdOf(String location) {
  final match = RegExp(r'^/classes/(\d+)/').firstMatch(location);
  return match == null ? null : int.parse(match.group(1)!);
}

/// Load the saved permissions (non-blocking). With no saved copy the state
/// becomes `unconfirmed`, and the sign-in fetch settles it.
void _loadPermissionsFromCache(Ref ref) {
  Future.microtask(() async {
    try {
      debugPrint('🔵 Loading permissions from cache...');
      await ref.read(permissionsProvider.notifier).loadFromCache();
    } catch (e) {
      debugPrint('🔴 Failed to load permissions: $e');
    }
  });
}

/// Build all application routes.
///
/// The main screens sit in four tabs ([BottomNavScaffold]), each with its own
/// stack. Routes outside the tabs (sign-in, the account screens, taking a
/// quiz) open over them, full screen.
List<RouteBase> _buildRoutes(
  NavigatorObserver Function() recentActionsObserver,
) {
  return [
    // === PUBLIC ROUTES ===
    GoRoute(
      path: '/my-class-alerts',
      name: 'myClassAlerts',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: AppRoutes.splash,
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.search,
      name: RouteNames.search,
      builder: (context, state) => const GlobalSearchScreen(),
    ),
    GoRoute(
      path: AppRoutes.studentCard,
      name: RouteNames.studentCard,
      builder: (context, state) => StudentCardScreen(
        token: int.tryParse(state.pathParameters['token']!) ?? 0,
      ),
    ),
    GoRoute(
      path: AppRoutes.subscriberCard,
      name: RouteNames.subscriberCard,
      builder: (context, state) => SubscriberCardScreen(
        token: int.tryParse(state.pathParameters['token']!) ?? 0,
      ),
    ),
    GoRoute(
      path: AppRoutes.register,
      name: RouteNames.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    // === PROTECTED ROUTES ===
    GoRoute(
      path: AppRoutes.profileCompletion,
      name: RouteNames.profileCompletion,
      builder: (context, state) => const ProfileCompletionScreen(),
    ),
    GoRoute(
      path: AppRoutes.notificationPermission,
      name: RouteNames.notificationPermission,
      builder: (context, state) => const NotificationPermissionScreen(),
    ),
    // === ACCOUNT DELETION (reached by redirect, not by tapping) ===
    GoRoute(
      path: AppRoutes.deletionPending,
      name: RouteNames.deletionPending,
      builder: (context, state) => const DeletionPendingScreen(),
    ),
    GoRoute(
      path: AppRoutes.accountDeleted,
      name: RouteNames.accountDeleted,
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => AccountDeletedScreen(
          someDataRemains: ref.watch(
            authStateProvider.select((s) => s.deletionLeftDataOnDevice),
          ),
        ),
      ),
    ),

    // Legacy route - redirect to /classes
    GoRoute(
      path: '/class-dashboard',
      name: RouteNames.classDashboard,
      redirect: (context, state) => AppRoutes.classes,
    ),

    // A quiz announcement's link (#868): the quiz card is on Home.
    GoRoute(
      path: AppRoutes.homeQuiz,
      name: RouteNames.homeQuiz,
      redirect: (context, state) => AppRoutes.home,
    ),

    // An MCQ link (#860): resolves the code, then opens that MCQ or says why not.
    GoRoute(
      path: AppRoutes.mcqLink,
      name: RouteNames.mcqLink,
      builder: (context, state) =>
          McqLinkScreen(code: state.pathParameters['code']!),
    ),

    // A join link (#815-#817): shows the class the link names.
    GoRoute(
      path: AppRoutes.joinLink,
      name: RouteNames.joinLink,
      builder: (context, state) =>
          JoinLinkScreen(code: state.pathParameters['code']!),
    ),

    // A parent-invite link (#1122): shows whose parent the invite makes you.
    GoRoute(
      path: AppRoutes.parentInviteLink,
      name: RouteNames.parentInviteLink,
      builder: (context, state) =>
          ParentInviteScreen(code: state.pathParameters['code']!),
    ),

    // A guide link (#1138): the level's guide, named by `?guide=<slug>`.
    GoRoute(
      path: AppRoutes.guideLink,
      name: RouteNames.guideLink,
      builder: (context, state) =>
          GuideLinkScreen(slug: state.uri.queryParameters['guide']),
    ),

    // === QUIZ ROUTES (Nested for back-stack) ===
    GoRoute(
      path: '/quizzes/:quizId',
      name: RouteNames.quizTaking,
      builder: buildQuizTakingPage,
      routes: [
        GoRoute(
          path: 'result',
          name: RouteNames.quizResult,
          builder: buildQuizResultPage,
        ),
      ],
    ),

    // === TABS ===
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          BottomNavScaffold(navigationShell: navigationShell),
      branches: [
        // Home
        StatefulShellBranch(
          observers: [recentActionsObserver()],
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: RouteNames.home,
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'articles',
                  name: RouteNames.articles,
                  builder: (context, state) => const ContentHubScreen(),
                  routes: [
                    GoRoute(
                      path: 'detail/:slug',
                      name: RouteNames.articleDetail,
                      builder: (context, state) {
                        final slug = state.pathParameters['slug']!;
                        final numericId = int.tryParse(slug);
                        if (numericId != null) {
                          return ArticleDetailScreen(articleId: numericId);
                        }
                        return TsrArticleDetailScreen(articleSlug: slug);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        // Library
        StatefulShellBranch(
          observers: [recentActionsObserver()],
          routes: [
            GoRoute(
              path: AppRoutes.library,
              name: RouteNames.library,
              builder: (context, state) => const LibraryScreen(),
            ),
            // Public content (sharable deep links)
            GoRoute(
              path: AppRoutes.articles,
              name: RouteNames.allArticles,
              builder: (context, state) => const AllArticlesScreen(),
            ),
            GoRoute(
              path: AppRoutes.articleDetail,
              name: RouteNames.articleBySlug,
              builder: (context, state) {
                final slug = state.pathParameters['slug']!;
                return TsrArticleDetailScreen(articleSlug: slug);
              },
            ),
            GoRoute(
              path: AppRoutes.videos,
              name: RouteNames.allVideos,
              builder: (context, state) => const AllVideosScreen(),
              routes: [
                GoRoute(
                  path: ':videoId',
                  name: RouteNames.videoDetail,
                  builder: (context, state) {
                    final extra = state.extra;
                    return VideoDetailScreen(
                      videoId: state.pathParameters['videoId']!,
                      initialVideo: extra is TsrYouTubeVideo ? extra : null,
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.publications,
              name: RouteNames.publications,
              builder: (context, state) => const PublicationsListScreen(),
            ),
          ],
        ),
        // Classes
        StatefulShellBranch(
          observers: [recentActionsObserver()],
          routes: [
            // === CLASS ROUTES (Nested for back-stack) ===
            GoRoute(
              path: AppRoutes.classes,
              name: RouteNames.classes,
              builder: (context, state) => const SignedInOnly(
                title: 'My Classes',
                message: 'Sign in to see your classes.',
                child: ClassDashboardScreen(),
              ),
              routes: [
                GoRoute(
                  path: ':classId/quizzes',
                  name: RouteNames.classQuizzes,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    return QuizListScreen(classId: classId);
                  },
                ),
                GoRoute(
                  path: ':classId/dashboard',
                  name: RouteNames.classDashboardDetail,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    return ClassDetailScreen(classId: classId);
                  },
                ),
                GoRoute(
                  path: ':classId/performance',
                  name: RouteNames.classPerformance,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    return ClassPerformanceScreen(classId: classId);
                  },
                ),
                GoRoute(
                  path: ':classId/syllabus/:levelId',
                  name: RouteNames.classSyllabus,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    final levelId = int.parse(state.pathParameters['levelId']!);
                    return SyllabusScreen(classId: classId, levelId: levelId);
                  },
                ),
                GoRoute(
                  path: ':classId/guide',
                  name: RouteNames.classGuide,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    return GuideScreen(classId: classId);
                  },
                ),
                GoRoute(
                  path: ':classId/conduction',
                  name: RouteNames.classConduction,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    return ConductionListScreen(classId: classId);
                  },
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: RouteNames.classConductionAdd,
                      builder: (context, state) {
                        final classId = int.parse(
                          state.pathParameters['classId']!,
                        );
                        return ConductionFormScreen(classId: classId);
                      },
                    ),
                    GoRoute(
                      path: ':sessionId/edit',
                      name: RouteNames.classConductionEdit,
                      builder: (context, state) {
                        final classId = int.parse(
                          state.pathParameters['classId']!,
                        );
                        final sessionId = int.parse(
                          state.pathParameters['sessionId']!,
                        );
                        return ConductionFormScreen(
                          classId: classId,
                          sessionId: sessionId,
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: ':classId/mcq/manage',
                  name: RouteNames.classMcqManage,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    return McqManageListScreen(classId: classId);
                  },
                  routes: [
                    GoRoute(
                      path: 'add',
                      name: RouteNames.classMcqManageAdd,
                      builder: (context, state) {
                        final classId = int.parse(
                          state.pathParameters['classId']!,
                        );
                        return McqEditScreen(classId: classId);
                      },
                    ),
                    GoRoute(
                      path: 'standard',
                      name: RouteNames.classMcqManageStandard,
                      builder: (context, state) {
                        final classId = int.parse(
                          state.pathParameters['classId']!,
                        );
                        return McqStandardScreen(classId: classId);
                      },
                    ),
                    GoRoute(
                      path: ':quizId/edit',
                      name: RouteNames.classMcqManageEdit,
                      builder: (context, state) {
                        final classId = int.parse(
                          state.pathParameters['classId']!,
                        );
                        final quizId = int.parse(
                          state.pathParameters['quizId']!,
                        );
                        return McqEditScreen(classId: classId, quizId: quizId);
                      },
                    ),
                    GoRoute(
                      path: ':quizId/scores',
                      name: RouteNames.classMcqManageScores,
                      builder: (context, state) {
                        final quizId = int.parse(
                          state.pathParameters['quizId']!,
                        );
                        return McqScoresScreen(quizId: quizId);
                      },
                    ),
                    GoRoute(
                      path: ':quizId/offline',
                      name: RouteNames.classMcqManageOffline,
                      builder: (context, state) {
                        final quizId = int.parse(
                          state.pathParameters['quizId']!,
                        );
                        return McqOfflineScreen(quizId: quizId);
                      },
                    ),
                    GoRoute(
                      path: ':quizId/copy',
                      name: RouteNames.classMcqManageCopy,
                      builder: (context, state) {
                        final classId = int.parse(
                          state.pathParameters['classId']!,
                        );
                        final quizId = int.parse(
                          state.pathParameters['quizId']!,
                        );
                        return McqCopyScreen(classId: classId, quizId: quizId);
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: ':classId/notifications/send',
                  name: RouteNames.classNotification,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    return ClassSendNotificationScreen(classId: classId);
                  },
                ),
                GoRoute(
                  path: ':classId/scheduled-events',
                  name: 'classEvents',
                  builder: (context, state) => ClassEventsScreen(
                    classId: int.parse(state.pathParameters['classId']!),
                  ),
                ),
                GoRoute(
                  path: ':classId/notifications/scheduled',
                  name: RouteNames.classScheduledNotifications,
                  builder: (context, state) {
                    final classId = int.parse(state.pathParameters['classId']!);
                    return ScheduledNotificationsScreen(classId: classId);
                  },
                ),
                GoRoute(
                  path: ':classId/manage',
                  name: RouteNames.classManage,
                  builder: (context, state) {
                    // ?tab=students opens on the Students tab (the Class Students
                    // tile), ?tab=schedule on the Schedule tab (the schedule card).
                    var initialTab = 0;
                    final tab = state.uri.queryParameters['tab'];
                    if (tab == 'students') {
                      initialTab = ClassManageScreen.studentsTab;
                    } else if (tab == 'schedule') {
                      initialTab = ClassManageScreen.scheduleTab;
                    }
                    return ClassManageScreen(
                      classId: int.parse(state.pathParameters['classId']!),
                      initialTab: initialTab,
                    );
                  },
                ),
                GoRoute(
                  path: ':classId/schedule',
                  name: RouteNames.classSchedule,
                  builder: (context, state) => ClassScheduleScreen(
                    classId: int.parse(state.pathParameters['classId']!),
                  ),
                ),
                GoRoute(
                  path: ':classId/students/performance',
                  name: RouteNames.classStudentFigures,
                  builder: (context, state) => ClassStudentFiguresScreen(
                    classId: int.parse(state.pathParameters['classId']!),
                  ),
                ),
                GoRoute(
                  path: ':classId/students',
                  name: RouteNames.classRoster,
                  builder: (context, state) => ClassRosterScreen(
                    classId: int.parse(state.pathParameters['classId']!),
                  ),
                ),
              ],
            ),
            // === CLASS REGISTRATION ===
            GoRoute(
              path: AppRoutes.classRegistration,
              name: RouteNames.classRegistration,
              builder: (context, state) => const ClassRegistrationScreen(),
            ),
          ],
        ),
        // Manage: the admin tools, for anyone who holds an admin module
        StatefulShellBranch(
          observers: [recentActionsObserver()],
          routes: [
            // === ADMIN ROUTES (Nested for back-stack) ===
            GoRoute(
              path: AppRoutes.admin,
              name: RouteNames.admin,
              builder: (context, state) => const AdminScreen(),
              routes: [
                GoRoute(
                  path: 'class-events',
                  name: RouteNames.adminClassEvents,
                  builder: (context, state) => const ClassEventsPickerScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  name: RouteNames.notificationDashboard,
                  builder: (context, state) =>
                      const NotificationDashboardScreen(),
                ),
                GoRoute(
                  path: 'send-notification',
                  name: RouteNames.sendNotification,
                  builder: (context, state) => const SendNotificationScreen(),
                ),
                GoRoute(
                  path: 'notification-history',
                  name: RouteNames.notificationHistory,
                  builder: (context, state) =>
                      const NotificationHistoryScreen(),
                ),
                GoRoute(
                  path: 'syllabus',
                  name: RouteNames.adminSyllabus,
                  builder: (context, state) => const SyllabusAdminScreen(),
                ),
                GoRoute(
                  path: 'deactivated-classes',
                  name: RouteNames.adminDeactivatedClasses,
                  builder: (context, state) => const DeactivatedClassesScreen(),
                ),
                GoRoute(
                  path: 'transfers',
                  name: RouteNames.adminTransfers,
                  builder: (context, state) => const StudentTransfersScreen(),
                ),
                GoRoute(
                  path: 'permissions',
                  name: RouteNames.adminPermissions,
                  builder: (context, state) => const PermissionGrantsScreen(),
                  routes: [
                    GoRoute(
                      path: ':token',
                      name: RouteNames.adminPermissionMember,
                      builder: (context, state) => MemberPermissionsScreen(
                        token:
                            int.tryParse(state.pathParameters['token']!) ?? 0,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'class-access',
                  name: RouteNames.adminClassAccess,
                  builder: (context, state) => const ClassAccessScreen(),
                  routes: [
                    GoRoute(
                      path: ':token',
                      name: RouteNames.adminClassAccessMember,
                      builder: (context, state) => MemberClassAccessScreen(
                        token:
                            int.tryParse(state.pathParameters['token']!) ?? 0,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'enrol-by-token',
                  name: RouteNames.adminEnrolByToken,
                  builder: (context, state) => const EnrolByTokenScreen(),
                ),
                GoRoute(
                  path: 'access-log',
                  name: RouteNames.adminAccessLog,
                  builder: (context, state) => const AccessLogScreen(),
                ),
                GoRoute(
                  path: 'guides',
                  name: RouteNames.adminGuides,
                  builder: (context, state) => const GuidesAdminScreen(),
                  routes: [
                    GoRoute(
                      path: ':levelId',
                      name: RouteNames.adminGuideEditor,
                      builder: (context, state) => GuideEditorScreen(
                        levelId:
                            int.tryParse(state.pathParameters['levelId']!) ?? 0,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'donors',
                  name: RouteNames.adminDonors,
                  builder: (context, state) => const DonorsScreen(),
                ),
                GoRoute(
                  path: 'deletion-requests',
                  name: RouteNames.adminDeletionRequests,
                  builder: (context, state) => const DeletionRequestsScreen(),
                ),
                GoRoute(
                  path: 'feedback',
                  name: RouteNames.adminFeedback,
                  builder: (context, state) => const FeedbackReviewScreen(),
                ),
                GoRoute(
                  path: 'standard-mcqs',
                  name: RouteNames.adminStandardMcqs,
                  builder: (context, state) => const StandardMcqsScreen(),
                ),
                GoRoute(
                  path: 'quiz',
                  name: RouteNames.adminQuiz,
                  builder: (context, state) => const QuizAdminScreen(),
                ),
                GoRoute(
                  path: 'mcq-copy',
                  name: RouteNames.adminMcqCopy,
                  builder: (context, state) => const McqCopyPickerScreen(),
                ),
                GoRoute(
                  path: 'whatsapp-reminders',
                  name: RouteNames.adminWhatsappReminders,
                  builder: (context, state) => const WhatsappRemindersScreen(),
                ),
                GoRoute(
                  path: 'teachers',
                  name: RouteNames.adminTeachers,
                  builder: (context, state) => const TeachersScreen(),
                  routes: [
                    GoRoute(
                      path: ':token',
                      name: RouteNames.adminTeacher,
                      builder: (context, state) => TeacherDetailScreen(
                        token:
                            int.tryParse(state.pathParameters['token']!) ?? 0,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'reports',
                  name: RouteNames.adminReports,
                  builder: (context, state) => const ReportsScreen(),
                ),
                GoRoute(
                  path: 'reports/conduction',
                  name: RouteNames.adminConductionReport,
                  builder: (context, state) => const ConductionReportScreen(),
                ),
                GoRoute(
                  path: 'reports/weekly',
                  name: RouteNames.adminWeeklyReport,
                  builder: (context, state) => const WeeklyReportScreen(),
                ),
                GoRoute(
                  path: 'reports/summary',
                  name: RouteNames.adminSummaryReport,
                  builder: (context, state) => const SummaryReportScreen(),
                ),
                GoRoute(
                  path: 'reports/students',
                  name: RouteNames.adminStudentPerformance,
                  builder: (context, state) => const StudentPerformanceScreen(),
                ),
                GoRoute(
                  path: 'reports/tsr',
                  name: RouteNames.adminTsrReport,
                  builder: (context, state) => const TsrReportScreen(),
                ),
                GoRoute(
                  path: 'reports/pending',
                  name: RouteNames.adminPendingReport,
                  builder: (context, state) => const PendingReportScreen(),
                ),
                GoRoute(
                  path: 'reports/subject-conduction',
                  name: RouteNames.adminSubjectConduction,
                  builder: (context, state) => const SubjectConductionScreen(),
                ),
                GoRoute(
                  path: 'reports/class-sessions',
                  name: RouteNames.adminClassSessions,
                  builder: (context, state) => const ClassSessionsScreen(),
                  routes: [
                    GoRoute(
                      path: ':classId',
                      name: RouteNames.adminClassSessionHistory,
                      builder: (context, state) => ClassSessionHistoryScreen(
                        classId: int.parse(state.pathParameters['classId']!),
                        title: state.extra as String?,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'reports/mcq-summary',
                  name: RouteNames.adminMcqSummary,
                  builder: (context, state) => const McqSummaryScreen(),
                  routes: [
                    GoRoute(
                      path: ':classId',
                      name: RouteNames.adminMcqSummaryClass,
                      // The class's period comes from the list that opened it;
                      // opened any other way there is nothing to show.
                      redirect: (context, state) =>
                          state.extra is McqSummaryClassArgs
                          ? null
                          : AppRoutes.adminMcqSummary,
                      builder: (context, state) => McqSummaryClassScreen(
                        classId: int.parse(state.pathParameters['classId']!),
                        args: state.extra as McqSummaryClassArgs,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'reports/mcq-adherence',
                  name: RouteNames.adminMcqAdherence,
                  builder: (context, state) => const McqAdherenceScreen(),
                  routes: [
                    GoRoute(
                      path: ':classId',
                      name: RouteNames.adminMcqAdherenceClass,
                      // The class's gender comes from the list that opened it;
                      // opened any other way there is nothing to show.
                      redirect: (context, state) =>
                          state.extra is McqAdherenceClassArgs
                          ? null
                          : AppRoutes.adminMcqAdherence,
                      builder: (context, state) => McqAdherenceClassScreen(
                        classId: int.parse(state.pathParameters['classId']!),
                        args: state.extra as McqAdherenceClassArgs,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'reports/active-teachers',
                  name: RouteNames.adminActiveTeachers,
                  builder: (context, state) => const ActiveTeachersScreen(),
                ),
                GoRoute(
                  path: 'reports/quran-leaderboard',
                  name: RouteNames.adminQuranLeaderboard,
                  builder: (context, state) => const QuranLeaderboardScreen(),
                ),
                GoRoute(
                  path: 'this-week',
                  name: RouteNames.adminThisWeek,
                  builder: (context, state) => const ThisWeekScreen(),
                ),
                GoRoute(
                  path: 'reports/registrations',
                  name: RouteNames.adminRegistrations,
                  builder: (context, state) => const RegistrationsScreen(),
                ),
              ],
            ),
          ],
        ),
        // Me: profile and notifications
        StatefulShellBranch(
          observers: [recentActionsObserver()],
          routes: [
            GoRoute(
              path: AppRoutes.me,
              name: RouteNames.me,
              builder: (context, state) => const SignedInOnly(
                title: 'Me',
                message: 'Sign in to see your profile and notifications.',
                guestFooter: AppVersionTile(),
                child: MeScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.releaseNotes,
              name: RouteNames.releaseNotes,
              builder: (context, state) => const ReleaseNotesScreen(),
            ),
            GoRoute(
              path: AppRoutes.about,
              name: RouteNames.about,
              builder: (context, state) => const AboutScreen(),
            ),
            GoRoute(
              path: AppRoutes.accreditation,
              name: RouteNames.accreditation,
              builder: (context, state) => const AccreditationScreen(),
            ),
            GoRoute(
              path: AppRoutes.contact,
              name: RouteNames.contact,
              builder: (context, state) => const ContactScreen(),
            ),
            GoRoute(
              path: AppRoutes.sendFeedback,
              name: RouteNames.sendFeedback,
              builder: (context, state) => const SignedInOnly(
                title: 'Send feedback',
                message: 'Sign in to send us feedback.',
                child: SendFeedbackScreen(),
              ),
            ),
            // === PROFILE ROUTES (Nested for back-stack) ===
            GoRoute(
              path: AppRoutes.profile,
              name: RouteNames.profile,
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  name: RouteNames.editProfile,
                  builder: (context, state) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: 'delete',
                  name: RouteNames.deleteAccount,
                  builder: (context, state) => const DeleteAccountScreen(),
                ),
              ],
            ),

            GoRoute(
              path: AppRoutes.notifications,
              name: RouteNames.userNotifications,
              builder: (context, state) => const UserNotificationsScreen(),
            ),

            // === PARENT & CHILDREN ROUTES (#633) ===
            GoRoute(
              path: AppRoutes.myChildren,
              name: RouteNames.myChildren,
              builder: (context, state) => const MyChildrenScreen(),
            ),
            GoRoute(
              path: AppRoutes.childClasses,
              name: RouteNames.childClasses,
              builder: (context, state) {
                final childToken =
                    int.tryParse(state.pathParameters['childToken'] ?? '') ?? 0;
                final extra = state.extra;
                return ChildClassesScreen(
                  childToken: childToken,
                  initialChild: extra is ChildModel ? extra : null,
                );
              },
            ),
            GoRoute(
              path: AppRoutes.childClassPerformance,
              name: RouteNames.childClassPerformance,
              builder: (context, state) {
                final childToken =
                    int.tryParse(state.pathParameters['childToken'] ?? '') ?? 0;
                final classId =
                    int.tryParse(state.pathParameters['classId'] ?? '') ?? 0;
                return ChildClassPerformanceScreen(
                  childToken: childToken,
                  classId: classId,
                );
              },
            ),
            GoRoute(
              path: AppRoutes.parentLinks,
              name: RouteNames.parentLinks,
              builder: (context, state) => const ParentLinksScreen(),
            ),
            GoRoute(
              path: AppRoutes.myParents,
              name: RouteNames.myParents,
              builder: (context, state) => const MyParentsScreen(),
            ),
          ],
        ),
      ],
    ),
  ];
}

/// Build error page for unknown routes.
/// The MCQ screen. A link can carry any text as the id, so one that is not a
/// number shows "Page not found" in place of crashing.
@visibleForTesting
Widget buildQuizTakingPage(BuildContext context, GoRouterState state) {
  final quizId = int.tryParse(state.pathParameters['quizId']!);
  if (quizId == null) return _buildErrorPage(context, state);
  return QuizTakingScreen(quizId: quizId);
}

/// The MCQ result screen; same rule for a bad id.
@visibleForTesting
Widget buildQuizResultPage(BuildContext context, GoRouterState state) {
  final quizId = int.tryParse(state.pathParameters['quizId']!);
  if (quizId == null) return _buildErrorPage(context, state);
  return QuizResultScreen(quizId: quizId);
}

Widget _buildErrorPage(BuildContext context, GoRouterState state) {
  return Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'The page you are looking for does not exist.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Go to Home'),
          ),
        ],
      ),
    ),
  );
}
