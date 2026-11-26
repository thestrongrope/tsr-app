import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/user.dart' as app_user;
import '../../../core/services/notification_service.dart';
import '../../../core/services/local_data_cleaner.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/providers/permissions_provider.dart';
import '../../classes/providers/classes_provider.dart';
import '../../account_deletion/models/deletion_request.dart';
import '../../account_deletion/repositories/deletion_repository.dart';
import '../models/auth_state.dart';

// Suggestion 1: Provide ApiClient via Riverpod for better dependency management.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Whether to offer Apple sign-in. iOS gets the native sheet; Android and web
/// would need a Services ID and OAuth code flow configured on the Firebase
/// Apple provider, which is deliberately not set up, so the button is hidden
/// there rather than shown and broken.
bool get showAppleSignIn =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Authentication service provider
final authServiceProvider = Provider<AuthService>((ref) {
  // Inject the ref to allow AuthService to read other providers.
  return AuthService(ref);
});

/// Current authentication state provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

/// Current user provider
final currentUserProvider = Provider<app_user.User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.user;
});

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(const AuthState()) {
    // Any request refused by the deletion gate carries the state that caused
    // it, so a refusal on any screen updates this one place.
    _deletionSignals = ApiClient().deletionSignals.listen(
      (raw) => applyDeletionStatus(DeletionStatus.fromApi(raw)),
    );

    // Schedule initialization to avoid state modification during build
    Future.microtask(() => _initializeAuth());
  }

  final AuthService _authService;
  late final StreamSubscription<String> _deletionSignals;

  @override
  void dispose() {
    _deletionSignals.cancel();
    super.dispose();
  }

  /// Initialize authentication on app start
  Future<void> _initializeAuth() async {
    debugPrint('🔵 Initializing authentication...');
    state = state.copyWith(status: AuthStatus.loading);
    try {
      // Add timeout to prevent infinite loading
      final user = await _authService.getCurrentUser().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('🔴 Auth initialization timed out');
          throw Exception('Authentication initialization timed out');
        },
      );

      if (user != null) {
        debugPrint('🟢 User found during initialization: ${user.email}');

        // CRITICAL: Load cached permissions BEFORE updating auth state to authenticated
        // This ensures the router has permissions available when it sees authenticated status
        await _loadCachedPermissionsSync();

        // Initialize notifications in background (don't await to keep startup fast)
        if (!kIsWeb) {
          NotificationService()
              .initialize()
              .then((_) {
                debugPrint('🔔 NotificationService initialized after auth');
              })
              .catchError((e) {
                debugPrint(
                  '❌ Failed to initialize NotificationService after auth: $e',
                );
              });
        }

        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        _refreshDeletionStatusAfterAuth();
      } else {
        debugPrint('🔴 No user found during initialization');
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('🔴 Auth initialization failed: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _mapErrorToMessage(e),
      );
    }
  }

  /// Load cached permissions synchronously before auth state update
  /// This ensures permissions are available when router checks them
  Future<void> _loadCachedPermissionsSync() async {
    try {
      debugPrint('🔵 Loading cached permissions synchronously...');
      // Use the simplified init() method which handles all the logic internally
      final notifier = _authService._ref.read(permissionsProvider.notifier);
      await notifier.init();
      // Ask the server too: a member with no saved copy waits for the answer,
      // one with a copy sees it at once while this runs behind it.
      unawaited(notifier.fetchAndSave());

      final currentState = _authService._ref.read(permissionsProvider);
      if (currentState.payload != null) {
        debugPrint(
          '🟢 Cached permissions loaded: ${currentState.payload!.permissions.length} permissions',
        );
        debugPrint('🟢 Permissions list: ${currentState.payload!.permissions}');
      } else {
        debugPrint('🟡 No saved permissions, waiting for the server');
      }
    } catch (e) {
      debugPrint('🔴 Failed to load cached permissions: $e');
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() {
    return _signIn('Google Sign-In', () => _authService.signInWithGoogle());
  }

  /// Sign in with an email address and password
  Future<void> signInWithEmail(String email, String password) {
    return _signIn(
      'Email Sign-In',
      () => _authService.signInWithEmail(email, password),
    );
  }

  /// Sign in with Apple
  Future<void> signInWithApple() {
    return _signIn('Apple Sign-In', () => _authService.signInWithApple());
  }

  /// Run a sign-in method and move the state along with its result.
  /// Every sign-in method behaves the same way once Firebase has answered.
  Future<void> _signIn(
    String label,
    Future<app_user.User> Function() signIn,
  ) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      debugPrint('Starting $label...');
      final user = await signIn();
      debugPrint('$label successful, user: ${user.email}');
      // Reset the deletion state: this may be a new account signing in on a
      // device where the previous one was deleted.
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        deletionStatus: DeletionStatus.none,
      );

      // Initialize notifications after login
      if (!kIsWeb) {
        NotificationService()
            .initialize()
            .then((_) {
              debugPrint('🔔 NotificationService initialized after login');
            })
            .catchError((e) {
              debugPrint(
                '❌ Failed to initialize NotificationService after login: $e',
              );
            });
      }

      // Fetch permissions after state is updated
      _fetchPermissionsAfterAuth();
      _refreshDeletionStatusAfterAuth();

      debugPrint('Auth state updated to authenticated');
    } catch (e) {
      debugPrint('$label failed: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: _mapErrorToMessage(e),
      );
    }
  }

  /// Read the deletion state from the API (non-blocking).
  ///
  /// `GET /me/deletion-request` is on the restricted-session allow-list, so
  /// this answers even while a request is pending.
  void _refreshDeletionStatusAfterAuth() {
    Future.microtask(refreshDeletionStatus);
  }

  /// Ask the API what deletion state this account is in.
  Future<void> refreshDeletionStatus() async {
    try {
      final request = await DeletionRepository().fetch();
      await applyDeletionStatus(request.status);
    } catch (e) {
      debugPrint('🔴 Failed to read deletion status: $e');
    }
  }

  /// Move to a deletion state observed anywhere in the app.
  Future<void> applyDeletionStatus(DeletionStatus status) async {
    if (status == state.deletionStatus) return;

    if (status.isTerminal) {
      await _wipeAfterDeletion();
      return;
    }

    debugPrint('🔵 Deletion status is now $status');
    state = state.copyWith(deletionStatus: status);
  }

  /// Leave the terminal deletion screen, so signing in is reachable again.
  ///
  /// Signing in after this creates a genuinely new account, which is intended.
  void acknowledgeDeletion() {
    state = state.copyWith(
      deletionStatus: DeletionStatus.none,
      deletionLeftDataOnDevice: false,
    );
  }

  /// The account is gone: clear this device and stop.
  ///
  /// Deliberately does not re-authenticate. A Firebase ID token stays valid for
  /// up to an hour after the Firebase user is deleted, so calling `/auth/link`
  /// here would make the API auto-provision a fresh row and silently resurrect
  /// the account that was just removed.
  Future<void> _wipeAfterDeletion() async {
    debugPrint('🔵 Account deletion completed — clearing local state');
    // Marked before the await, not after: the API refuses every route once a
    // deletion completes, so several in-flight requests announce this at the
    // same moment. Without this the guard in applyDeletionStatus lets each of
    // them start its own sign-out.
    state = state.copyWith(deletionStatus: DeletionStatus.completed);
    // A removal that fails never stops the sign-out; the member is told.
    final failed = await clearPerUserLocalData();
    // Each sign-out step is guarded on its own: a failed Google sign-out
    // (offline) must not leave the tokens or the profile on the device.
    failed.addAll(await _authService.clearSession());
    // The in-memory copies too, so nothing shows until the next sign-in.
    await _clearPermissionsAfterSignOut();
    try {
      _authService._ref.read(classesProvider.notifier).clear();
    } catch (e) {
      debugPrint('🟡 Clearing classes after deletion failed: $e');
    }
    state = AuthState(
      status: AuthStatus.unauthenticated,
      deletionStatus: DeletionStatus.completed,
      deletionLeftDataOnDevice: failed.isNotEmpty,
    );
  }

  /// Fetch permissions after authentication (non-blocking)
  /// This is called after login to get fresh permissions from the server
  void _fetchPermissionsAfterAuth() {
    Future.microtask(() async {
      try {
        debugPrint('🔵 Fetching fresh permissions after authentication...');
        await _authService._ref
            .read(permissionsProvider.notifier)
            .fetchAndSave();
        debugPrint('🟢 Fresh permissions fetched and saved successfully');
      } catch (e) {
        debugPrint('🔴 Failed to fetch permissions after auth: $e');
      }
    });
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      debugPrint('🔵 Starting sign out process...');

      // Try device unregistration with a shorter timeout (don't let it block logout)
      try {
        await _authService._unregisterDevice().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint(
              '🟡 Device unregistration timed out, continuing with logout',
            );
          },
        );
      } catch (e) {
        debugPrint(
          '🟡 Device unregistration failed, continuing with logout: $e',
        );
      }

      // Drop the FCM token so this device stops receiving the member's pushes.
      // Runs whether or not the unregister above succeeded; never blocks.
      try {
        await NotificationService().deleteToken().timeout(
          const Duration(seconds: 3),
        );
      } catch (e) {
        debugPrint('🟡 FCM token delete failed, continuing with logout: $e');
      }

      // Clear per-user local data (grand quiz cache, offline box, bookmarks)
      await clearPerUserLocalData();

      // Perform core sign out operations (excluding device unregistration)
      await _authService.signOutWithoutDeviceUnregister().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('🔴 Core sign out timed out, forcing completion');
          throw Exception('Core sign out operation timed out');
        },
      );

      // Clear permissions cache
      try {
        await _clearPermissionsAfterSignOut().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint(
              '🟡 Permissions clear timed out, continuing with logout',
            );
          },
        );
      } catch (e) {
        debugPrint('🟡 Permissions clear failed, continuing with logout: $e');
      }

      // Clear classes state and cache (Issue #6 fix)
      try {
        await _clearClassesStateAfterSignOut();
      } catch (e) {
        debugPrint('🟡 Classes clear failed, continuing with logout: $e');
      }

      // Set to unauthenticated after all cleanup is complete
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        error: null,
        deletionStatus: DeletionStatus.none,
      );
      debugPrint('🟢 Sign out completed successfully');
    } catch (e) {
      debugPrint('🔴 Sign out failed: $e');
      // Even if sign out fails, force unauthenticated state to prevent getting stuck
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        error: null, // Don't show error to user for forced logout
        deletionStatus: DeletionStatus.none,
      );
      debugPrint('🟢 Forced sign out completion to prevent stuck state');
    }
  }

  /// Clear permissions after sign out (blocking to ensure cleanup completes)
  Future<void> _clearPermissionsAfterSignOut() async {
    try {
      await _authService._ref.read(permissionsProvider.notifier).clear();
    } catch (e) {
      debugPrint('Failed to clear permissions after sign out: $e');
    }
  }

  /// Clear classes state and cache after sign out
  Future<void> _clearClassesStateAfterSignOut() async {
    try {
      // Clear the classes provider state
      _authService._ref.read(classesProvider.notifier).clear();

      // Clear the classes cache asynchronously via repository provider
      final repository = _authService._ref.read(classesRepositoryProvider);
      await repository.clearCache();

      debugPrint('🟢 Classes state and cache cleared after sign out');
    } catch (e) {
      debugPrint('Failed to clear classes after sign out: $e');
    }
  }

  /// Maps different exception types to a user-friendly string.
  String _mapErrorToMessage(Object e) {
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'network-request-failed':
          return 'Please check your internet connection and try again.';
        case 'user-cancelled':
        case 'popup-closed-by-user':
        case 'canceled':
        case 'web-context-canceled':
          return 'The sign-in process was cancelled.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email address but different sign-in credentials.';
        // Firebase's email enumeration protection collapses wrong-password and
        // user-not-found into invalid-credential, so this is the case a failed
        // password sign-in actually lands in.
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password.';
        case 'invalid-email':
          return 'That does not look like a valid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many sign-in attempts. Please wait a few minutes and try again.';
        default:
          return 'An authentication error occurred. Please try again.';
      }
    }
    // Handle the custom exception from the original code for cancelled sign-in
    if (e.toString().contains('Google sign in was cancelled')) {
      return 'The sign-in process was cancelled.';
    }
    // Generic fallback for other exception types
    return 'An unexpected error occurred. Please try again later.';
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Force unauthenticated state (for debugging/skip purposes)
  void forceUnauthenticated() {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
      error: null,
    );
  }

  /// Refresh user data manually (for pull-to-refresh, etc.)
  Future<void> refreshUser() async {
    if (state.status != AuthStatus.authenticated) {
      debugPrint('🔴 Cannot refresh user - not authenticated');
      return;
    }

    try {
      debugPrint('🔄 Manual user refresh requested...');
      final refreshedUser = await _authService.getCurrentUser(
        forceRefresh: true,
      );
      if (refreshedUser != null) {
        state = state.copyWith(user: refreshedUser);
        debugPrint('🟢 Manual user refresh completed');

        // Don't automatically refresh permissions during manual refresh
        // to avoid router redirects - let calling code handle permissions refresh
        debugPrint(
          '🟡 Skipping automatic permissions refresh during manual user refresh',
        );
      }
    } catch (e) {
      debugPrint('🔴 Manual user refresh failed: $e');
      state = state.copyWith(error: _mapErrorToMessage(e));
    }
  }

  /// Update user data locally and in storage
  Future<void> updateUserLocally(app_user.User updatedUser) async {
    debugPrint('🔵 Updating user locally: ${updatedUser.email}');

    try {
      final currentUser = state.user;

      // Check if user data has actually changed to prevent unnecessary state updates
      if (currentUser == updatedUser) {
        debugPrint(
          '⚪ User data unchanged, skipping update to prevent router flicker',
        );
        return;
      }

      // Update Hive storage
      await _authService._initializeStorage();
      final userBox = Hive.box<app_user.User>(AppConstants.userBoxKey);
      await userBox.put('current_user', updatedUser);

      // Update state only if data has changed
      state = state.copyWith(user: updatedUser);

      debugPrint('🟢 User updated locally successfully');
    } catch (e) {
      debugPrint('🔴 Failed to update user locally: $e');
    }
  }
}

/// Authentication service implementation
class AuthService {
  // Suggestion 1: Inject Ref to read providers.
  AuthService(
    this._ref, {
    Future<void> Function()? signOutOfIdentityProviders,
  }) : _signOutOfIdentityProviders =
           signOutOfIdentityProviders ?? _defaultSignOutOfIdentityProviders;

  final Ref _ref;
  final Future<void> Function() _signOutOfIdentityProviders;
  // Lazily read the ApiClient provider.
  ApiClient get _apiClient => _ref.read(apiClientProvider);

  // Lazy, so an AuthService built without Firebase (tests) does not touch it.
  late final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;

  static Future<void> _defaultSignOutOfIdentityProviders() async {
    await firebase_auth.FirebaseAuth.instance.signOut();
    // Also sign out from Google on mobile
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
  }

  /// Initialize Hive boxes
  Future<void> _initializeStorage() async {
    if (!Hive.isBoxOpen(AppConstants.userBoxKey)) {
      await Hive.openBox<app_user.User>(AppConstants.userBoxKey);
    }
  }

  /// Get current user from storage or Firebase
  Future<app_user.User?> getCurrentUser({bool forceRefresh = false}) async {
    debugPrint('🔵 Getting current user... (forceRefresh: $forceRefresh)');
    await _initializeStorage();

    final userBox = Hive.box<app_user.User>(AppConstants.userBoxKey);
    final localUser = userBox.get('current_user');
    final firebaseUser = _firebaseAuth.currentUser;

    debugPrint('🔍 Local user: ${localUser?.email}');
    debugPrint('🔍 Firebase user: ${firebaseUser?.email}');

    // If we have both Firebase user and local data, decide whether to refresh
    if (firebaseUser != null && localUser != null) {
      // Fast path: Return cached user for immediate app startup
      if (!forceRefresh) {
        debugPrint(
          '🟢 Using cached user data for fast startup: ${localUser.email}',
        );

        // Schedule a background refresh for next time (non-blocking)
        _scheduleUserRefresh();

        return localUser;
      }

      // Forced refresh path: Update user data from backend
      try {
        debugPrint('🔵 Refreshing user data from backend...');
        final idToken = await firebaseUser.getIdToken();
        if (idToken != null) {
          await _apiClient.setFirebaseToken(idToken);
          final userData = await _apiClient.getCurrentUser();
          debugPrint('🟢 Backend user data: $userData');
          final updatedUser = app_user.User.fromJson(userData);
          await userBox.put('current_user', updatedUser);
          return updatedUser;
        } else {
          debugPrint('🔴 No ID token available');
          await _clearUserData();
          return null;
        }
      } catch (e) {
        debugPrint('🔴 Failed to get user from backend: $e');
        // Return cached user as fallback instead of clearing everything
        debugPrint('🟡 Using cached user data as fallback');
        return localUser;
      }
    }

    debugPrint('🔴 No authenticated user found');
    return null;
  }

  /// Schedule a background user refresh (non-blocking)
  void _scheduleUserRefresh() {
    Future.microtask(() async {
      try {
        debugPrint('🔄 Background user refresh started...');
        final refreshedUser = await getCurrentUser(forceRefresh: true);
        if (refreshedUser != null) {
          debugPrint('🟢 Background user refresh completed');
          // Update the auth state if we're still authenticated
          _ref
              .read(authStateProvider.notifier)
              .updateUserLocally(refreshedUser);
        }
      } catch (e) {
        debugPrint('🔴 Background user refresh failed: $e');
        // Don't do anything - user can continue with cached data
      }
    });
  }

  /// Sign in with Google
  Future<app_user.User> signInWithGoogle() async {
    try {
      debugPrint('🔵 Starting Google Sign-In process...');
      await _initializeStorage();

      firebase_auth.UserCredential userCredential;

      if (kIsWeb) {
        // WEB PLATFORM
        debugPrint('🔵 Using web platform authentication...');
        final googleProvider = firebase_auth.GoogleAuthProvider();
        userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        // MOBILE PLATFORMS (iOS/Android)
        debugPrint('🔵 Using mobile platform authentication...');

        // Use GoogleSignIn.instance.authenticate() for version 7+
        if (GoogleSignIn.instance.supportsAuthenticate()) {
          debugPrint('🔵 Platform supports authenticate method');

          final googleUser = await GoogleSignIn.instance.authenticate();

          debugPrint(
            '🟢 Google authentication successful for ${googleUser.email}',
          );
          final GoogleSignInAuthentication googleAuth =
              googleUser.authentication;
          final credential = firebase_auth.GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );
          userCredential = await _firebaseAuth.signInWithCredential(credential);
        } else {
          debugPrint('🔴 Google Sign-In authentication not supported');
          throw Exception(
            'Google Sign-In authentication is not supported on this platform.',
          );
        }
      }

      if (userCredential.user == null) {
        debugPrint('🔴 Firebase user credential is null');
        throw Exception('Failed to sign in with Firebase.');
      }

      return await _finishFirebaseSignIn(userCredential);
    } catch (e) {
      // Clean up on error for both Firebase and Google Sign-In
      await _firebaseAuth.signOut();
      if (!kIsWeb) {
        // Also sign out from Google to allow the user to re-select an account on next attempt.
        await GoogleSignIn.instance.signOut();
      }
      // Re-throw the original exception to be handled by the AuthNotifier
      rethrow;
    }
  }

  /// Sign in with an email address and password
  Future<app_user.User> signInWithEmail(String email, String password) async {
    try {
      debugPrint('🔵 Starting email/password sign-in...');
      await _initializeStorage();

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        debugPrint('🔴 Firebase user credential is null');
        throw Exception('Failed to sign in with Firebase.');
      }

      return await _finishFirebaseSignIn(userCredential);
    } catch (e) {
      // Clean up on error. Unlike Google, there is no second session to end.
      await _firebaseAuth.signOut();
      rethrow;
    }
  }

  /// Sign in with Apple
  ///
  /// iOS only. The Apple provider has no Services ID configured in Firebase,
  /// which the Android and web redirect flows both require, so the button that
  /// calls this is not shown on those platforms.
  Future<app_user.User> signInWithApple() async {
    try {
      debugPrint('🔵 Starting Apple Sign-In process...');
      await _initializeStorage();

      final appleProvider = firebase_auth.AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final userCredential = kIsWeb
          ? await _firebaseAuth.signInWithPopup(appleProvider)
          : await _firebaseAuth.signInWithProvider(appleProvider);

      if (userCredential.user == null) {
        debugPrint('🔴 Firebase user credential is null');
        throw Exception('Failed to sign in with Firebase.');
      }

      return await _finishFirebaseSignIn(userCredential);
    } catch (e) {
      // Clean up on error. Unlike Google, there is no second session to end.
      await _firebaseAuth.signOut();
      rethrow;
    }
  }

  /// Everything that happens once Firebase has authenticated, whichever method
  /// got us there: link the account with the backend, store the user locally
  /// and register the device for push. Throws on failure so that each caller
  /// can run its own sign-out cleanup.
  Future<app_user.User> _finishFirebaseSignIn(
    firebase_auth.UserCredential userCredential,
  ) async {
    debugPrint(
      '🟢 Firebase authentication successful for ${userCredential.user!.email}',
    );
    final String? idToken = await userCredential.user!.getIdToken();
    if (idToken == null) {
      debugPrint('🔴 Failed to get Firebase ID token');
      throw Exception('Failed to get Firebase ID token.');
    }

    // Add a small delay to prevent clock skew issues
    await Future.delayed(const Duration(seconds: 1));

    debugPrint('🔵 Linking account with backend...');
    final userData = await _apiClient.linkAccount(idToken);
    debugPrint('🟢 Backend linking successful: $userData');

    final user = app_user.User.fromJson(userData);
    final userBox = Hive.box<app_user.User>(AppConstants.userBoxKey);
    await userBox.put('current_user', user);
    debugPrint('🟢 User stored in local storage: ${user.email}');

    // Register device for push notifications
    await _registerDevice();

    return user;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Unregister device for push notifications
      await _unregisterDevice();

      // Sign out from Firebase
      await _firebaseAuth.signOut();

      // Also sign out from Google on mobile
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }

      // Clear API tokens
      await _apiClient.clearTokens();

      // Clear local user data
      await _clearUserData();
    } catch (e) {
      // Re-throw to be handled by AuthNotifier
      rethrow;
    }
  }

  /// Sign out without device unregistration (for when device unregistration is handled separately)
  ///
  /// Every step runs even if an earlier one fails, so a failed Google or
  /// Firebase sign-out (offline) cannot leave the tokens and the member's
  /// profile on the device. Throws afterwards if any step failed.
  Future<void> signOutWithoutDeviceUnregister() async {
    final failed = await clearSession();
    if (failed.isNotEmpty) {
      throw Exception('Sign out incomplete: ${failed.join(', ')}');
    }
  }

  /// Sign out of Firebase/Google, then clear the API tokens and the stored
  /// profile. Each step is guarded on its own; returns the names of the steps
  /// that failed (empty when all succeeded). Nothing here throws.
  Future<List<String>> clearSession() async {
    final failed = <String>[];
    Future<void> step(String what, Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        debugPrint('🟡 Failed to clear $what: $e');
        failed.add(what);
      }
    }

    await step('identity provider sign-out', _signOutOfIdentityProviders);
    await step('API tokens', () => _apiClient.clearTokens());
    await step('stored profile', _removeStoredProfile);
    return failed;
  }

  /// Remove the stored profile. Throws if it cannot be removed.
  Future<void> _removeStoredProfile() async {
    if (Hive.isBoxOpen(AppConstants.userBoxKey)) {
      final userBox = Hive.box<app_user.User>(AppConstants.userBoxKey);
      await userBox.delete('current_user');
    }
  }

  /// Clear user data from local storage
  Future<void> _clearUserData() async {
    try {
      await _removeStoredProfile();
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  /// Check if user is signed in
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Get Firebase auth stream
  Stream<firebase_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  /// Register device for push notifications
  /// This method requests notification permissions during login
  Future<void> _registerDevice() async {
    try {
      debugPrint('🔵 Starting device registration...');

      // For web platform, skip FCM token registration for now
      if (kIsWeb) {
        debugPrint('🟡 Skipping device registration on web platform');
        return;
      }

      // Check if FCM is available
      final messaging = FirebaseMessaging.instance;
      debugPrint('🔍 Firebase Messaging instance created');

      // Request permission first with timeout
      final settings = await messaging.requestPermission().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('🔴 FCM permission request timed out');
          throw Exception('FCM permission request timed out');
        },
      );
      debugPrint('🔍 FCM permission status: ${settings.authorizationStatus}');

      // Only proceed if permissions are granted
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint(
          '🟡 User denied notification permissions, skipping device registration',
        );
        return;
      }

      final fcmToken = await messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('🔴 FCM token request timed out');
          throw Exception('FCM token request timed out');
        },
      );

      if (fcmToken != null) {
        debugPrint('🔵 Got FCM token: ${fcmToken.substring(0, 20)}...');
        debugPrint('🔵 About to call API client registerDevice...');
        await _apiClient.registerDevice(fcmToken);
        debugPrint('🟢 Device registration completed successfully');
      } else {
        debugPrint('🔴 No FCM token available for device registration');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 Failed to register device: $e');
      debugPrint('🔴 Stack trace: $stackTrace');
      // Don't throw the error - device registration failure shouldn't block login
    }
  }

  /// Unregister device for push notifications
  Future<void> _unregisterDevice() async {
    try {
      debugPrint('🔵 Starting device unregistration...');

      // For web platform, skip FCM token unregistration for now
      if (kIsWeb) {
        debugPrint('🟡 Skipping device unregistration on web platform');
        return;
      }

      final messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('🔴 FCM token request timed out during unregistration');
          throw Exception('FCM token request timed out');
        },
      );

      if (fcmToken != null) {
        debugPrint(
          '🔵 Got FCM token for unregistration: ${fcmToken.substring(0, 20)}...',
        );
        debugPrint('🔵 Calling API client unregisterDevice...');
        await _apiClient.unregisterDevice(fcmToken);
        debugPrint('🟢 Device unregistration completed');
      } else {
        debugPrint('🔴 No FCM token available for device unregistration');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 Failed to unregister device: $e');
      debugPrint('🔴 Stack trace: $stackTrace');
      // Don't throw the error - device unregistration failure shouldn't block logout
    }
  }
}
