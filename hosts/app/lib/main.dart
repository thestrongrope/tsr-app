import 'features/calendar/calendar_provider.dart';
import 'dart:ui' show PlatformDispatcher;

import 'package:timezone/data/latest_all.dart' as tz;

import 'package:flutter/foundation.dart'
    show
        kIsWeb,
        kReleaseMode,
        debugPrint,
        defaultTargetPlatform,
        TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemChrome
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'firebase_options.dart';
import 'core/config/auth_emulator.dart';
import 'core/config/firebase_override.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/api_client.dart';
import 'core/constants/app_constants.dart';
import 'core/models/user.dart';
import 'core/services/notification_service.dart';
import 'core/services/scheduled_notification_service.dart';
import 'core/version/version_gate.dart';
import 'core/version/version_provider.dart';
import 'features/classes/providers/conduction_queue_provider.dart';
import 'features/feedback/providers/feedback_queue_provider.dart';
import 'features/notifications/providers/notification_target.dart';
import 'core/version/update_required_screen.dart';
import 'core/version/startup_alert_host.dart';
import 'features/wordpress/models/bookmark.dart';
import 'core/widgets/app_error_view.dart';
import 'core/widgets/offline_banner.dart';

// 1. Initialization Provider: Handles heavy lifting in the background
final appInitializationProvider = FutureProvider<void>((ref) async {
  // Initialize Firebase (Critical)
  // Production unless a developer gave their own project (debug builds only).
  await Firebase.initializeApp(
    options:
        firebaseOverride(
          release: kReleaseMode,
          android: defaultTargetPlatform == TargetPlatform.android,
        ) ??
        DefaultFirebaseOptions.currentPlatform,
  );

  // Local login against the Firebase Auth Emulator (debug builds only; the
  // function throws in release).
  final emulator = authEmulatorTarget(release: kReleaseMode);
  if (emulator != null) {
    await FirebaseAuth.instance.useAuthEmulator(emulator.host, emulator.port);
  }

  // Analytics, release builds only, so developer testing does not land in the
  // dashboard alongside real members. The setting persists on the device, so
  // only the very first launch of a fresh debug install can still send the
  // automatic first_open event before this line runs.
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(kReleaseMode);

  // Crash reporting. Release builds are minified and obfuscated, so without
  // this a crash on a user's device tells us nothing. Reports are only useful
  // if the R8 mapping file and iOS dSYMs are uploaded per build; see
  // docs/mobile/app/crashlytics-design.md.
  //
  // Debug builds are excluded so local crashes do not pollute the dashboard.
  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(BookmarkAdapter());

  // Parallelize the rest for speed
  await Future.wait([
    if (!kIsWeb) GoogleSignIn.instance.initialize(),
    Hive.openBox<User>(AppConstants.userBoxKey),
    Hive.openBox(AppConstants.settingsBoxKey),
    Hive.openBox(AppConstants.cacheBoxKey),
    Hive.openBox(AppConstants.offlineBoxKey),
    Hive.openBox(AppConstants.bookmarksBoxKey),
  ]);

  // Initialize API client
  ApiClient().initialize();

  // Initialize Notification Service
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Initialize timezone data for scheduled notifications.
  tz.initializeTimeZones();

  // Initialize Scheduled Notification Service (local class reminders).
  // Must run after the base NotificationService so we can share its plugin.
  if (!kIsWeb) {
    // requestPermission: false — startup only needs the local plugin and the
    // Android channel. The OS prompt stays with the opt-in explainer screen;
    // on iOS it can only be shown once, so asking here would burn it.
    await NotificationService().initialize(requestPermission: false);
    await ScheduledNotificationService.instance.initialize(
      NotificationService().localNotificationsPlugin,
    );
  }

  // FORCE SYSTEM UI VISIBILITY (Fixes the missing system tray)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Keep status bar icons dark (black) across the app. Avoid per-screen overrides.
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ),
  );
});

void main() {
  // Disable console logs in release mode for security and performance
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // 2. Minimal blocking setup for instant launch
  WidgetsFlutterBinding.ensureInitialized();

  // Run App IMMEDIATELY. Do not await heavy services here.
  runApp(const ProviderScope(child: TSRApp()));
}

/// The app's root widget once it is ready: theme, localization and the
/// startup wrappers. One place, so the app and its tests build the same thing.
Widget buildAppShell(RouterConfig<Object> router) {
  return MaterialApp.router(
    title: AppConstants.appName,
    theme: AppTheme.lightTheme,
    routerConfig: router,
    // The guide editor (QuillEditor) throws without these delegates.
    localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
    supportedLocales: FlutterQuillLocalizations.supportedLocales,
    debugShowCheckedModeBanner: false,
    scrollBehavior: const _AppScrollBehavior(),
    themeMode: ThemeMode.light,
    // Dismiss keyboard/focus when tapping anywhere outside an input field.
    builder: (context, child) {
      return StartupAlertHost(
        child: OfflineBanner(
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    },
  );
}

class TSRApp extends ConsumerWidget {
  const TSRApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 3. Watch the initialization status
    final appInitState = ref.watch(appInitializationProvider);

    return appInitState.when(
      // SHOW LOADING SCREEN WHILE BOOTING UP
      loading: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2E7D6B), // Primary Green
            ),
          ),
        ),
      ),
      // SHOW ERROR IF STARTUP FAILS
      error: (err, stack) => MaterialApp(
        home: Scaffold(
          body: AppErrorView(
            error: err,
            onRetry: () => ref.invalidate(appInitializationProvider),
          ),
        ),
      ),
      // SHOW ACTUAL APP WHEN READY
      data: (_) {
        // The update gate. `asData` is null while the check is in flight and
        // when it failed, and both of those mean carry on: the gate only stops
        // someone when it is certain, so an unreachable API can never wall the
        // whole user base. See docs/specs/force-update/design.md.
        final versionCheck = ref.watch(versionCheckProvider).asData?.value;
        if (versionCheck?.status == VersionStatus.updateRequired) {
          return MaterialApp(
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            debugShowCheckedModeBanner: false,
            home: UpdateRequiredScreen(storeUrl: versionCheck!.policy.storeUrl),
          );
        }

        // Sends conduction records saved offline, at start and on reconnect.
        ref.watch(conductionQueueProvider);
        ref.watch(feedbackQueueProvider);
        ref.watch(calendarProvider);

        // Opens what a tapped notification is about (#925).
        ref.watch(notificationTapProvider);

        final router = ref.watch(routerProvider);
        return buildAppShell(router);
      },
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
