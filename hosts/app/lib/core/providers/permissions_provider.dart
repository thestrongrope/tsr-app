import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:riverpod/legacy.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../models/permissions_payload.dart';
import '../services/saved_copy.dart';

/// Permissions provider.
/// Flow:
/// 1. User logs in → fetchAndSave() → saves to Hive as JSON string
/// 2. App restarts → init() → loads from Hive
/// 3. Refetch: when a response announces a new revision (see [revisionSignals]),
///    on resume after 15 minutes, and after a 403 (see [forbiddenSignals])
final permissionsProvider =
    StateNotifierProvider<PermissionsNotifier, PermissionsState>((ref) {
      final notifier = PermissionsNotifier();
      WidgetsBinding.instance.addObserver(notifier);
      final forbidden = ApiClient().forbiddenSignals.listen(
        (_) => notifier.refreshIfOlderThan(PermissionsNotifier.forbiddenGap),
      );
      final revisions = ApiClient().revisionSignals.listen(
        notifier.onServerRevision,
      );
      ref.onDispose(() {
        WidgetsBinding.instance.removeObserver(notifier);
        forbidden.cancel();
        revisions.cancel();
      });
      return notifier;
    });

class PermissionsState {
  final bool isLoading;
  final PermissionsPayload? payload;
  final String? error;

  /// The last fetch failed, so [payload] is the last answer the server gave,
  /// not necessarily the current one.
  final bool stale;

  /// A signed-in member with no saved copy and no answer yet. [payload] is
  /// null; the app shows a loading state and Retry, never an empty default.
  final bool unconfirmed;

  const PermissionsState({
    this.isLoading = false,
    this.payload,
    this.error,
    this.stale = false,
    this.unconfirmed = false,
  });

  // For backwards compatibility
  bool get loading => isLoading;

  PermissionsState copyWith({
    bool? isLoading,
    bool? loading,
    PermissionsPayload? payload,
    String? error,
    bool? stale,
    bool? unconfirmed,
    bool clearError = false,
  }) {
    return PermissionsState(
      isLoading: isLoading ?? loading ?? this.isLoading,
      payload: payload ?? this.payload,
      error: clearError ? null : (error ?? this.error),
      stale: stale ?? this.stale,
      unconfirmed: unconfirmed ?? this.unconfirmed,
    );
  }

  bool get hasPermissions => payload != null;

  /// See [PermissionsPayload.can]. No payload yet means nothing is granted.
  bool can(String permission, {int? classId, int? classGender}) =>
      payload?.can(permission, classId: classId, classGender: classGender) ??
      false;
}

class PermissionsNotifier extends StateNotifier<PermissionsState>
    with WidgetsBindingObserver {
  static final resumeEvents = StreamController<void>.broadcast();
  PermissionsNotifier({
    Future<Map<String, dynamic>?> Function({String? ifNoneMatch})? fetch,
    DateTime Function()? now,
    int? Function()? owner,
  }) : _fetch =
           fetch ??
           (({ifNoneMatch}) =>
               ApiClient().getPermissions(ifNoneMatch: ifNoneMatch)),
       _now = now ?? DateTime.now,
       _owner = owner ?? signedInToken,
       super(const PermissionsState());

  /// Returns the body, or null when the server answered 304 to [ifNoneMatch].
  final Future<Map<String, dynamic>?> Function({String? ifNoneMatch}) _fetch;
  final DateTime Function() _now;
  final int? Function() _owner;

  /// A new key, so the payload cached by older builds (`permissions_json_v2`,
  /// a different shape) is ignored. A copy saved by a build before revisions
  /// has none, so the first launch after upgrade fetches in full.
  static const _storageKey = 'permissions_json_v4';

  /// Refetch on resume when the last fetch is older than this.
  static const resumeGap = Duration(minutes: 15);

  /// A 403 may mean the grants changed; refetch, but not more often than this,
  /// so a 403 on the permissions call itself cannot loop.
  static const forbiddenGap = Duration(minutes: 1);

  DateTime? _lastFetch;
  Future<void>? _inFlight;

  /// The revision the server last announced that this build tried to fetch, and
  /// when, so a server that cannot answer is not asked again on every response.
  (String, DateTime)? _lastAnnounced;

  /// Initialize - load from local storage
  /// Call this on app startup when user is authenticated
  Future<void> init() async {
    debugPrint('🔵 [Permissions] Initializing...');

    final cached = await _loadFromStorage();
    if (cached != null) {
      debugPrint(
        '🟢 [Permissions] Loaded from cache: ${cached.permissions.length} permissions',
      );
      state = state.copyWith(payload: cached, unconfirmed: false);
    } else if (state.payload == null) {
      if (_owner() == null) {
        useGuestBase();
      } else {
        debugPrint('🟡 [Permissions] No saved copy, waiting for the server');
        state = state.copyWith(unconfirmed: true);
      }
    }
  }

  // Legacy method names for backwards compatibility
  /// What a guest may see. It is not an answer about any member, so a
  /// sign-in never shows it or keeps it as that member's last answer.
  static const _guestBase = PermissionsPayload.member();

  /// Nobody is signed in (a guest browsing, or after sign-out): there is no
  /// member to ask the server about, so the app does not wait for an answer.
  void useGuestBase() {
    debugPrint('🟡 [Permissions] Nobody signed in, using the member base');
    state = const PermissionsState(payload: _guestBase);
  }

  Future<void> loadFromCache() => init();
  Future<void> fetchAndCache() => fetchAndSave();
  Future<void> silentRefresh() => fetchAndSave();

  /// Fetch from API and save to local storage
  /// Call this after login or on manual refresh. Callers that arrive while a
  /// fetch is running share it.
  Future<void> fetchAndSave() =>
      _inFlight ??= _fetchAndSave().whenComplete(() => _inFlight = null);

  Future<void> _fetchAndSave() async {
    if (_owner() == null) {
      debugPrint('🟡 [Permissions] Nobody signed in, nothing to fetch');
      return;
    }
    debugPrint('🔵 [Permissions] Fetching from API...');
    _lastFetch = _now();
    if (identical(state.payload, _guestBase)) state = const PermissionsState();
    final held = state.payload;
    // With a copy to show, the fetch runs behind it; the app waits only when
    // there is nothing to show.
    state = state.copyWith(isLoading: held == null, clearError: true);

    try {
      // The copy's revision lets the server answer 304: nothing changed.
      final json = await _fetch(ifNoneMatch: held?.revision);
      final PermissionsPayload payload;
      if (json == null) {
        if (held == null) {
          throw const FormatException('304 with no saved permissions');
        }
        payload = held;
      } else {
        payload = PermissionsPayload.fromJson(json);
        await _saveToStorage(payload);
      }

      debugPrint(
        '🟢 [Permissions] Fetched and saved: ${payload.permissions.length} permissions',
      );
      state = PermissionsState(payload: payload);
    } catch (e) {
      debugPrint('🔴 [Permissions] Fetch failed: $e');

      // Keep the last answer the server gave; never install an empty one.
      state = PermissionsState(
        payload: held,
        error: e.toString(),
        stale: held != null,
        unconfirmed: held == null,
      );
    }
  }

  /// Refetch if signed in (permissions loaded) and the last fetch is older
  /// than [gap].
  Future<void> refreshIfOlderThan(Duration gap) async {
    if (state.payload == null || _inFlight != null) return;
    final last = _lastFetch;
    if (last != null && _now().difference(last) < gap) return;
    await fetchAndSave();
  }

  /// The server announced [revision] on a response. When it is not the one held
  /// and no fetch is running, fetch once; the same announcement is not acted on
  /// again within [forbiddenGap].
  void onServerRevision(String revision) {
    final held = state.payload;
    if (held == null || held.revision == revision || _inFlight != null) return;
    final last = _lastAnnounced;
    if (last != null &&
        last.$1 == revision &&
        _now().difference(last.$2) < forbiddenGap) {
      return;
    }
    _lastAnnounced = (revision, _now());
    unawaited(fetchAndSave());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resumeEvents.add(null);
      refreshIfOlderThan(resumeGap);
    }
  }

  /// Clear permissions (on logout)
  Future<void> clear() async {
    debugPrint('🔵 [Permissions] Clearing...');
    try {
      await deleteSaved();
    } catch (e) {
      debugPrint('🔴 [Permissions] Clear failed: $e');
    }
    _lastFetch = null;
    state = const PermissionsState();
  }

  /// Deletes the saved permissions (and those of older builds) from the
  /// device. Throws if it cannot, so account deletion can report it.
  static Future<void> deleteSaved() async {
    final box = Hive.box(AppConstants.cacheBoxKey);
    await box.delete(_storageKey);
    await box.delete('permissions_json_v2');
    await box.delete('permissions_v1');
  }

  /// Saved permissions never expire (a member offline keeps their access), but
  /// they are shown only to the member they were saved for.
  SavedCopies get _saved => SavedCopies(
    Hive.box(AppConstants.cacheBoxKey),
    owner: _owner,
    maxAge: null,
  );

  /// Load from Hive storage
  Future<PermissionsPayload?> _loadFromStorage() async {
    try {
      final jsonString = _saved.read(_storageKey);

      if (jsonString == null) {
        debugPrint('🔍 [Permissions] No data in storage');
        return null;
      }

      if (jsonString is! String) {
        debugPrint(
          '🔴 [Permissions] Storage data is not a string: ${jsonString.runtimeType}',
        );
        return null;
      }

      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      return PermissionsPayload.fromJson(jsonMap);
    } catch (e) {
      debugPrint('🔴 [Permissions] Load from storage failed: $e');
      return null;
    }
  }

  /// Save to Hive storage as JSON string
  Future<void> _saveToStorage(PermissionsPayload payload) async {
    try {
      final jsonString = json.encode(payload.toJson());
      await _saved.save(_storageKey, jsonString);
      debugPrint('🟢 [Permissions] Saved to storage');
    } catch (e) {
      debugPrint('🔴 [Permissions] Save to storage failed: $e');
    }
  }
}
